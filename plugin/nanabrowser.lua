-- nanabrowser.nvim - Terminal browser and TODO list for Neovim

if vim.g.loaded_nanabrowser then
  return
end
vim.g.loaded_nanabrowser = 1

-- Browser Commands
vim.api.nvim_create_user_command("NanaBrowser", function(opts)
  require("nanabrowser").open_browser(opts.args)
end, {
  nargs = "?",
  desc = "Open URL in terminal browser at bottom",
})

vim.api.nvim_create_user_command("NanaBrowserPrompt", function()
  require("nanabrowser").open_browser_prompt()
end, {
  desc = "Prompt for URL to open in browser",
})

vim.api.nvim_create_user_command("NanaBrowserCursor", function()
  require("nanabrowser").open_browser_cursor()
end, {
  desc = "Open URL under cursor in browser",
})

vim.api.nvim_create_user_command("NanaBrowserClose", function()
  require("nanabrowser").close_browser()
end, {
  desc = "Close terminal browser",
})

vim.api.nvim_create_user_command("NanaBrowserToggle", function()
  require("nanabrowser").toggle_browser()
end, {
  desc = "Toggle terminal browser",
})

-- TODO Commands
vim.api.nvim_create_user_command("NanaTodos", function()
  require("nanabrowser").open_todos()
end, {
  desc = "Open TODO list",
})

vim.api.nvim_create_user_command("NanaTodosToggle", function()
  require("nanabrowser").toggle_todos()
end, {
  desc = "Toggle TODO list",
})
