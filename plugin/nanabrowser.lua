-- nanabrowser.nvim - Panel system for Neovim
-- Browser, TODO Manager, and Terminal in bottom panels

if vim.g.loaded_nanabrowser then
  return
end
vim.g.loaded_nanabrowser = 1

-- Browser Commands
vim.api.nvim_create_user_command("NanaBrowser", function(opts)
  require("nanabrowser").open_browser(opts.args)
end, {
  nargs = "?",
  complete = function(arglead)
    return require("nanabrowser").complete_url(arglead)
  end,
  desc = "Open browser at bottom (Tab-completes recent URLs)",
})

vim.api.nvim_create_user_command("NanaBrowserPrompt", function()
  require("nanabrowser").open_browser_prompt()
end, {
  desc = "Prompt for URL",
})

vim.api.nvim_create_user_command("NanaBrowserCursor", function()
  require("nanabrowser").open_browser_cursor()
end, {
  desc = "Open URL under cursor",
})

-- TODO Commands
vim.api.nvim_create_user_command("NanaTodos", function()
  require("nanabrowser").open_todos()
end, {
  desc = "Open TODO manager",
})

vim.api.nvim_create_user_command("NanaTodosToggle", function()
  require("nanabrowser").toggle_todos()
end, {
  desc = "Toggle TODO manager",
})

-- Terminal Commands
vim.api.nvim_create_user_command("NanaTerminal", function()
  require("nanabrowser").open_terminal()
end, {
  desc = "Open terminal panel",
})

vim.api.nvim_create_user_command("NanaTerminalToggle", function()
  require("nanabrowser").toggle_terminal()
end, {
  desc = "Toggle terminal panel",
})

-- Workspace / layout Commands
vim.api.nvim_create_user_command("NanaPanels", function()
  require("nanabrowser").toggle_panels()
end, {
  desc = "Toggle the full panel workspace",
})

vim.api.nvim_create_user_command("NanaZoom", function()
  require("nanabrowser").toggle_zoom()
end, {
  desc = "Toggle focus-one / show-all panel zoom",
})

vim.api.nvim_create_user_command("NanaPanel", function(opts)
  require("nanabrowser").open_panel(opts.args)
end, {
  nargs = 1,
  complete = function(arglead)
    local names = require("nanabrowser").panel_names()
    local hit = {}
    for _, n in ipairs(names) do
      if n:find(arglead, 1, true) == 1 then
        hit[#hit + 1] = n
      end
    end
    return hit
  end,
  desc = "Open a single panel by name (built-in or registered)",
})
