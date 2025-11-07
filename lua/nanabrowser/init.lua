-- nanabrowser.nvim - Side-by-side panel system
-- Browser │ Terminal │ TODO all visible at once

local M = {}

M.config = {
  browser = "w3m",
  external_browser = "firefox", -- External browser for full browsing
  height = 20, -- Height of bottom panel area
  browser_width = 40, -- Width percentage for browser
  terminal_width = 30, -- Width percentage for terminal
  todo_width = 30, -- Width percentage for TODO
  borders = true, -- Enable borders around panels
  border_style = "rounded", -- Options: "rounded", "solid", "double", "none"
}

M.state = {
  browser_open = false,
  browser_win = nil,
  browser_buf = nil,
  browser_job_id = nil,
  terminal_open = false,
  terminal_win = nil,
  terminal_buf = nil,
  terminal_job_id = nil,
  todo_open = false,
  todo_win = nil,
  todo_buf = nil,
  todos = {},
  bottom_win = nil, -- The main bottom split window
}

-- Define highlight groups for borders
local function setup_highlights()
  -- Panel background (slightly different from main editor)
  vim.api.nvim_set_hl(0, "NanaPanelNormal", { bg = "#1e1e2e", blend = 0 })
  vim.api.nvim_set_hl(0, "NanaPanelNC", { bg = "#181825", blend = 0 })

  -- Border color
  vim.api.nvim_set_hl(0, "NanaPanelBorder", { fg = "#89b4fa", bg = "#1e1e2e", bold = true })
end

function M.setup(opts)
  M.config = vim.tbl_deep_extend("force", M.config, opts or {})
  M.load_todos()
  setup_highlights()
end

--------------------------------------------------------------------------------
-- PANEL LAYOUT
--------------------------------------------------------------------------------

-- Forward declarations
local render_browser_placeholder
local render_terminal_placeholder
local render_todo
local setup_browser_keymaps
local setup_terminal_keymaps
local setup_todo_keymaps

-- Apply border styling to a window
local function apply_panel_border(win, title)
  if not win or not vim.api.nvim_win_is_valid(win) or not M.config.borders then
    return
  end

  -- Set window-local options for visual separation
  vim.wo[win].winhl = "Normal:NanaPanelNormal,NormalNC:NanaPanelNC"
  vim.wo[win].cursorline = false

  -- Add a winbar as top border with title
  if title then
    vim.wo[win].winbar = "%#NanaPanelBorder#" .. " " .. title .. " "
  end
end

-- Helper to count open panels
local function count_open_panels()
  local count = 0
  if M.state.browser_open then count = count + 1 end
  if M.state.terminal_open then count = count + 1 end
  if M.state.todo_open then count = count + 1 end
  return count
end

-- Helper to get ordered list of open panels
local function get_open_panels()
  local panels = {}
  if M.state.browser_open then table.insert(panels, "browser") end
  if M.state.terminal_open then table.insert(panels, "terminal") end
  if M.state.todo_open then table.insert(panels, "todo") end
  return panels
end

