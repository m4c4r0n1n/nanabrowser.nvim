local M = {}

M.config = {
  browser = "w3m", -- w3m, lynx, links
  position = "bottom", -- bottom, right, float
  size = 20, -- height for horizontal, width for vertical
  border = "rounded",
  auto_close = false,
}

-- State
M.terminal = nil
M.todo_buf = nil

function M.setup(opts)
  M.config = vim.tbl_deep_extend("force", M.config, opts or {})
end

-- Check if browser is available
local function check_browser()
  if vim.fn.executable(M.config.browser) ~= 1 then
    vim.notify(
      string.format("nanabrowser: %s is not installed. Install with: sudo pacman -S %s", M.config.browser, M.config.browser),
      vim.log.levels.ERROR
    )
    return false
  end
  return true
end

-- Open browser in terminal split
function M.open_browser(url)
  if not check_browser() then
    return
  end

  -- Default URL if none provided
  url = url or "https://duckduckgo.com"

  -- Validate URL
  if not url:match("^https?://") then
    url = "https://" .. url
  end

  -- Build command
  local cmd = string.format("%s '%s'", M.config.browser, url)

  -- Determine split command
  local split_cmd
  if M.config.position == "bottom" then
    split_cmd = string.format("botright %dsplit", M.config.size)
  elseif M.config.position == "right" then
    split_cmd = string.format("botright %dvsplit", M.config.size)
  else
    split_cmd = "split"
  end

  -- Open terminal
  vim.cmd(split_cmd)
  vim.cmd("terminal " .. cmd)

  -- Get terminal info
  M.terminal = {
    buf = vim.api.nvim_get_current_buf(),
    win = vim.api.nvim_get_current_win(),
    job_id = vim.b.terminal_job_id,
  }

  -- Set buffer options
  vim.api.nvim_buf_set_option(M.terminal.buf, "filetype", "nanabrowser")
  vim.api.nvim_buf_set_name(M.terminal.buf, "nanabrowser://" .. url)

  -- Set window options
  vim.wo.number = false
  vim.wo.relativenumber = false
  vim.wo.signcolumn = "no"

  -- Keymaps for browser buffer
  local opts = { buffer = M.terminal.buf, silent = true }

  -- Close browser
  vim.keymap.set("n", "q", function()
    M.close_browser()
  end, opts)

  -- New URL
  vim.keymap.set("n", "<leader>wn", function()
    M.open_browser_prompt()
  end, opts)

  -- Enter terminal mode automatically
  vim.cmd("startinsert")

  vim.notify("nanabrowser: Browser opened. Press 'q' (in normal mode) to close", vim.log.levels.INFO)
end

-- Prompt for URL
function M.open_browser_prompt()
  vim.ui.input({ prompt = "Enter URL: ", default = "https://" }, function(url)
    if url and url ~= "" then
      M.open_browser(url)
    end
  end)
end

-- Open URL under cursor
function M.open_browser_cursor()
  local url = vim.fn.expand("<cWORD>")
  url = url:match('["\']([^"\']+)["\']') or url:match('%(([^)]+)%)') or url

  if url and url ~= "" then
    M.open_browser(url)
  else
    vim.notify("nanabrowser: No URL under cursor", vim.log.levels.WARN)
  end
end

-- Close browser
function M.close_browser()
  if M.terminal and vim.api.nvim_buf_is_valid(M.terminal.buf) then
    vim.api.nvim_buf_delete(M.terminal.buf, { force = true })
    M.terminal = nil
    vim.notify("nanabrowser: Browser closed", vim.log.levels.INFO)
  end
end

-- Toggle browser
function M.toggle_browser()
  if M.terminal and vim.api.nvim_buf_is_valid(M.terminal.buf) then
    M.close_browser()
  else
    M.open_browser_prompt()
  end
end

--------------------------------------------------------------------------------
-- TODO List Feature
--------------------------------------------------------------------------------

M.todos = {}

-- Load todos from file
local function load_todos()
  local todo_file = vim.fn.stdpath("data") .. "/nanabrowser_todos.json"
  if vim.fn.filereadable(todo_file) == 1 then
    local content = vim.fn.readfile(todo_file)
    local ok, data = pcall(vim.fn.json_decode, table.concat(content, "\n"))
    if ok then
      M.todos = data
    end
  end
end

-- Save todos to file
local function save_todos()
  local todo_file = vim.fn.stdpath("data") .. "/nanabrowser_todos.json"
  local content = vim.fn.json_encode(M.todos)
  vim.fn.writefile({ content }, todo_file)
end

-- Render todo list in buffer
local function render_todos()
  if not M.todo_buf or not vim.api.nvim_buf_is_valid(M.todo_buf) then
    return
  end

  local lines = {
    "═══════════════════════════════════════════════════════════════════",
    "  TODO List",
    "  [a] Add | [d] Delete | [x] Toggle | [q] Close",
    "═══════════════════════════════════════════════════════════════════",
    "",
  }

  for i, todo in ipairs(M.todos) do
    local checkbox = todo.done and "[✓]" or "[ ]"
    local text = todo.done and string.format("~~%s~~", todo.text) or todo.text
    table.insert(lines, string.format("%d. %s %s", i, checkbox, text))
  end

  vim.api.nvim_buf_set_option(M.todo_buf, "modifiable", true)
  vim.api.nvim_buf_set_lines(M.todo_buf, 0, -1, false, lines)
  vim.api.nvim_buf_set_option(M.todo_buf, "modifiable", false)
end

-- Open TODO list
function M.open_todos()
  load_todos()

  -- Create buffer
  vim.cmd("botright 15split")
  M.todo_buf = vim.api.nvim_get_current_buf()

  -- Buffer options
  vim.api.nvim_buf_set_option(M.todo_buf, "buftype", "nofile")
  vim.api.nvim_buf_set_option(M.todo_buf, "filetype", "nanabrowser-todo")
  vim.api.nvim_buf_set_name(M.todo_buf, "nanabrowser://todos")

  -- Window options
  vim.wo.number = false
  vim.wo.relativenumber = false
  vim.wo.signcolumn = "no"
  vim.wo.wrap = false

  render_todos()

  -- Keymaps
  local opts = { buffer = M.todo_buf, silent = true }

  -- Add todo
  vim.keymap.set("n", "a", function()
    vim.ui.input({ prompt = "New TODO: " }, function(text)
      if text and text ~= "" then
        table.insert(M.todos, { text = text, done = false })
        save_todos()
        render_todos()
      end
    end)
  end, opts)

  -- Delete todo
  vim.keymap.set("n", "d", function()
    local line = vim.fn.line(".")
    local idx = line - 5 -- Account for header lines
    if idx > 0 and idx <= #M.todos then
      table.remove(M.todos, idx)
      save_todos()
      render_todos()
    end
  end, opts)

  -- Toggle done
  vim.keymap.set("n", "x", function()
    local line = vim.fn.line(".")
    local idx = line - 5
    if idx > 0 and idx <= #M.todos then
      M.todos[idx].done = not M.todos[idx].done
      save_todos()
      render_todos()
    end
  end, opts)

  -- Close
  vim.keymap.set("n", "q", function()
    vim.cmd("close")
    M.todo_buf = nil
  end, opts)
end

-- Toggle TODO list
function M.toggle_todos()
  if M.todo_buf and vim.api.nvim_buf_is_valid(M.todo_buf) then
    vim.cmd("close")
    M.todo_buf = nil
  else
    M.open_todos()
  end
end

return M
