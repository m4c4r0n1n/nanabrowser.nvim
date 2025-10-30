# nanabrowser.nvim

A full-featured ASCII web browser for Neovim! Browse the web without leaving your editor.

## Features

- 🌐 Full webpage rendering in ASCII
- 🖼️ Images converted to ASCII art (via chafa)
- 🔗 **Clickable links** - Press Enter on numbered links
- ⬅️ **Browser navigation** - Back/forward with Ctrl-o/Ctrl-i
- ⚡ Fast and lightweight (powered by w3m)
- 📜 Browse history
- 🔄 Refresh pages

## Dependencies

- `w3m` - Terminal web browser (for rendering HTML)
- `chafa` - Image-to-ASCII converter (optional, for images)

Install on Arch Linux:
```bash
sudo pacman -S w3m chafa
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

### Navigation (in browser buffer)

- `<Enter>` - Follow numbered link
- `<C-o>` - Go back in history
- `<C-i>` - Go forward in history
- `r` - Refresh current page
- `<leader>wb` - Open new URL

### Examples

```vim
:NanaBrowser https://example.com
:NanaBrowserPrompt
```

**Interactive browsing:**
1. Open a page: `:NanaBrowser https://github.com`
2. Scroll down to the links section
3. Put cursor on `[1] https://...`
4. Press `<Enter>` to follow the link
5. Use `<C-o>` to go back

## Configuration

```lua
require("nanabrowser").setup({
  width = 120,                    -- Terminal width for rendering
  show_images = true,             -- Convert images to ASCII art
  image_width = 80,               -- Width for ASCII images
  user_agent = "Mozilla/5.0...",  -- Custom user agent
  timeout = 30,                   -- Request timeout in seconds
})
```

## License

MIT
