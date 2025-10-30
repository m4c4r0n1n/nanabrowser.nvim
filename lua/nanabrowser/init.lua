-- nanabrowser.nvim - Side-by-side panel system
-- Browser │ Terminal │ TODO all visible at once

local M = {}

M.config = {
  browser = "w3m",
  height = 20, -- Height of bottom panel area
  browser_width = 40, -- Width percentage for browser
  terminal_width = 30, -- Width percentage for terminal
  todo_width = 30, -- Width percentage for TODO
}

M.state = {
  panels_open = false,
  browser_win = nil,
  browser_buf = nil,
  browser_job_id = nil,
  terminal_win = nil,
  terminal_buf = nil,
  terminal_job_id = nil,
  todo_win = nil,
  todo_buf = nil,
  todos = {},
}

function M.setup(opts)
  M.config = vim.tbl_deep_extend("force", M.config, opts or {})
  M.load_todos()
end

--------------------------------------------------------------------------------
-- PANEL LAYOUT
--------------------------------------------------------------------------------

local function close_all_panels()
  if M.state.browser_job_id then
    vim.fn.jobstop(M.state.browser_job_id)
  end
  if M.state.terminal_job_id then
    vim.fn.jobstop(M.state.terminal_job_id)
  end

  for _, win in ipairs({ M.state.browser_win, M.state.terminal_win, M.state.todo_win }) do
    if win and vim.api.nvim_win_is_valid(win) then
      vim.api.nvim_win_close(win, true)
    end
  end

  M.state.panels_open = false
  M.state.browser_win = nil
  M.state.terminal_win = nil
  M.state.todo_win = nil
  M.state.browser_job_id = nil
  M.state.terminal_job_id = nil
end

function M.open_panels()
  if M.state.panels_open then
    return
  end

  -- Save current window
  local original_win = vim.api.nvim_get_current_win()

  -- Create bottom split
  vim.cmd(string.format("botright %dsplit", M.config.height))
  local bottom_win = vim.api.nvim_get_current_win()

  -- Split into 3 vertical columns
  -- Browser (left)
  M.state.browser_buf = vim.api.nvim_create_buf(false, true)
  vim.api.nvim_win_set_buf(bottom_win, M.state.browser_buf)
  M.state.browser_win = bottom_win

  vim.api.nvim_buf_set_name(M.state.browser_buf, "Browser")
  vim.api.nvim_buf_set_option(M.state.browser_buf, "buftype", "nofile")
  vim.wo[M.state.browser_win].number = false
  vim.wo[M.state.browser_win].relativenumber = false
  vim.wo[M.state.browser_win].signcolumn = "no"

  -- Terminal (middle)
  vim.cmd("vsplit")
  M.state.terminal_win = vim.api.nvim_get_current_win()
  M.state.terminal_buf = vim.api.nvim_create_buf(false, true)
  vim.api.nvim_win_set_buf(M.state.terminal_win, M.state.terminal_buf)

  vim.api.nvim_buf_set_name(M.state.terminal_buf, "Terminal")
  vim.api.nvim_buf_set_option(M.state.terminal_buf, "buftype", "nofile")
  vim.wo[M.state.terminal_win].number = false
  vim.wo[M.state.terminal_win].relativenumber = false
  vim.wo[M.state.terminal_win].signcolumn = "no"

  -- TODO (right)
  vim.cmd("vsplit")
  M.state.todo_win = vim.api.nvim_get_current_win()
  M.state.todo_buf = vim.api.nvim_create_buf(false, true)
  vim.api.nvim_win_set_buf(M.state.todo_win, M.state.todo_buf)

  vim.api.nvim_buf_set_name(M.state.todo_buf, "TODO Manager")
  vim.api.nvim_buf_set_option(M.state.todo_buf, "buftype", "nofile")
  vim.wo[M.state.todo_win].number = false
  vim.wo[M.state.todo_win].relativenumber = false
  vim.wo[M.state.todo_win].signcolumn = "no"

  -- Adjust widths
  vim.api.nvim_win_set_width(M.state.browser_win, math.floor(vim.o.columns * M.config.browser_width / 100))
  vim.api.nvim_win_set_width(M.state.terminal_win, math.floor(vim.o.columns * M.config.terminal_width / 100))

  -- Render initial content
  render_browser_placeholder()
  render_terminal_placeholder()
  render_todo()

  -- Setup keymaps
  setup_browser_keymaps()
  setup_terminal_keymaps()
  setup_todo_keymaps()

  M.state.panels_open = true

  -- Return to original window
  if vim.api.nvim_win_is_valid(original_win) then
    vim.api.nvim_set_current_win(original_win)
  end
