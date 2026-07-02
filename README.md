## UPDATES!!
I've tried to update this a bit, if you use it with a different config other than Nananvim and it doesn't work, let me know what's going on and I will resolve the issue as fast as I can. I may break this up to three separate plugins that work together as a panel.. I'm not sure yet.. If anyone uses this, let me know your thoughts. Otherwise, I'll just send it. 

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

## Commands

Every action is also a plain user command, so it scripts and `<Tab>`-completes:

| Command | Does |
| --- | --- |
| `:NanaPanels` | Toggle the whole panel workspace (same as `<leader>p`) |
| `:NanaZoom` | Toggle focus-one ↔ show-all zoom |
| `:NanaPanel {name}` | Open one panel by name (Tab-completes: browser, terminal, todo, …) |
| `:NanaBrowser [url]` | Open the text browser; `<Tab>` completes recent URLs |
| `:NanaBrowserPrompt` / `:NanaBrowserCursor` | Prompt for a URL / open the one under the cursor |
| `:NanaTerminal` / `:NanaTerminalToggle` | Open / toggle the terminal panel |
| `:NanaTodos` / `:NanaTodosToggle` | Open / toggle the TODO panel |

## Extending — custom panels

The workspace is not limited to the three built-ins. Register your own panel and
it joins the auto/split/float layouts, zoom cycling, and `:NanaPanel` completion
automatically — no core edits:

```lua
local nana = require("nanabrowser")

nana.register_panel("notes", {
  title = "🗒 Notes",
  render = function(buf, name)
    vim.api.nvim_buf_set_lines(buf, 0, -1, false, { "scratch notes…" })
  end,
})

-- open it on demand …
vim.keymap.set("n", "<leader>pn", function() nana.open_panel("notes") end)
-- … or add it to the default workspace:
nana.setup({ default_panels = { "browser", "terminal", "todo", "notes" } })
```

## Configuration

```lua
require("nanabrowser").setup({
  text_browser = nil,        -- nil = auto (w3m > lynx > elinks); or force one
  external_browser = nil,    -- nil = auto ($BROWSER > xdg-open > brave/chromium/firefox)
  layout = "auto",           -- "auto" (side-by-side if wide enough, else tabbed) | "float" | "split"
  auto_min_width = 40,       -- min columns per panel before "auto" drops to a float
  reader_mode = false,       -- true = static -dump render (great for docs)
  float = { width = 0.85, height = 0.85, border = "rounded" },
  split = { position = "botright", size = 0.35 }, -- size = fraction of screen height
  default_panels = { "browser", "terminal", "todo" },
  home = "https://duckduckgo.com/html",
})
```

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
