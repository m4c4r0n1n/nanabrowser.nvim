-- nanabrowser.nvim - Tabbed panel system for Neovim
-- SpaceVim-style bottom panel with Browser, TODO, Terminal tabs

local M = {}

M.config = {
  browser = "w3m",
  size = 20,
  border = "rounded",
}

M.state = {
  panel_win = nil,
  panel_buf = nil,
  current_tab = "browser", -- browser, todo, terminal
  browser_job_id = nil,
  todos = {},
  terminal_job_id = nil,
}

function M.setup(opts)
  M.config = vim.tbl_deep_extend("force", M.config, opts or {})
  M.load_todos()
end

--------------------------------------------------------------------------------
-- PANEL MANAGEMENT
--------------------------------------------------------------------------------

local function create_panel()
  if M.state.panel_win and vim.api.nvim_win_is_valid(M.state.panel_win) then
    return
  end

  -- Create bottom split
  vim.cmd(string.format("botright %dsplit", M.config.size))
  M.state.panel_win = vim.api.nvim_get_current_win()
  M.state.panel_buf = vim.api.nvim_create_buf(false, true)
  vim.api.nvim_win_set_buf(M.state.panel_win, M.state.panel_buf)

  -- Window options
  vim.wo[M.state.panel_win].number = false
  vim.wo[M.state.panel_win].relativenumber = false
  vim.wo[M.state.panel_win].signcolumn = "no"
  vim.wo[M.state.panel_win].wrap = false
  vim.wo[M.state.panel_win].cursorline = true
  vim.wo[M.state.panel_win].winfixheight = true

  -- Buffer options
  vim.api.nvim_buf_set_option(M.state.panel_buf, "buftype", "nofile")
  vim.api.nvim_buf_set_option(M.state.panel_buf, "bufhidden", "hide")
  vim.api.nvim_buf_set_option(M.state.panel_buf, "swapfile", false)
  vim.api.nvim_buf_set_name(M.state.panel_buf, "Nana Panel")

  -- Keymaps for panel
  local opts = { buffer = M.state.panel_buf, silent = true, nowait = true }

  -- Tab switching
  vim.keymap.set("n", "1", function() M.switch_tab("browser") end, opts)
  vim.keymap.set("n", "2", function() M.switch_tab("todo") end, opts)
  vim.keymap.set("n", "3", function() M.switch_tab("terminal") end, opts)

  -- Close panel
  vim.keymap.set("n", "q", function() M.close_panel() end, opts)
end

local function render_tab_bar()
  local tabs = {
    { name = "Browser", key = "browser", num = "1" },
    { name = "TODO", key = "todo", num = "2" },
    { name = "Terminal", key = "terminal", num = "3" },
  }

  local tab_line = "  "
  for _, tab in ipairs(tabs) do
    local active = tab.key == M.state.current_tab
    if active then
      tab_line = tab_line .. string.format("[%s] %s  ", tab.num, tab.name)
    else
      tab_line = tab_line .. string.format(" %s  %s  ", tab.num, tab.name)
    end
  end
  tab_line = tab_line .. "│ [q] Close"

  return {
    "═══════════════════════════════════════════════════════════════════",
    tab_line,
    "───────────────────────────────────────────────────────────────────",
  }
end

