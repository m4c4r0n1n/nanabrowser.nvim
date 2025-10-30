-- nanabrowser.nvim - TODO Manager for Neovim
-- For browser functionality, use w3m.vim plugin

if vim.g.loaded_nanabrowser then
  return
end
vim.g.loaded_nanabrowser = 1

-- TODO Commands
vim.api.nvim_create_user_command("NanaTodos", function()
  require("nanabrowser").open_todos()
end, {
  desc = "Open TODO list manager",
})

vim.api.nvim_create_user_command("NanaTodosToggle", function()
  require("nanabrowser").toggle_todos()
end, {
  desc = "Toggle TODO list manager",
})

vim.api.nvim_create_user_command("NanaTodosClose", function()
  require("nanabrowser").close_todos()
end, {
  desc = "Close TODO list manager",
})
