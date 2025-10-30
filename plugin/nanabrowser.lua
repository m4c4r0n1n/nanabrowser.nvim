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
  desc = "Open browser at bottom",
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
