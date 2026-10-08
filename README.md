<div align="center">

# nanabrowser.nvim

**Browser │ Terminal │ TODO panels for Neovim.** One key opens all three.

<a href="https://github.com/neovim/neovim/releases"><img alt="Neovim 0.11+" src="https://img.shields.io/badge/Neovim-0.11%2B-c4a7e7?logo=neovim&logoColor=e0def4&style=for-the-badge&labelColor=232136" /></a>
<a href="https://github.com/m4c4r0n1n/nanabrowser.nvim/commits/main"><img alt="Last commit" src="https://img.shields.io/github/last-commit/m4c4r0n1n/nanabrowser.nvim?logo=git&logoColor=e0def4&color=f6c177&style=for-the-badge&labelColor=232136" /></a>
<a href="https://github.com/m4c4r0n1n/nanabrowser.nvim/commits/main"><img alt="Maintained: yes" src="https://img.shields.io/badge/Maintained%3F-yes-9ccfd8?style=for-the-badge&labelColor=232136" /></a>
<a href="LICENSE"><img alt="License" src="https://img.shields.io/github/license/m4c4r0n1n/nanabrowser.nvim?color=ea9a97&style=for-the-badge&labelColor=232136" /></a>
<a href="https://ko-fi.com/koifist"><img alt="Ko-fi" src="https://img.shields.io/badge/Ko--fi-support-eb6f92?logo=kofi&logoColor=e0def4&style=for-the-badge&labelColor=232136" /></a>

</div>

<img width="1718" height="1400" alt="nanabrowser panels" src="https://github.com/user-attachments/assets/4a58d05b-9f2a-4452-9057-99055eb3fc5a" />

<img width="1706" height="1384" alt="nanabrowser in use" src="https://github.com/user-attachments/assets/ea286d6b-ef4d-4b0a-9670-8a3c56f7713b" />

Built for [nananvim](https://github.com/m4c4r0n1n/nananvim). Works in any config.

## Features

- 🌐 **Browser**: w3m, lynx or elinks in a panel. `gx` sends a URL to your real browser.
- 💻 **Terminal**: a shell in a panel.
- ✅ **TODO**: a small task list, saved between sessions.
- 📐 **Adaptive layout**: side by side on a wide screen, a tabbed float on a narrow one.
- 💤 **Hide, not kill**: `<leader>p` hides the panels. Your shell and page keep running.
- 🎨 **Uses your theme**: colors come from your colorscheme, blackout mode included.
- 🧩 **Custom panels**: add your own with `register_panel()`.

## Requirements

- Neovim 0.11+
- A text browser (optional): install `w3m` with your package manager. Without one, URLs open in your external browser.

Run `:checkhealth nanabrowser` to see what it found.

## Installation

[lazy.nvim](https://github.com/folke/lazy.nvim), the same spec nananvim uses:

```lua
{
  "m4c4r0n1n/nanabrowser.nvim",
  lazy = false,
  opts = {},
  keys = {
    { "<leader>p", function() require("nanabrowser").toggle_panels() end, desc = "Toggle panels" },
    { "<leader>z", function() require("nanabrowser").toggle_zoom() end, desc = "Zoom panel" },
    { "<leader>wb", function() require("nanabrowser").open_browser_prompt() end, desc = "Browse URL (in-editor)" },
    { "<leader>wo", function() require("nanabrowser").open_external_prompt() end, desc = "Open URL (external)" },
    { "gx", function() require("nanabrowser").open_external_cursor() end, desc = "Open URL in browser", mode = { "n", "v" } },
    { "<leader>tt", function() require("nanabrowser").open_terminal() end, desc = "Terminal panel" },
    { "<leader>td", function() require("nanabrowser").focus_todo() end, desc = "Focus TODO" },
  },
}
```

## Keys

| Key | Does |
| --- | --- |
| `<Tab>` / `<S-Tab>` | Next / previous panel |
| `q` | Hide the panel. The program keeps running |
| `<leader>z` | Zoom one panel, or show all again |
| `<Esc>` | Leave terminal mode |
| `a` / `x` / `e` / `d` | TODO: add / done / edit / delete |

To end the shell or w3m, quit it in the panel (`exit`, or `q` in w3m).

## Commands

| Command | Does |
| --- | --- |
| `:NanaPanels` | Show / hide all panels |
| `:NanaZoom` | Zoom one panel, or show all |
| `:NanaPanel {name}` | Open one panel |
| `:NanaBrowser [url]` | Open the text browser |
| `:NanaBrowserPrompt` / `:NanaBrowserCursor` | Ask for a URL / use the one under the cursor |
| `:NanaExternal [url]` | Open a URL in your real browser |
| `:NanaTerminal` / `:NanaTerminalToggle` | Open / toggle the terminal |
| `:NanaTodos` / `:NanaTodosToggle` | Open / toggle the TODO list |

URLs can skip `https://`. Local paths open as files and `localhost:3000` opens over http.

## Configuration

Defaults. Set only what you want to change:

```lua
require("nanabrowser").setup({
  text_browser = nil,     -- nil = w3m > lynx > elinks, or "w3m -no-mouse"
  external_browser = nil, -- nil = $BROWSER > system opener > brave/chromium/firefox
  layout = "auto",        -- "auto" | "float" | "split"
  auto_min_width = 40,    -- columns per panel before "auto" uses a float
  reader_mode = false,    -- true = static page dump
  float = { width = 0.85, height = 0.85, border = "rounded", hints = true },
  split = { position = "botright", size = 0.35 },
  default_panels = { "browser", "terminal", "todo" },
  home = "https://duckduckgo.com/html",
  highlights = nil,       -- nil = colors from your colorscheme
})
```

## Theming

The groups link to standard ones, so theme changes carry over: `NanaPanelNormal` (NormalFloat), `NanaPanelBorder` (FloatBorder), `NanaPanelTitle` (FloatTitle), `NanaPanelNC`, `NanaPanelTab`, `NanaPanelKey`, `NanaPanelHint` and `NanaTodoDone`.

Change one in a `ColorScheme` autocmd:

```lua
vim.api.nvim_create_autocmd("ColorScheme", {
  callback = function()
    vim.api.nvim_set_hl(0, "NanaPanelBorder", { fg = "#89b4fa" })
  end,
})
```

For fixed colors: `highlights = { border = "#89b4fa", bg = "#1e1e2e", bg_nc = "#181825" }`.

## Custom panels

```lua
local nana = require("nanabrowser")

nana.register_panel("notes", {
  title = "🗒 Notes",
  render = function(buf)
    vim.api.nvim_buf_set_lines(buf, 0, -1, false, { "scratch notes" })
  end,
})

vim.keymap.set("n", "<leader>pn", function() nana.open_panel("notes") end)
```

Add `"notes"` to `default_panels` to open it with the others.

## License

MIT