end

function M.toggle_panels()
  if M.state.panels_open then
    close_all_panels()
  else
    M.open_panels()
  end
end

--------------------------------------------------------------------------------
-- BROWSER
--------------------------------------------------------------------------------

local function render_browser_placeholder()
  if not M.state.browser_buf or not vim.api.nvim_buf_is_valid(M.state.browser_buf) then
    return
  end

  local lines = {
    "╔═══════════════════════════╗",
    "║      🌐 BROWSER           ║",
    "╚═══════════════════════════╝",
    "",
    "  Press <leader>wb to browse",
    "  Or gx on a URL",
    "",
    "  Waiting for URL...",
  }

  vim.api.nvim_buf_set_option(M.state.browser_buf, "modifiable", true)
  vim.api.nvim_buf_set_lines(M.state.browser_buf, 0, -1, false, lines)
  vim.api.nvim_buf_set_option(M.state.browser_buf, "modifiable", false)
end

function M.open_browser(url)
  if not M.state.panels_open then
    M.open_panels()
  end

  if vim.fn.executable(M.config.browser) ~= 1 then
    vim.notify("nanabrowser: " .. M.config.browser .. " not installed", vim.log.levels.ERROR)
    return
  end

  url = url or "https://duckduckgo.com"
  if not url:match("^https?://") then
    url = "https://" .. url
  end

  -- Kill old browser job
  if M.state.browser_job_id then
    vim.fn.jobstop(M.state.browser_job_id)
  end

  -- Create new terminal buffer for browser
  local browser_term_buf = vim.api.nvim_create_buf(false, true)
  vim.api.nvim_win_set_buf(M.state.browser_win, browser_term_buf)

  -- Focus browser window and start terminal
  vim.api.nvim_set_current_win(M.state.browser_win)
  M.state.browser_job_id = vim.fn.termopen(string.format("%s '%s'", M.config.browser, url))

  vim.api.nvim_buf_set_name(browser_term_buf, "Browser: " .. url)
  M.state.browser_buf = browser_term_buf

  vim.cmd("startinsert")
end

function M.open_browser_prompt()
  vim.ui.input({ prompt = "Enter URL: ", default = "https://" }, function(url)
    if url and url ~= "" then
      M.open_browser(url)
    end
  end)
end

function M.open_browser_cursor()
  local url = vim.fn.expand("<cWORD>")
  url = url:match('["\']([^"\']+)["\']') or url:match('%(([^)]+)%)') or url

  if url and url ~= "" then
    M.open_browser(url)
  else
    vim.notify("No URL under cursor", vim.log.levels.WARN)
  end
end

function setup_browser_keymaps()
  if not M.state.browser_buf or not vim.api.nvim_buf_is_valid(M.state.browser_buf) then
    return
  end

  local opts = { buffer = M.state.browser_buf, silent = true }
  vim.keymap.set("n", "<leader>wb", M.open_browser_prompt, opts)
end

--------------------------------------------------------------------------------
-- TERMINAL
--------------------------------------------------------------------------------

local function render_terminal_placeholder()
  if not M.state.terminal_buf or not vim.api.nvim_buf_is_valid(M.state.terminal_buf) then
    return
  end

  local lines = {
    "╔═══════════════════════════╗",
    "║      💻 TERMINAL          ║",
    "╚═══════════════════════════╝",
    "",
    "  Press <leader>tt to start",
    "",
    "  Waiting...",
  }

  vim.api.nvim_buf_set_option(M.state.terminal_buf, "modifiable", true)
  vim.api.nvim_buf_set_lines(M.state.terminal_buf, 0, -1, false, lines)
  vim.api.nvim_buf_set_option(M.state.terminal_buf, "modifiable", false)
