-- nanabrowser.nvim - Browser, TODO Manager, and Terminal panels for Neovim
-- SpaceVim-inspired panel system

local M = {}

M.config = {
  browser = "w3m",
  position = "bottom",
  size = 20,
  border = "rounded",
}

M.state = {
  browser_buf = nil,
  browser_win = nil,
  todo_buf = nil,
  todo_win = nil,
  terminal_buf = nil,
  terminal_win = nil,
  todos = {},
}

function M.setup(opts)
  M.config = vim.tbl_deep_extend("force", M.config, opts or {})
  M.load_todos()
end

--------------------------------------------------------------------------------
-- BROWSER
--------------------------------------------------------------------------------

local function check_browser()
  if vim.fn.executable(M.config.browser) ~= 1 then
    vim.notify(
      string.format("nanabrowser: %s not installed. Install: sudo pacman -S %s", M.config.browser, M.config.browser),
      vim.log.levels.ERROR
    )
    return false
  end
  return true
end

function M.open_browser(url)
  if not check_browser() then
    return
  end

  url = url or "https://duckduckgo.com"
  if not url:match("^https?://") then
    url = "https://" .. url
  end

  -- Close existing panels
  M.close_todos()
  M.close_terminal()

  local cmd = string.format("%s '%s'", M.config.browser, url)
  local split_cmd = string.format("botright %dsplit", M.config.size)

  vim.cmd(split_cmd)
  vim.cmd("terminal " .. cmd)

  M.state.browser_buf = vim.api.nvim_get_current_buf()
  M.state.browser_win = vim.api.nvim_get_current_win()

  vim.api.nvim_buf_set_option(M.state.browser_buf, "filetype", "nanabrowser")
  vim.api.nvim_buf_set_name(M.state.browser_buf, "Browser: " .. url)

  vim.wo.number = false
  vim.wo.relativenumber = false
  vim.wo.signcolumn = "no"

  local opts = { buffer = M.state.browser_buf, silent = true }
  vim.keymap.set("n", "q", function()
    M.close_browser()
  end, opts)

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

function M.close_browser()
  if M.state.browser_win and vim.api.nvim_win_is_valid(M.state.browser_win) then
    if #vim.api.nvim_list_wins() > 1 then
      vim.api.nvim_win_close(M.state.browser_win, true)
      M.state.browser_win = nil
      M.state.browser_buf = nil
    end
  end
end

--------------------------------------------------------------------------------
-- TODO MANAGER
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
  local content = vim.fn.json_encode(M.state.todos)
  vim.fn.writefile({ content }, todo_file)
end

local function render_todos()
  if not M.state.todo_buf or not vim.api.nvim_buf_is_valid(M.state.todo_buf) then
    return
  end

  local lines = {
    "═══════════════════════════════════════════════════════════════════",
    "  📝 TODO Manager",
    "  [a] Add | [d] Delete | [x] Toggle | [e] Edit | [q] Close",
    "═══════════════════════════════════════════════════════════════════",
    "",
  }

  if #M.state.todos == 0 then
    table.insert(lines, "  No TODOs yet. Press 'a' to add one!")
  else
    for i, todo in ipairs(M.state.todos) do
      local checkbox = todo.done and "[✓]" or "[ ]"
      local text = todo.done and string.format("~~%s~~", todo.text) or todo.text
      table.insert(lines, string.format("  %d. %s %s", i, checkbox, text))
    end
  end

  vim.api.nvim_buf_set_option(M.state.todo_buf, "modifiable", true)
  vim.api.nvim_buf_set_lines(M.state.todo_buf, 0, -1, false, lines)
  vim.api.nvim_buf_set_option(M.state.todo_buf, "modifiable", false)
  vim.api.nvim_buf_set_option(M.state.todo_buf, "modified", false)
end

