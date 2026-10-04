## UPDATES!!
I've tried to update this a bit, if you use it with a different config other than Nananvim and it doesn't work, let me know what's going on and I will resolve the issue as fast as I can. I may break this up to three separate plugins that work together as a panel.. I'm not sure yet.. If anyone uses this, let me know your thoughts. Otherwise, I'll just send it. 

# nanabrowser.nvim

**Browser │ Terminal │ TODO panels for Neovim.** One key opens all three.

<img width="1718" height="1400" alt="image" src="https://github.com/user-attachments/assets/4a58d05b-9f2a-4452-9057-99055eb3fc5a" />

and why not, a picture of it "working"


<img width="1706" height="1384" alt="image" src="https://github.com/user-attachments/assets/ea286d6b-ef4d-4b0a-9670-8a3c56f7713b" />

It's pretty easy to use. Any suggestions, let me know. 

Built for [nananvim](https://github.com/m4c4r0n1n/nananvim), works in any config.

## Features

- 🌐 **Browser**: w3m, lynx or elinks in a panel. `gx` sends a URL to your real browser.
- 💻 **Terminal**: a shell in a panel.
- ✅ **TODO**: a small task list, saved between sessions.
- 📐 **Adaptive layout**: side by side at the bottom on a wide screen, a tabbed float on a narrow one.
- 💤 **Hide, not kill**: `<leader>p` hides the panels. Your shell and your page are still there when you come back.
- 🎨 **Uses your theme**: panel colors come from your colorscheme, blackout mode included.
- 🧩 **Custom panels**: add your own with `register_panel()`.

## Requirements

- Neovim 0.11+
- A text browser (optional). Without one, URLs open in your external browser.

| System | Install |
| --- | --- |
| Arch | `sudo pacman -S w3m` |
| Debian / Ubuntu | `sudo apt install w3m` |
| Fedora | `sudo dnf install w3m` |
| macOS | `brew install w3m` |

Run `:checkhealth nanabrowser` to see what it found.

## Installation

[lazy.nvim](https://github.com/folke/lazy.nvim). This is the same spec nananvim ships in `lua/plugins/nanabrowser.lua`:

```lua
{
  "m4c4r0n1n/nanabrowser.nvim",
  lazy = false,
  opts = {}, -- see Configuration
  keys = {
    { "<leader>p", function() require("nanabrowser").toggle_panels() end, desc = "Toggle panels" },
    { "<leader>pz", function() require("nanabrowser").toggle_zoom() end, desc = "Zoom panel (focus one / show all)" },
    { "<leader>wb", function() require("nanabrowser").open_browser_prompt() end, desc = "Browse URL (in-editor)" },
    { "<leader>wo", function() require("nanabrowser").open_external_prompt() end, desc = "Open URL (external)" },
    { "gx", function() require("nanabrowser").open_external_cursor() end, desc = "Open URL in browser", mode = { "n", "v" } },
    { "<leader>tt", function() require("nanabrowser").open_terminal() end, desc = "Terminal panel" },
    { "<leader>td", function() require("nanabrowser").focus_todo() end, desc = "Focus TODO" },
  },
}
```

## Keys

**Global** (from the spec above)

| Key | Does |
| --- | --- |
| `<leader>p` | Show / hide all panels |
| `<leader>pz` | Zoom one panel, or show all again |
| `<leader>wb` | Browse a URL in the browser panel |
| `<leader>wo` | Open a URL in your external browser |
| `gx` | Open the URL under the cursor (or the selection) externally |
| `<leader>tt` | Start the shell, or jump back to it |
| `<leader>td` | Jump to the TODO panel |

**Inside any panel** (normal mode)

| Key | Does |
| --- | --- |
| `<Tab>` / `<S-Tab>` | Next / previous panel (`<Right>` / `<Left>` work too) |
| `q` | Hide the panel. The program in it keeps running |
| `<leader>z` | Zoom |
| `<Esc>` | Leave terminal mode (browser and shell panels) |

To really end the shell or w3m, quit it inside the panel (`exit`, or `q` in w3m). The panel then goes back to its start screen.

**TODO panel**

| Key | Does |
| --- | --- |
| `a` | Add |
| `x` / `<CR>` | Done / not done |
| `e` | Edit |
| `d` | Delete |

## Commands

Every action is also a plain user command, so it scripts and `<Tab>`-completes:

| Command | Does |
| --- | --- |
| `:NanaPanels` | Toggle the whole panel workspace (same as `<leader>p`) |
| `:NanaZoom` | Toggle focus-one ↔ show-all zoom |
| `:NanaPanel {name}` | Open one panel by name (Tab-completes: browser, terminal, todo, …) |
| `:NanaBrowser [url]` | Open the text browser; `<Tab>` completes recent URLs |
| `:NanaBrowserPrompt` / `:NanaBrowserCursor` | Prompt for a URL / open the one under the cursor |
| `:NanaExternal [url]` | Open a URL in your real browser |
| `:NanaTerminal` / `:NanaTerminalToggle` | Open / toggle the terminal panel |
| `:NanaTodos` / `:NanaTodosToggle` | Open / toggle the TODO panel |

URLs can skip the `https://`. Local paths (`./index.html`, `~/docs/a.html`) open as files, and `localhost:3000` opens over http.

## Configuration

Defaults. Pass only what you want to change:

```lua
require("nanabrowser").setup({
  text_browser = nil,        -- nil = auto (w3m > lynx > elinks); or force one, args allowed: "w3m -no-mouse"
  external_browser = nil,    -- nil = auto ($BROWSER > system opener > brave/chromium/firefox)
  layout = "auto",           -- "auto" (side-by-side if wide enough, else tabbed) | "float" | "split"
  auto_min_width = 40,       -- min columns per panel before "auto" drops to a float
  reader_mode = false,       -- true = static -dump render (great for docs)
  float = { width = 0.85, height = 0.85, border = "rounded", hints = true }, -- hints = keys on the border
  split = { position = "botright", size = 0.35 }, -- size = fraction of screen height
  default_panels = { "browser", "terminal", "todo" },
  home = "https://duckduckgo.com/html",
  highlights = nil,          -- nil = use your colorscheme; see Theming
})
```

The system opener is `open` on macOS, `xdg-open` on Linux and `wslview` on WSL.

## Theming

The panels take their colors from your colorscheme, so `:colorscheme`, theme-switcher previews and blackout mode just carry over. Each group links to a standard one:

| Group | Links to | Used for |
| --- | --- | --- |
| `NanaPanelNormal` | `NormalFloat` | Panel background |
| `NanaPanelNC` | `NanaPanelNormal` | Unfocused split panel |
| `NanaPanelBorder` | `FloatBorder` | Float border |
| `NanaPanelTitle` | `FloatTitle` | Active tab, focused panel title |
| `NanaPanelTab` | `NanaPanelBorder` | Other tabs and titles |
| `NanaPanelKey` | `Special` | Keys on the start screens |
| `NanaPanelHint` | `Comment` | Key hints |
| `NanaTodoDone` | `Comment` | Finished TODOs |

Change one in a `ColorScheme` autocmd so it survives theme changes:

```lua
vim.api.nvim_create_autocmd("ColorScheme", {
  callback = function()
    vim.api.nvim_set_hl(0, "NanaPanelBorder", { fg = "#89b4fa" })
  end,
})
```

Want the old fixed colors back? `highlights = { border = "#89b4fa", bg = "#1e1e2e", bg_nc = "#181825" }`.

## Custom panels

The workspace is not limited to the three built-ins. Register your own panel and
it joins the auto/split/float layouts, zoom cycling, and `:NanaPanel` completion
automatically:

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

## License

MIT
