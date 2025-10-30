# nanabrowser.nvim

**TODO Manager for Neovim** - Simple, persistent task management in a bottom panel.

> **Note:** This plugin focuses on TODO management. For web browsing in Neovim, we recommend [w3m.vim](https://github.com/yuratomo/w3m.vim) which provides full w3m integration.

## Features

- ✅ **Persistent TODO list** - Saves to disk automatically
- 📦 **Bottom panel** - Opens in a dedicated split (SpaceVim-style)
- ⌨️ **Simple keybindings** - Add, edit, delete, toggle tasks
- 💾 **Auto-save** - Never lose your TODOs
- 🎨 **Clean interface** - Checkboxes and strikethrough for completed tasks
- 📝 **Edit support** - Modify existing TODOs

## Installation

### lazy.nvim

```lua
{
  "nanabrowser.nvim",
  dir = "~/projects/nanabrowser.nvim",
  lazy = false,
  config = function()
    require("nanabrowser").setup({
      position = "bottom", -- bottom or right
      size = 15, -- height/width of panel
      border = "rounded",
    })
  end,
  keys = {
    { "<leader>td", "<cmd>NanaTodosToggle<cr>", desc = "Toggle TODO Manager" },
  },
}
```

### With w3m.vim for browsing

```lua
-- TODO Manager
{
  "nanabrowser.nvim",
  dir = "~/projects/nanabrowser.nvim",
  lazy = false,
  config = function()
    require("nanabrowser").setup()
  end,
  keys = {
    { "<leader>td", "<cmd>NanaTodosToggle<cr>", desc = "Toggle TODO Manager" },
  },
},

-- Web Browser (w3m.vim)
{
  "yuratomo/w3m.vim",
  cmd = { "W3m", "W3mTab" },
  keys = {
    { "<leader>wb", "<cmd>W3m<cr>", desc = "Open w3m browser" },
    { "gx", "<cmd>W3mTab <cWORD><cr>", desc = "Open URL in w3m" },
  },
}
```

## Usage

### Commands

| Command | Description |
|---------|-------------|
| `:NanaTodos` | Open TODO Manager |
| `:NanaTodosToggle` | Toggle TODO Manager |
| `:NanaTodosClose` | Close TODO Manager |

### Keybindings

**Global:**
- `<leader>td` - Toggle TODO Manager

**In TODO Manager:**
- `a` - Add new TODO
- `e` - Edit TODO under cursor
- `d` - Delete TODO under cursor
- `x` - Toggle done/undone
- `q` - Close TODO Manager

## Quick Start

1. **Open TODO Manager:**
   ```vim
   :NanaTodos
   ```
   Or press `<leader>td`

2. **Add a task:** Press `a`

3. **Mark as done:** Move cursor to task, press `x`

4. **Edit a task:** Move cursor to task, press `e`

5. **Delete a task:** Move cursor to task, press `d`

6. **Close:** Press `q`

## Configuration

```lua
require("nanabrowser").setup({
  position = "bottom", -- "bottom" or "right"
  size = 15,           -- Height (if bottom) or width (if right)
  border = "rounded",  -- Border style
})
```

## Data Storage

TODOs are saved to: `~/.local/share/nvim/nanabrowser_todos.json`

## Why nanabrowser?

- **Lightweight** - Pure Lua, no external dependencies
- **Persistent** - TODOs survive Neovim restarts
- **Focused** - Does one thing well
- **Clean UI** - Inspired by SpaceVim's panel system
- **Keyboard-driven** - No mouse needed

## Recommended Companion Plugins

- **[w3m.vim](https://github.com/yuratomo/w3m.vim)** - Full-featured w3m browser integration
- **[toggleterm.nvim](https://github.com/akinsho/toggleterm.nvim)** - Enhanced terminal management

## License

MIT