-- Recalculate and rearrange panel layout
local function rearrange_panels()
  local open_panels = get_open_panels()
  local panel_count = #open_panels

  if panel_count == 0 then
    -- Close bottom window if no panels open
    if M.state.bottom_win and vim.api.nvim_win_is_valid(M.state.bottom_win) then
      vim.api.nvim_win_close(M.state.bottom_win, true)
      M.state.bottom_win = nil
    end
    return
  end

  -- Save current window
  local original_win = vim.api.nvim_get_current_win()

  -- Close all panel windows (we'll recreate them in correct positions)
  for _, win in ipairs({ M.state.browser_win, M.state.terminal_win, M.state.todo_win }) do
    if win and vim.api.nvim_win_is_valid(win) then
      vim.api.nvim_win_close(win, true)
    end
  end
  M.state.browser_win = nil
  M.state.terminal_win = nil
  M.state.todo_win = nil

  -- Create/reuse bottom split
  if not M.state.bottom_win or not vim.api.nvim_win_is_valid(M.state.bottom_win) then
    vim.cmd(string.format("botright %dsplit", M.config.height))
    M.state.bottom_win = vim.api.nvim_get_current_win()
  else
    vim.api.nvim_set_current_win(M.state.bottom_win)
  end

  -- Create windows based on which panels are open
  if panel_count == 1 then
    -- Single panel takes full width
    local panel_type = open_panels[1]
    if panel_type == "browser" then
      if M.state.browser_buf and vim.api.nvim_buf_is_valid(M.state.browser_buf) then
        vim.api.nvim_win_set_buf(M.state.bottom_win, M.state.browser_buf)
      end
      M.state.browser_win = M.state.bottom_win
      apply_panel_border(M.state.browser_win, "🌐 Browser")
    elseif panel_type == "terminal" then
      if M.state.terminal_buf and vim.api.nvim_buf_is_valid(M.state.terminal_buf) then
        vim.api.nvim_win_set_buf(M.state.bottom_win, M.state.terminal_buf)
      end
      M.state.terminal_win = M.state.bottom_win
      apply_panel_border(M.state.terminal_win, "💻 Terminal")
    elseif panel_type == "todo" then
      if M.state.todo_buf and vim.api.nvim_buf_is_valid(M.state.todo_buf) then
        vim.api.nvim_win_set_buf(M.state.bottom_win, M.state.todo_buf)
      end
      M.state.todo_win = M.state.bottom_win
      apply_panel_border(M.state.todo_win, "📝 TODO")
    end
  else
    -- Multiple panels - split them
    -- First panel in bottom_win
    local first_panel = open_panels[1]
    if first_panel == "browser" and M.state.browser_buf and vim.api.nvim_buf_is_valid(M.state.browser_buf) then
      vim.api.nvim_win_set_buf(M.state.bottom_win, M.state.browser_buf)
      M.state.browser_win = M.state.bottom_win
      apply_panel_border(M.state.browser_win, "🌐 Browser")
    elseif first_panel == "terminal" and M.state.terminal_buf and vim.api.nvim_buf_is_valid(M.state.terminal_buf) then
      vim.api.nvim_win_set_buf(M.state.bottom_win, M.state.terminal_buf)
      M.state.terminal_win = M.state.bottom_win
      apply_panel_border(M.state.terminal_win, "💻 Terminal")
    elseif first_panel == "todo" and M.state.todo_buf and vim.api.nvim_buf_is_valid(M.state.todo_buf) then
      vim.api.nvim_win_set_buf(M.state.bottom_win, M.state.todo_buf)
      M.state.todo_win = M.state.bottom_win
      apply_panel_border(M.state.todo_win, "📝 TODO")
    end

    -- Create remaining panels with vsplit
    for i = 2, panel_count do
      vim.cmd("vsplit")
      local new_win = vim.api.nvim_get_current_win()
      local panel_type = open_panels[i]

      if panel_type == "browser" and M.state.browser_buf and vim.api.nvim_buf_is_valid(M.state.browser_buf) then
        vim.api.nvim_win_set_buf(new_win, M.state.browser_buf)
        M.state.browser_win = new_win
        apply_panel_border(M.state.browser_win, "🌐 Browser")
      elseif panel_type == "terminal" and M.state.terminal_buf and vim.api.nvim_buf_is_valid(M.state.terminal_buf) then
        vim.api.nvim_win_set_buf(new_win, M.state.terminal_buf)
        M.state.terminal_win = new_win
        apply_panel_border(M.state.terminal_win, "💻 Terminal")
      elseif panel_type == "todo" and M.state.todo_buf and vim.api.nvim_buf_is_valid(M.state.todo_buf) then
        vim.api.nvim_win_set_buf(new_win, M.state.todo_buf)
        M.state.todo_win = new_win
        apply_panel_border(M.state.todo_win, "📝 TODO")
      end
    end

    -- Adjust widths based on panel count
    if panel_count == 2 then
      -- Split 50/50
      local width = math.floor(vim.o.columns / 2)
      if M.state.browser_win then vim.api.nvim_win_set_width(M.state.browser_win, width) end
      if M.state.terminal_win then vim.api.nvim_win_set_width(M.state.terminal_win, width) end
      if M.state.todo_win then vim.api.nvim_win_set_width(M.state.todo_win, width) end
    elseif panel_count == 3 then
      -- Use config percentages
      if M.state.browser_win then
        vim.api.nvim_win_set_width(M.state.browser_win, math.floor(vim.o.columns * M.config.browser_width / 100))
      end
      if M.state.terminal_win then
        vim.api.nvim_win_set_width(M.state.terminal_win, math.floor(vim.o.columns * M.config.terminal_width / 100))
      end
      -- TODO takes remaining space
    end
  end

  -- Return to original window
  if vim.api.nvim_win_is_valid(original_win) then
    vim.api.nvim_set_current_win(original_win)
  end
end

-- Open all panels at once (<leader>p)
function M.open_panels()
  M.open_browser_panel()
  M.open_terminal_panel()
  M.open_todo_panel()
end

-- Close all panels
function M.close_all_panels()
  M.state.browser_open = false
  M.state.terminal_open = false
  M.state.todo_open = false

  if M.state.browser_job_id then
    vim.fn.jobstop(M.state.browser_job_id)
    M.state.browser_job_id = nil
  end
  if M.state.terminal_job_id then
    vim.fn.jobstop(M.state.terminal_job_id)
    M.state.terminal_job_id = nil
  end

  rearrange_panels()
end

-- Toggle all panels
function M.toggle_panels()
  if count_open_panels() > 0 then
    M.close_all_panels()
  else
    M.open_panels()
  end
end

--------------------------------------------------------------------------------
-- BROWSER
--------------------------------------------------------------------------------

render_browser_placeholder = function()
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

-- Open browser panel (creates placeholder)
function M.open_browser_panel()
  if M.state.browser_open then
    return
  end

  -- Create buffer if needed
  if not M.state.browser_buf or not vim.api.nvim_buf_is_valid(M.state.browser_buf) then
    M.state.browser_buf = vim.api.nvim_create_buf(false, true)
    vim.api.nvim_buf_set_name(M.state.browser_buf, "Browser-" .. M.state.browser_buf)
    vim.api.nvim_buf_set_option(M.state.browser_buf, "buftype", "nofile")
    vim.api.nvim_buf_set_option(M.state.browser_buf, "bufhidden", "hide")
    vim.api.nvim_buf_set_option(M.state.browser_buf, "buflisted", false)
  end

  M.state.browser_open = true
  rearrange_panels()

  -- Setup window options and render placeholder
  if M.state.browser_win and vim.api.nvim_win_is_valid(M.state.browser_win) then
    vim.wo[M.state.browser_win].number = false
    vim.wo[M.state.browser_win].relativenumber = false
    vim.wo[M.state.browser_win].signcolumn = "no"
  end

  render_browser_placeholder()
  -- Don't setup keymaps here - they'll be set up when browser actually opens
end

function M.open_browser(url)
  if vim.fn.executable(M.config.browser) ~= 1 then
    vim.notify("nanabrowser: " .. M.config.browser .. " not installed", vim.log.levels.ERROR)
    return
  end

  url = url or "https://duckduckgo.com"
  if not url:match("^https?://") then
    url = "https://" .. url
  end

  -- Open browser panel if not already open
  if not M.state.browser_open then
    M.open_browser_panel()
  end

  -- Verify window is valid after panel is opened
  if not M.state.browser_win or not vim.api.nvim_win_is_valid(M.state.browser_win) then
    -- Force recreate if window is invalid
    M.state.browser_open = false
    M.open_browser_panel()
  end

  -- Final check
  if not M.state.browser_win or not vim.api.nvim_win_is_valid(M.state.browser_win) then
    vim.notify("Failed to create browser window", vim.log.levels.ERROR)
    return
  end

  -- Kill old browser job
  if M.state.browser_job_id then
    vim.fn.jobstop(M.state.browser_job_id)
    M.state.browser_job_id = nil
  end

  -- Create new terminal buffer for browser
  local browser_term_buf = vim.api.nvim_create_buf(false, true)

  -- Set buffer options to prevent :q issues
  vim.api.nvim_buf_set_option(browser_term_buf, "bufhidden", "hide")
  vim.api.nvim_buf_set_option(browser_term_buf, "buflisted", false)

  vim.api.nvim_win_set_buf(M.state.browser_win, browser_term_buf)

  -- Focus browser window and start terminal
  vim.api.nvim_set_current_win(M.state.browser_win)

  -- Use modern user agent to avoid "update browser" warnings
  local user_agent = "Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36"
  local cmd = string.format("%s -o user_agent='%s' '%s'", M.config.browser, user_agent, url)
  M.state.browser_job_id = vim.fn.termopen(cmd, {
    on_exit = function()
      M.state.browser_job_id = nil
    end
  })

  vim.api.nvim_buf_set_name(browser_term_buf, "Browser-" .. browser_term_buf .. ": " .. url)
  M.state.browser_buf = browser_term_buf

  -- Reapply border styling to the new terminal buffer
  apply_panel_border(M.state.browser_win, "🌐 Browser")

  -- Set up keymaps BEFORE entering insert mode
  setup_browser_keymaps()

  -- Enter terminal mode for interaction with w3m
  -- Using feedkeys to ensure it happens after everything is set up
  vim.schedule(function()
    if vim.api.nvim_get_current_win() == M.state.browser_win then
      vim.cmd("startinsert")
    end
  end)
end

function M.open_browser_prompt()
  vim.ui.input({ prompt = "Enter URL: ", default = "https://" }, function(url)
    if url and url ~= "" then
      vim.schedule(function()
        M.open_browser(url)
      end)
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

-- Open URL in external browser
function M.open_external(url)
  if not url or url == "" then
    vim.notify("No URL provided", vim.log.levels.WARN)
    return
  end

  if not url:match("^https?://") then
    url = "https://" .. url
  end

  if vim.fn.executable(M.config.external_browser) ~= 1 then
    vim.notify("nanabrowser: " .. M.config.external_browser .. " not installed", vim.log.levels.ERROR)
    return
  end

  -- Launch browser in background, disown it
  vim.fn.jobstart({M.config.external_browser, url}, {detach = true})
  vim.notify("Opened in " .. M.config.external_browser .. ": " .. url, vim.log.levels.INFO)
end

function M.open_external_prompt()
  vim.ui.input({ prompt = "Enter URL for external browser: ", default = "https://" }, function(url)
    if url and url ~= "" then
      vim.schedule(function()
        M.open_external(url)
      end)
    end
  end)
end

function M.open_external_cursor()
  local url = vim.fn.expand("<cWORD>")
  url = url:match('["\']([^"\']+)["\']') or url:match('%(([^)]+)%)') or url

  if url and url ~= "" then
    M.open_external(url)
  else
    vim.notify("No URL under cursor", vim.log.levels.WARN)
  end
end

setup_browser_keymaps = function()
  if not M.state.browser_buf or not vim.api.nvim_buf_is_valid(M.state.browser_buf) then
    return
  end

  -- Set up autocommand to clean up job on buffer delete
  vim.api.nvim_create_autocmd("BufDelete", {
    buffer = M.state.browser_buf,
    callback = function()
      if M.state.browser_job_id then
        vim.fn.jobstop(M.state.browser_job_id)
        M.state.browser_job_id = nil
      end
    end,
  })

  local opts = { buffer = M.state.browser_buf, silent = true }
  -- Only set keymaps in normal mode, don't interfere with terminal mode
  vim.keymap.set("n", "<leader>wb", M.open_browser_prompt, opts)
  vim.keymap.set("n", "q", function()
    M.state.browser_open = false
    if M.state.browser_job_id then
      vim.fn.jobstop(M.state.browser_job_id)
      M.state.browser_job_id = nil
    end
    rearrange_panels()
  end, opts)

  -- Add escape to exit terminal mode in browser
  vim.keymap.set("t", "<Esc>", "<C-\\><C-n>", { buffer = M.state.browser_buf, silent = true })
end

--------------------------------------------------------------------------------
-- TERMINAL
--------------------------------------------------------------------------------

render_terminal_placeholder = function()
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

-- Open terminal panel (creates placeholder)
function M.open_terminal_panel()
  if M.state.terminal_open then
    return
  end

  -- Create buffer if needed
  if not M.state.terminal_buf or not vim.api.nvim_buf_is_valid(M.state.terminal_buf) then
    M.state.terminal_buf = vim.api.nvim_create_buf(false, true)
    vim.api.nvim_buf_set_name(M.state.terminal_buf, "Terminal-" .. M.state.terminal_buf)
    vim.api.nvim_buf_set_option(M.state.terminal_buf, "buftype", "nofile")
    vim.api.nvim_buf_set_option(M.state.terminal_buf, "bufhidden", "hide")
    vim.api.nvim_buf_set_option(M.state.terminal_buf, "buflisted", false)
  end

  M.state.terminal_open = true
  rearrange_panels()

  -- Setup window options and render placeholder
  if M.state.terminal_win and vim.api.nvim_win_is_valid(M.state.terminal_win) then
    vim.wo[M.state.terminal_win].number = false
    vim.wo[M.state.terminal_win].relativenumber = false
    vim.wo[M.state.terminal_win].signcolumn = "no"
  end

  render_terminal_placeholder()
  -- Don't setup keymaps here - they'll be set up when terminal actually opens
end

function M.open_terminal()
  -- Open terminal panel if not already open
  if not M.state.terminal_open then
    M.open_terminal_panel()
  end

  -- Kill old terminal job
  if M.state.terminal_job_id then
    vim.fn.jobstop(M.state.terminal_job_id)
  end

  -- Create terminal buffer
  local term_buf = vim.api.nvim_create_buf(false, true)

  -- Set buffer options to prevent :q issues
  vim.api.nvim_buf_set_option(term_buf, "bufhidden", "hide")
  vim.api.nvim_buf_set_option(term_buf, "buflisted", false)

  vim.api.nvim_win_set_buf(M.state.terminal_win, term_buf)

  -- Focus and start terminal
  vim.api.nvim_set_current_win(M.state.terminal_win)
  M.state.terminal_job_id = vim.fn.termopen(vim.o.shell, {
    on_exit = function()
      M.state.terminal_job_id = nil
    end
  })

  vim.api.nvim_buf_set_name(term_buf, "Terminal-" .. term_buf)
  M.state.terminal_buf = term_buf

  -- Reapply border styling to the new terminal buffer
  apply_panel_border(M.state.terminal_win, "💻 Terminal")

  -- Set up keymaps BEFORE entering insert mode
  setup_terminal_keymaps()

  vim.schedule(function()
    if vim.api.nvim_get_current_win() == M.state.terminal_win then
      vim.cmd("startinsert")
    end
  end)
end

setup_terminal_keymaps = function()
  if not M.state.terminal_buf or not vim.api.nvim_buf_is_valid(M.state.terminal_buf) then
    return
  end

  -- Set up autocommand to clean up job on buffer delete
  vim.api.nvim_create_autocmd("BufDelete", {
    buffer = M.state.terminal_buf,
    callback = function()
      if M.state.terminal_job_id then
        vim.fn.jobstop(M.state.terminal_job_id)
        M.state.terminal_job_id = nil
      end
    end,
  })

  local opts = { buffer = M.state.terminal_buf, silent = true }
  vim.keymap.set("n", "<leader>tt", M.open_terminal, opts)
  vim.keymap.set("n", "q", function()
    M.state.terminal_open = false
    if M.state.terminal_job_id then
      vim.fn.jobstop(M.state.terminal_job_id)
      M.state.terminal_job_id = nil
    end
    rearrange_panels()
  end, opts)

  -- Add escape to exit terminal mode
  vim.keymap.set("t", "<Esc>", "<C-\\><C-n>", { buffer = M.state.terminal_buf, silent = true })
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

render_todo = function()
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

-- Open TODO panel
function M.open_todo_panel()
  if M.state.todo_open then
    return
  end

  -- Create buffer if needed
  if not M.state.todo_buf or not vim.api.nvim_buf_is_valid(M.state.todo_buf) then
    M.state.todo_buf = vim.api.nvim_create_buf(false, true)
    vim.api.nvim_buf_set_name(M.state.todo_buf, "TODO-" .. M.state.todo_buf)
    vim.api.nvim_buf_set_option(M.state.todo_buf, "buftype", "nofile")
    vim.api.nvim_buf_set_option(M.state.todo_buf, "bufhidden", "hide")
    vim.api.nvim_buf_set_option(M.state.todo_buf, "buflisted", false)
  end

  M.state.todo_open = true
  rearrange_panels()

  -- Setup window options and render
  if M.state.todo_win and vim.api.nvim_win_is_valid(M.state.todo_win) then
    vim.wo[M.state.todo_win].number = false
    vim.wo[M.state.todo_win].relativenumber = false
    vim.wo[M.state.todo_win].signcolumn = "no"
  end

  render_todo()
  setup_todo_keymaps()
end

setup_todo_keymaps = function()
  if not M.state.todo_buf or not vim.api.nvim_buf_is_valid(M.state.todo_buf) then
    return
  end

  local opts = { buffer = M.state.todo_buf, silent = true, nowait = true }

  vim.keymap.set("n", "q", function()
    M.state.todo_open = false
    rearrange_panels()
  end, opts)

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

function M.focus_todo()
  if not M.state.todo_open then
    M.open_todo_panel()
  end

  if M.state.todo_win and vim.api.nvim_win_is_valid(M.state.todo_win) then
    vim.api.nvim_set_current_win(M.state.todo_win)
  end
end

return M