function M.open_todos()
  if M.state.todo_win and vim.api.nvim_win_is_valid(M.state.todo_win) then
    vim.api.nvim_set_current_win(M.state.todo_win)
    return
  end

  -- Close other panels
  M.close_browser()
  M.close_terminal()

  local split_cmd = string.format("botright %dsplit", M.config.size)
  vim.cmd(split_cmd)

  if not M.state.todo_buf or not vim.api.nvim_buf_is_valid(M.state.todo_buf) then
    M.state.todo_buf = vim.api.nvim_create_buf(false, true)
  end

  vim.api.nvim_win_set_buf(0, M.state.todo_buf)
  M.state.todo_win = vim.api.nvim_get_current_win()

  vim.api.nvim_buf_set_option(M.state.todo_buf, "buftype", "nofile")
  vim.api.nvim_buf_set_option(M.state.todo_buf, "bufhidden", "hide")
  vim.api.nvim_buf_set_option(M.state.todo_buf, "swapfile", false)
  vim.api.nvim_buf_set_option(M.state.todo_buf, "filetype", "nanabrowser-todo")
  vim.api.nvim_buf_set_name(M.state.todo_buf, "TODO Manager")

  vim.wo.number = false
  vim.wo.relativenumber = false
  vim.wo.signcolumn = "no"
  vim.wo.wrap = false
  vim.wo.cursorline = true

  render_todos()

  local opts = { buffer = M.state.todo_buf, silent = true, nowait = true }

  vim.keymap.set("n", "a", function()
    vim.ui.input({ prompt = "New TODO: " }, function(text)
      if text and text ~= "" then
        table.insert(M.state.todos, { text = text, done = false })
        M.save_todos()
        render_todos()
      end
    end)
  end, opts)

  vim.keymap.set("n", "d", function()
    local line = vim.fn.line(".")
    local idx = line - 5
    if idx > 0 and idx <= #M.state.todos then
      table.remove(M.state.todos, idx)
      M.save_todos()
      render_todos()
    end
  end, opts)

  vim.keymap.set("n", "x", function()
    local line = vim.fn.line(".")
    local idx = line - 5
    if idx > 0 and idx <= #M.state.todos then
      M.state.todos[idx].done = not M.state.todos[idx].done
      M.save_todos()
      render_todos()
    end
  end, opts)

  vim.keymap.set("n", "e", function()
    local line = vim.fn.line(".")
    local idx = line - 5
    if idx > 0 and idx <= #M.state.todos then
      vim.ui.input({ prompt = "Edit TODO: ", default = M.state.todos[idx].text }, function(text)
        if text and text ~= "" then
          M.state.todos[idx].text = text
          M.save_todos()
          render_todos()
        end
      end)
    end
  end, opts)

  vim.keymap.set("n", "q", function()
    M.close_todos()
  end, opts)
end

function M.close_todos()
  if M.state.todo_win and vim.api.nvim_win_is_valid(M.state.todo_win) then
    if #vim.api.nvim_list_wins() > 1 then
      vim.api.nvim_win_close(M.state.todo_win, false)
      M.state.todo_win = nil
    end
  end
end

function M.toggle_todos()
  if M.state.todo_win and vim.api.nvim_win_is_valid(M.state.todo_win) then
    M.close_todos()
  else
    M.open_todos()
  end
end

--------------------------------------------------------------------------------
-- TERMINAL
--------------------------------------------------------------------------------

function M.open_terminal()
  if M.state.terminal_win and vim.api.nvim_win_is_valid(M.state.terminal_win) then
    vim.api.nvim_set_current_win(M.state.terminal_win)
    return
  end

  -- Close other panels
  M.close_browser()
  M.close_todos()

  local split_cmd = string.format("botright %dsplit", M.config.size)
  vim.cmd(split_cmd)
  vim.cmd("terminal")

  M.state.terminal_buf = vim.api.nvim_get_current_buf()
  M.state.terminal_win = vim.api.nvim_get_current_win()

  vim.api.nvim_buf_set_name(M.state.terminal_buf, "Terminal")

  vim.wo.number = false
  vim.wo.relativenumber = false
  vim.wo.signcolumn = "no"

  local opts = { buffer = M.state.terminal_buf, silent = true }
  vim.keymap.set("n", "q", function()
    M.close_terminal()
  end, opts)

  vim.cmd("startinsert")
end

function M.close_terminal()
  if M.state.terminal_win and vim.api.nvim_win_is_valid(M.state.terminal_win) then
    if #vim.api.nvim_list_wins() > 1 then
      vim.api.nvim_win_close(M.state.terminal_win, true)
      M.state.terminal_win = nil
      M.state.terminal_buf = nil
    end
  end
end

function M.toggle_terminal()
  if M.state.terminal_win and vim.api.nvim_win_is_valid(M.state.terminal_win) then
    M.close_terminal()
  else
    M.open_terminal()
  end
end

return M
