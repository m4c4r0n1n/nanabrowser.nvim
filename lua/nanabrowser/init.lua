-- nanabrowser.nvim - TODO list manager for Neovim
-- Note: For browser, we recommend using w3m.vim plugin instead

local M = {}

M.config = {
  position = "bottom", -- bottom, right
  size = 15, -- height/width of panel
  border = "rounded",
}

M.state = {
  todo_buf = nil,
  todo_win = nil,
  todos = {},
}

function M.setup(opts)
  M.config = vim.tbl_deep_extend("force", M.config, opts or {})
  M.load_todos()
end

-- Load todos from file
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

-- Save todos to file
function M.save_todos()
  local todo_file = vim.fn.stdpath("data") .. "/nanabrowser_todos.json"
  local content = vim.fn.json_encode(M.state.todos)
  vim.fn.writefile({ content }, todo_file)
end

-- Render todo list in buffer
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

-- Open TODO list
function M.open_todos()
  -- Check if already open
  if M.state.todo_win and vim.api.nvim_win_is_valid(M.state.todo_win) then
    vim.api.nvim_set_current_win(M.state.todo_win)
    return
  end

  -- Determine split command
  local split_cmd
  if M.config.position == "bottom" then
    split_cmd = string.format("botright %dsplit", M.config.size)
  elseif M.config.position == "right" then
    split_cmd = string.format("botright %dvsplit", M.config.size)
  else
    split_cmd = string.format("botright %dsplit", M.config.size)
  end

  -- Create split
  vim.cmd(split_cmd)

  -- Create or reuse buffer
  if not M.state.todo_buf or not vim.api.nvim_buf_is_valid(M.state.todo_buf) then
    M.state.todo_buf = vim.api.nvim_create_buf(false, true)
  end

  vim.api.nvim_win_set_buf(0, M.state.todo_buf)
  M.state.todo_win = vim.api.nvim_get_current_win()

  -- Buffer options
  vim.api.nvim_buf_set_option(M.state.todo_buf, "buftype", "nofile")
  vim.api.nvim_buf_set_option(M.state.todo_buf, "bufhidden", "hide")
  vim.api.nvim_buf_set_option(M.state.todo_buf, "swapfile", false)
  vim.api.nvim_buf_set_option(M.state.todo_buf, "filetype", "nanabrowser-todo")
  vim.api.nvim_buf_set_name(M.state.todo_buf, "TODO Manager")

  -- Window options
  vim.wo.number = false
  vim.wo.relativenumber = false
  vim.wo.signcolumn = "no"
  vim.wo.wrap = false
  vim.wo.cursorline = true

  render_todos()

  -- Keymaps
  local opts = { buffer = M.state.todo_buf, silent = true, nowait = true }

  -- Add todo
  vim.keymap.set("n", "a", function()
    vim.ui.input({ prompt = "New TODO: " }, function(text)
      if text and text ~= "" then
        table.insert(M.state.todos, { text = text, done = false })
        M.save_todos()
        render_todos()
      end
    end)
  end, opts)

  -- Delete todo
  vim.keymap.set("n", "d", function()
    local line = vim.fn.line(".")
    local idx = line - 5 -- Account for header lines
    if idx > 0 and idx <= #M.state.todos then
      table.remove(M.state.todos, idx)
      M.save_todos()
      render_todos()
      vim.notify("TODO deleted", vim.log.levels.INFO)
    end
  end, opts)

  -- Toggle done
  vim.keymap.set("n", "x", function()
    local line = vim.fn.line(".")
    local idx = line - 5
    if idx > 0 and idx <= #M.state.todos then
      M.state.todos[idx].done = not M.state.todos[idx].done
      M.save_todos()
      render_todos()
    end
  end, opts)

  -- Edit todo
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

  -- Close (fixed to not close if it's the last window)
  vim.keymap.set("n", "q", function()
    M.close_todos()
  end, opts)
end

-- Close TODO list
function M.close_todos()
  if M.state.todo_win and vim.api.nvim_win_is_valid(M.state.todo_win) then
    -- Check if this is the last window
    local wins = vim.api.nvim_list_wins()
    local valid_wins = 0
    for _, win in ipairs(wins) do
      if vim.api.nvim_win_is_valid(win) and vim.api.nvim_win_get_config(win).relative == "" then
        valid_wins = valid_wins + 1
      end
    end

    if valid_wins > 1 then
      vim.api.nvim_win_close(M.state.todo_win, false)
      M.state.todo_win = nil
    else
      vim.notify("Cannot close last window. Open another split first.", vim.log.levels.WARN)
    end
  end
end

-- Toggle TODO list
function M.toggle_todos()
  if M.state.todo_win and vim.api.nvim_win_is_valid(M.state.todo_win) then
    M.close_todos()
  else
    M.open_todos()
  end
end

return M