local function render_content()
  if M.state.current_tab == "browser" then
    return {
      "",
      "  🌐 Browser",
      "",
      "  Press <leader>wb to enter a URL",
      "  Or put cursor on a URL and press gx",
      "",
      "  Navigation:",
      "    Arrow keys / vim keys - Navigate",
      "    Enter - Follow link",
      "    <Esc> - Exit terminal mode",
      "",
    }
  elseif M.state.current_tab == "todo" then
    local lines = {
      "",
      "  📝 TODO Manager",
      "  [a] Add | [e] Edit | [x] Toggle | [d] Delete",
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

    return lines
  elseif M.state.current_tab == "terminal" then
    return {
      "",
      "  💻 Terminal",
      "",
      "  Press <leader>tt to open terminal",
      "  Or use :NanaTerminal",
      "",
    }
  end
end

local function render_panel()
  if not M.state.panel_buf or not vim.api.nvim_buf_is_valid(M.state.panel_buf) then
    return
  end

  local lines = render_tab_bar()
  local content = render_content()
  vim.list_extend(lines, content)

  vim.api.nvim_buf_set_option(M.state.panel_buf, "modifiable", true)
  vim.api.nvim_buf_set_lines(M.state.panel_buf, 0, -1, false, lines)
  vim.api.nvim_buf_set_option(M.state.panel_buf, "modifiable", false)

  -- Setup TODO keymaps if on TODO tab
  if M.state.current_tab == "todo" then
    setup_todo_keymaps()
  end
end

function M.open_panel(tab)
  create_panel()
  if tab then
    M.state.current_tab = tab
  end
  render_panel()
  vim.api.nvim_set_current_win(M.state.panel_win)
end

function M.close_panel()
  if M.state.panel_win and vim.api.nvim_win_is_valid(M.state.panel_win) then
    if #vim.api.nvim_list_wins() > 1 then
      -- Kill any terminal jobs
      if M.state.browser_job_id then
        vim.fn.jobstop(M.state.browser_job_id)
        M.state.browser_job_id = nil
      end
      if M.state.terminal_job_id then
        vim.fn.jobstop(M.state.terminal_job_id)
        M.state.terminal_job_id = nil
      end

      vim.api.nvim_win_close(M.state.panel_win, true)
      M.state.panel_win = nil
    end
  end
end

function M.toggle_panel()
  if M.state.panel_win and vim.api.nvim_win_is_valid(M.state.panel_win) then
    M.close_panel()
  else
    M.open_panel()
  end
end

function M.switch_tab(tab)
  M.state.current_tab = tab
  render_panel()
end

--------------------------------------------------------------------------------
-- BROWSER
--------------------------------------------------------------------------------

function M.open_browser(url)
  if vim.fn.executable(M.config.browser) ~= 1 then
    vim.notify("nanabrowser: " .. M.config.browser .. " not installed", vim.log.levels.ERROR)
    return
  end

  url = url or "https://duckduckgo.com"
  if not url:match("^https?://") then
    url = "https://" .. url
  end

  -- Open panel and switch to browser tab
  M.open_panel("browser")

  -- Create terminal buffer for browser
  local browser_buf = vim.api.nvim_create_buf(false, true)
  vim.api.nvim_win_set_buf(M.state.panel_win, browser_buf)

  local cmd = string.format("%s '%s'", M.config.browser, url)
  M.state.browser_job_id = vim.fn.termopen(cmd)

  vim.api.nvim_buf_set_name(browser_buf, "Browser: " .. url)
  vim.wo[M.state.panel_win].number = false
  vim.wo[M.state.panel_win].relativenumber = false

  -- Browser-specific keymaps
  local opts = { buffer = browser_buf, silent = true }
  vim.keymap.set("n", "q", function()
    vim.api.nvim_win_set_buf(M.state.panel_win, M.state.panel_buf)
    vim.fn.jobstop(M.state.browser_job_id)
    M.state.browser_job_id = nil
    render_panel()
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

function setup_todo_keymaps()
  local opts = { buffer = M.state.panel_buf, silent = true, nowait = true }

  vim.keymap.set("n", "a", function()
    vim.ui.input({ prompt = "New TODO: " }, function(text)
      if text and text ~= "" then
        table.insert(M.state.todos, { text = text, done = false })
        M.save_todos()
        render_panel()
      end
    end)
  end, opts)

  vim.keymap.set("n", "d", function()
    local line = vim.fn.line(".")
    local idx = line - 7 -- Account for header
    if idx > 0 and idx <= #M.state.todos then
      table.remove(M.state.todos, idx)
      M.save_todos()
      render_panel()
    end
  end, opts)

  vim.keymap.set("n", "x", function()
    local line = vim.fn.line(".")
    local idx = line - 7
    if idx > 0 and idx <= #M.state.todos then
      M.state.todos[idx].done = not M.state.todos[idx].done
      M.save_todos()
      render_panel()
    end
  end, opts)

  vim.keymap.set("n", "e", function()
    local line = vim.fn.line(".")
    local idx = line - 7
    if idx > 0 and idx <= #M.state.todos then
      vim.ui.input({ prompt = "Edit TODO: ", default = M.state.todos[idx].text }, function(text)
        if text and text ~= "" then
          M.state.todos[idx].text = text
          M.save_todos()
          render_panel()
        end
      end)
    end
  end, opts)
end

--------------------------------------------------------------------------------
-- TERMINAL
--------------------------------------------------------------------------------

function M.open_terminal()
  M.open_panel("terminal")

  local term_buf = vim.api.nvim_create_buf(false, true)
  vim.api.nvim_win_set_buf(M.state.panel_win, term_buf)

  M.state.terminal_job_id = vim.fn.termopen(vim.o.shell)

  vim.api.nvim_buf_set_name(term_buf, "Terminal")
  vim.wo[M.state.panel_win].number = false

  local opts = { buffer = term_buf, silent = true }
  vim.keymap.set("n", "q", function()
    vim.api.nvim_win_set_buf(M.state.panel_win, M.state.panel_buf)
    vim.fn.jobstop(M.state.terminal_job_id)
    M.state.terminal_job_id = nil
    render_panel()
  end, opts)

  vim.cmd("startinsert")
end

return M
