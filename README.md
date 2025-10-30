# nanabrowser.nvim

**SpaceVim-inspired tabbed panel system for Neovim**

One persistent bottom panel with tabs for Browser, TODO Manager, and Terminal.

## Features

- 📦 **Tabbed bottom panel** - Like SpaceVim screenshot!
- 🌐 **Browser tab** - w3m for web browsing
- ✅ **TODO tab** - Persistent task management
- 💻 **Terminal tab** - Quick shell access
- 🔢 **Press 1/2/3** - Switch between tabs instantly
- ⌨️ **Keyboard-first** - No mouse needed
- 🎨 **Contained & boxed** - Clean, organized interface

## Installation

```lua
{
  "nanabrowser.nvim",
  dir = "~/projects/nanabrowser.nvim",
  lazy = false,
  config = function()
    require("nanabrowser").setup({
      browser = "w3m",  -- or lynx, links
      size = 20,        -- panel height
    })
  end,
  keys = {
    { "<leader>p", function() require("nanabrowser").toggle_panel() end, desc = "Toggle panel" },
    { "<leader>wb", function() require("nanabrowser").open_browser_prompt() end, desc = "Browse URL" },
    { "gx", function() require("nanabrowser").open_browser_cursor() end, desc = "Open URL" },
    { "<leader>td", function() require("nanabrowser").open_panel("todo") end, desc = "Open TODO" },
    { "<leader>tt", function() require("nanabrowser").open_terminal() end, desc = "Open terminal" },
  },
}
```

## Usage

### Panel Control

**Keybindings:**
- `<leader>p` - Toggle panel open/close
- `1` - Switch to Browser tab
- `2` - Switch to TODO tab
- `3` - Switch to Terminal tab
- `q` - Close panel

### Browser

**Launch:**
- `<leader>wb` - Prompt for URL, opens in Browser tab
- `gx` (on URL) - Opens URL in Browser tab

**Navigation:**
- Arrow keys / vim keys - Navigate page
- Enter - Follow links
- `<Esc>` then `q` - Back to tab view

### TODO Manager

**Launch:**
- `<leader>td` - Opens panel on TODO tab
- Or press `<leader>p` then `2`

**Actions:**
- `a` - Add new TODO
- `e` - Edit TODO under cursor
- `x` - Toggle done/undone
- `d` - Delete TODO

### Terminal

**Launch:**
- `<leader>tt` - Opens panel with terminal
- Or press `<leader>p` then `3`

**Usage:**
- Type shell commands as normal
- `<Esc>` then `q` - Back to tab view

## How It Works

1. **One persistent panel** at the bottom
2. **Three tabs**: Browser │ TODO │ Terminal
3. **Tab bar** shows which is active: `[1] Browser  2 TODO  3 Terminal`
4. **Launch actions** (`<leader>wb`, etc.) automatically open the panel on that tab
5. **Switch tabs** with `1`/`2`/`3` keys
6. **Clean & contained** - Everything in one boxed area

## Quick Start

```vim
" Open panel
<leader>p

" Switch to TODO tab
2

" Add a task
a

" Switch to Browser
1

" Close panel
q
```

## Configuration

```lua
require("nanabrowser").setup({
  browser = "w3m",  -- Terminal browser (w3m, lynx, links)
  size = 20,        -- Panel height in lines
  border = "rounded",
})
```

## Dependencies

- **w3m**: `sudo pacman -S w3m`
- Or **lynx**: `sudo pacman -S lynx`
- Or **links**: `sudo pacman -S links`

## Why nanabrowser?

- **SpaceVim-style** - Exact tabbed panel UI from the screenshot
- **Contained** - Everything in one persistent bottom box
- **Organized** - No overlapping windows, clean tabs
- **Fast switching** - Press 1/2/3 to jump between features
- **Lightweight** - Pure Lua, simple dependencies

## License

MIT
