# nanabrowser.nvim

A Neovim plugin to browse webpages as ASCII/Markdown directly in your editor.

## Features

- 🌐 Fetch and convert webpages to readable text
- 📝 Outputs as Markdown (with pandoc)
- ⚡ Fast and lightweight
- 🎨 Syntax highlighting in markdown format
- 🔗 Open URLs from cursor position

## Dependencies

- `curl` - for fetching webpages
- `pandoc` - for HTML to Markdown conversion

Install on Arch Linux:
```bash
sudo pacman -S curl pandoc
```

## Installation

### lazy.nvim

```lua
{
  "nanabrowser.nvim",
  dir = "~/projects/nanabrowser.nvim",
  config = function()
    require("nanabrowser").setup({
      output_format = "markdown", -- or "plain"
      default_width = 80,
      timeout = 30,
    })
  end,
  keys = {
    { "<leader>wb", "<cmd>NanaBrowserPrompt<cr>", desc = "Browse URL" },
    { "<leader>wc", "<cmd>NanaBrowserCursor<cr>", desc = "Browse URL under cursor" },
  },
}
```

## Usage

### Commands

- `:NanaBrowser <url>` - Open a specific URL
- `:NanaBrowserPrompt` - Prompt for URL to open
- `:NanaBrowserCursor` - Open URL under cursor

### Examples

```vim
:NanaBrowser https://github.com
:NanaBrowserPrompt
```

Or use the keybindings:
- `<leader>wb` - Prompt for URL
- `<leader>wc` - Open URL under cursor

## Configuration

```lua
require("nanabrowser").setup({
  converter = "pandoc",           -- HTML converter (currently only pandoc)
  output_format = "markdown",     -- Output format: "markdown" or "plain"
  user_agent = "Mozilla/5.0...",  -- Custom user agent
  timeout = 30,                   -- Curl timeout in seconds
  default_width = 80,             -- Text width for wrapping
})
```

## License

MIT
