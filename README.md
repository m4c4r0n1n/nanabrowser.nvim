# nanabrowser.nvim

**A real terminal web browser + TODO list for Neovim!**

Browse the web and manage tasks without leaving your editor.

## Features

### Browser
- 🌐 **Real interactive terminal browser** (w3m/lynx/links)
- 📦 **Opens at bottom** of screen (configurable position)
- ⌨️ **Full keyboard navigation** - type, click, scroll
- 🔗 **Open URLs** from cursor or prompt
- 🎨 **Clean interface** with rounded borders

### TODO List
- ✅ **Persistent TODO list** saved to disk
- ➕ Add/delete/toggle tasks
- 📝 Simple keyboard shortcuts
- 💾 Auto-saves

## Dependencies

Choose your browser:
- `w3m` - Recommended, best compatibility
- `lynx` - Classic, very stable
- `links` - Modern alternative

Install on Arch Linux:
```bash
sudo pacman -S w3m
# or
sudo pacman -S lynx
# or
sudo pacman -S links
```

## Installation

### lazy.nvim

```lua
{
  "nanabrowser.nvim",
  dir = "~/projects/nanabrowser.nvim",
  lazy = false,
  config = function()
    require("nanabrowser").setup({
      browser = "w3m", -- w3m, lynx, links
      position = "bottom", -- bottom, right, float
      size = 20, -- height/width of window
      border = "rounded",
    })
  end,
  keys = {
    -- Browser
    { "<leader>wb", "<cmd>NanaBrowserPrompt<cr>", desc = "Open browser" },
    { "<leader>wc", "<cmd>NanaBrowserCursor<cr>", desc = "Browse URL under cursor" },
    { "<leader>wt", "<cmd>NanaBrowserToggle<cr>", desc = "Toggle browser" },
    { "gx", "<cmd>NanaBrowserCursor<cr>", desc = "Open URL", mode = { "n", "v" } },
    -- TODO List
    { "<leader>td", "<cmd>NanaTodosToggle<cr>", desc = "Toggle TODO list" },
  },
}
```

## Usage

### Browser Commands

| Command | Description |
|---------|-------------|
| `:NanaBrowser <url>` | Open URL in browser |
| `:NanaBrowserPrompt` | Prompt for URL |
| `:NanaBrowserCursor` | Open URL under cursor |
| `:NanaBrowserToggle` | Toggle browser window |
| `:NanaBrowserClose` | Close browser |

### Browser Keybindings

| Key | Action |
|-----|--------|
| `<leader>wb` | Prompt for URL |
| `<leader>wc` | Open URL under cursor |
| `<leader>wt` | Toggle browser |
| `gx` | Open URL (replaces default) |
| `q` (in browser, normal mode) | Close browser |
| `<Esc>` | Exit insert mode in browser |

### TODO List

| Command | Description |
|---------|-------------|
| `:NanaTodos` | Open TODO list |
| `:NanaTodosToggle` | Toggle TODO list |

**TODO Keybindings (in TODO buffer):**
| Key | Action |
|-----|--------|
| `<leader>td` | Toggle TODO list |
| `a` | Add new TODO |
| `d` | Delete TODO under cursor |
| `x` | Toggle done/undone |
| `q` | Close TODO list |

## Examples

**Open a webpage:**
```vim
:NanaBrowser https://github.com
```

**Quick browse:**
1. Put cursor on any URL in text
2. Press `gx`
3. Browser opens at bottom with that page
4. Press `<Esc>` then `q` to close

**Manage TODOs:**
1. Press `<leader>td`
2. Press `a` to add a task
3. Press `x` to mark as done
4. Press `d` to delete
5. Press `q` to close

**Interactive browsing:**
- Browser opens in **terminal mode** (you can type!)
- Use arrow keys or vim keys to navigate
- Press Enter to follow links
- Press `<Esc>` to exit terminal mode
- Press `q` to close browser

## Tips

- **Google/Facebook alternatives:** Use DuckDuckGo (works better in w3m)
- **Terminal navigation:** Learn w3m/lynx keybindings for best experience
- **Split position:** Change `position = "right"` for vertical split
- **Window size:** Adjust `size = 30` for larger browser window

## Why nanabrowser?

- **Stay focused** - No context switching
- **Lightweight** - Terminal browsers use minimal resources
- **Keyboard-driven** - No mouse needed
- **Distraction-free** - No ads, no animations
- **Productivity** - Integrated TODO list
- **Privacy** - Text-only browsing

## License

MIT