end

function M.open_terminal()
  if not M.state.panels_open then
    M.open_panels()
  end

  -- Kill old terminal job
  if M.state.terminal_job_id then
    vim.fn.jobstop(M.state.terminal_job_id)
  end

  -- Create terminal buffer
  local term_buf = vim.api.nvim_create_buf(false, true)
  vim.api.nvim_win_set_buf(M.state.terminal_win, term_buf)

  -- Focus and start terminal
  vim.api.nvim_set_current_win(M.state.terminal_win)
  M.state.terminal_job_id = vim.fn.termopen(vim.o.shell)

  vim.api.nvim_buf_set_name(term_buf, "Terminal")
  M.state.terminal_buf = term_buf

  vim.cmd("startinsert")
end

function setup_terminal_keymaps()
  if not M.state.terminal_buf or not vim.api.nvim_buf_is_valid(M.state.terminal_buf) then
    return
  end

  local opts = { buffer = M.state.terminal_buf, silent = true }
  vim.keymap.set("n", "<leader>tt", M.open_terminal, opts)
end

--------------------------------------------------------------------------------
-- TODO
--------------------------------------------------------------------------------

function M.load_todos()
  local todo_file = vim.fn.stdpath("data") .. "/nanabrowser_todos.json"
  if vim.fn.filereadable(todo_file) == 1 then
    local content = vim.fn.readfile(todo_file)
    local ok, data = pcall(vim.fn.json_decode, table.concat(content, "\n"))
    if ok and type(data) == "table" then
      M.state.todos = data
    end
  end
end

function M.save_todos()
  local todo_file = vim.fn.stdpath("data") .. "/nanabrowser_todos.json"
  vim.fn.writefile({ vim.fn.json_encode(M.state.todos) }, todo_file)
end

local function render_todo()
  if not M.state.todo_buf or not vim.api.nvim_buf_is_valid(M.state.todo_buf) then
    return
  end

  local lines = {
    "╔═══════════════════════════╗",
    "║      📝 TODO              ║",
    "╚═══════════════════════════╝",
    "  [a]Add [x]Toggle [d]Del",
    "",
  }

  if #M.state.todos == 0 then
    table.insert(lines, "  No TODOs")
    table.insert(lines, "  Press 'a' to add")
  else
    for i, todo in ipairs(M.state.todos) do
      local checkbox = todo.done and "[✓]" or "[ ]"
      local text = todo.text
      if #text > 25 then
        text = text:sub(1, 22) .. "..."
      end
      table.insert(lines, string.format("  %s %s", checkbox, text))
    end
  end

  vim.api.nvim_buf_set_option(M.state.todo_buf, "modifiable", true)
  vim.api.nvim_buf_set_lines(M.state.todo_buf, 0, -1, false, lines)
  vim.api.nvim_buf_set_option(M.state.todo_buf, "modifiable", false)
end

function setup_todo_keymaps()
  if not M.state.todo_buf or not vim.api.nvim_buf_is_valid(M.state.todo_buf) then
    return
  end

  local opts = { buffer = M.state.todo_buf, silent = true, nowait = true }

  vim.keymap.set("n", "a", function()
    vim.ui.input({ prompt = "New TODO: " }, function(text)
      if text and text ~= "" then
        table.insert(M.state.todos, { text = text, done = false })
        M.save_todos()
        render_todo()
      end
    end)
  end, opts)

  vim.keymap.set("n", "d", function()
    local line = vim.fn.line(".")
    local idx = line - 5
    if idx > 0 and idx <= #M.state.todos then
      table.remove(M.state.todos, idx)
      M.save_todos()
      render_todo()
    end
  end, opts)

  vim.keymap.set("n", "x", function()
    local line = vim.fn.line(".")
    local idx = line - 5
    if idx > 0 and idx <= #M.state.todos then
      M.state.todos[idx].done = not M.state.todos[idx].done
      M.save_todos()
      render_todo()
    end
  end, opts)
end

return M
