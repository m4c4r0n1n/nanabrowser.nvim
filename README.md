# nanabrowser.nvim

**SpaceVim-inspired panel system for Neovim**

Browser, TODO Manager, and Terminal in clean bottom panels.

## Features

- 🌐 **Browser** - w3m in terminal at bottom with URL prompt
- ✅ **TODO Manager** - Persistent task list
- 💻 **Terminal** - Quick terminal access
- 📦 **Bottom panels** - SpaceVim-style interface
- ⌨️ **Keyboard-driven** - No mouse needed
- 🎨 **Clean UI** - Rounded borders, no clutter

## Installation

### lazy.nvim

```lua
{
  "nanabrowser.nvim",
  dir = "~/projects/nanabrowser.nvim",
  lazy = false,
  config = function()
    require("nanabrowser").setup({
      browser = "w3m",       -- w3m, lynx, links
      position = "bottom",   -- bottom or right
      size = 20,             -- height/width of panel
      border = "rounded",
    })
  end,
  keys = {
    -- Browser
    { "<leader>wb", "<cmd>NanaBrowserPrompt<cr>", desc = "Open browser" },
    { "gx", "<cmd>NanaBrowserCursor<cr>", desc = "Open URL" },
    -- TODO
    { "<leader>td", "<cmd>NanaTodosToggle<cr>", desc = "Toggle TODO" },
    -- Terminal
    { "<leader>tt", "<cmd>NanaTerminalToggle<cr>", desc = "Toggle terminal" },
  },
}
```

## Usage

### Browser

**Commands:**
- `:NanaBrowserPrompt` - Enter URL to browse
- `:NanaBrowserCursor` - Open URL under cursor

**Keybindings:**
- `<leader>wb` - Prompt for URL, opens browser at bottom
- `gx` - Open URL under cursor

**In browser:**
- Arrow keys / vim keys to navigate
- Enter to follow links
- `<Esc>` then `q` to close

### TODO Manager

**Commands:**
- `:NanaTodos` - Open TODO manager
- `:NanaTodosToggle` - Toggle TODO manager

**Keybindings:**
- `<leader>td` - Toggle TODO panel

**In TODO panel:**
- `a` - Add new TODO
- `e` - Edit TODO
- `x` - Toggle done/undone
- `d` - Delete TODO
- `q` - Close panel

### Terminal

**Commands:**
- `:NanaTerminal` - Open terminal
- `:NanaTerminalToggle` - Toggle terminal

**Keybindings:**
- `<leader>tt` - Toggle terminal panel

**In terminal:**
- Type commands as normal
- `<Esc>` then `q` to close

## Quick Start

**Browse the web:**
```vim
<leader>wb
```
Enter a URL and press Enter

**Manage TODOs:**
```vim
<leader>td
```
Press `a` to add a task

**Open terminal:**
```vim
<leader>tt
```

## Panel Behavior

- **Only one panel open at a time** - Opening a new panel closes the current one
- **Bottom position** - All panels open at the bottom (configurable)
- **Persistent** - TODOs save automatically
- **Clean close** - Press `q` in normal mode to close any panel

## Configuration

```lua
require("nanabrowser").setup({
  browser = "w3m",       -- Terminal browser to use
  position = "bottom",   -- "bottom" or "right"
  size = 20,             -- Height (bottom) or width (right)
  border = "rounded",    -- Border style
})
```

## Dependencies

- **w3m** (for browser): `sudo pacman -S w3m`
- Or use lynx/links: `sudo pacman -S lynx` or `links`

## Why nanabrowser?

- **All-in-one** - Browser, TODOs, terminal in one plugin
- **SpaceVim-inspired** - Clean panel system
- **Lightweight** - Pure Lua, minimal dependencies
- **Keyboard-first** - Vim-style navigation
- **Focused** - One panel at a time, no distractions

## License

MIT
