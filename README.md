# nanabrowser.nvim

**Side-by-side panels at the bottom of your screen**

Browser │ Terminal │ TODO - All visible at once!

```
┌────────────────────────────────────────────────────┐
│              Main Editor Area                      │
├──────────────┬──────────────┬──────────────────────┤
│   Browser    │   Terminal   │       TODO           │
│   (w3m)      │   (shell)    │   (task list)        │
└──────────────┴──────────────┴──────────────────────┘
```

## Features

- 🎨 **Side-by-side layout** - All 3 panels visible at once
- 🌐 **Browser** - w3m for web browsing
- 💻 **Terminal** - Shell access
- ✅ **TODO** - Task management
- 📦 **Contained & boxed** - Clean bottom panel area
- ⌨️ **One keybinding** - `<leader>p` toggles all panels

## Installation

```lua
{
  "nanabrowser.nvim",
  dir = "~/projects/nanabrowser.nvim",
  lazy = false,
  config = function()
    require("nanabrowser").setup({
      browser = "w3m",
      height = 20,           -- Height of panel area
      browser_width = 40,    -- Browser width %
      terminal_width = 30,   -- Terminal width %
      todo_width = 30,       -- TODO width %
    })
  end,
  keys = {
    { "<leader>p", function() require("nanabrowser").toggle_panels() end, desc = "Toggle panels" },
    { "<leader>wb", function() require("nanabrowser").open_browser_prompt() end, desc = "Browse URL" },
    { "gx", function() require("nanabrowser").open_browser_cursor() end, desc = "Open URL" },
    { "<leader>tt", function() require("nanabrowser").open_terminal() end, desc = "Open terminal" },
  },
}
```

## Usage

### Open/Close Panels

```vim
<leader>p
```
- Opens all 3 panels at bottom
- Press again to close all

### Browser (Left Panel)

**Launch:**
- `<leader>wb` - Prompt for URL
- `gx` on any URL - Opens that URL

**Navigate:**
- Arrow keys or vim keys
- Enter to follow links
- `<Esc>` to exit terminal mode

### Terminal (Middle Panel)

**Launch:**
```vim
<leader>tt
```
Then type shell commands as normal

### TODO (Right Panel)

**Always visible** when panels are open!

**Actions:**
- `a` - Add new TODO
- `x` - Toggle done/undone
- `d` - Delete TODO

## Quick Start

```vim
" 1. Open panels
<leader>p

" 2. Start browsing (left panel)
<leader>wb

" 3. Open terminal (middle panel)
<leader>tt

" 4. Add TODO (right panel - click/navigate there)
" Navigate to TODO panel, press 'a'
```

## Configuration

```lua
require("nanabrowser").setup({
  browser = "w3m",       -- or lynx, browsh, links
  height = 20,           -- Panel area height (lines)
  browser_width = 40,    -- Browser width (%)
  terminal_width = 30,   -- Terminal width (%)
  todo_width = 30,       -- TODO width (%)
  borders = true,        -- Enable Telescope-style borders
  border_style = "rounded", -- Options: "rounded", "solid", "double", "none"
})
```

**Adjust widths** to your preference:
- All 3 should add up to 100%
- Example: `50, 30, 20` = Browser takes half screen

## Dependencies

- **w3m**: `sudo pacman -S w3m`

## Why This Design?

- **All visible** - No switching, see everything at once
- **Organized** - Each feature in its own contained box
- **Efficient** - One command opens/closes all
- **Clean** - Boxed layout, professional look
- **Practical** - Like having 3 mini apps at the bottom

## License

MIT
