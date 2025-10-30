-- nanabrowser.nvim - Convert webpages to ASCII in Neovim

if vim.g.loaded_nanabrowser then
  return
end
vim.g.loaded_nanabrowser = 1

-- Commands
vim.api.nvim_create_user_command("NanaBrowser", function(opts)
  require("nanabrowser").open_url(opts.args)
end, {
  nargs = 1,
  desc = "Open URL in nanabrowser",
})

vim.api.nvim_create_user_command("NanaBrowserPrompt", function()
  require("nanabrowser").open_url_prompt()
end, {
  desc = "Prompt for URL to open in nanabrowser",
})

vim.api.nvim_create_user_command("NanaBrowserCursor", function()
  require("nanabrowser").open_url_under_cursor()
end, {
  desc = "Open URL under cursor in nanabrowser",
})
