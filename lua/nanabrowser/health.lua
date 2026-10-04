-- :checkhealth nanabrowser
-- Shows which external tools the panels use and which are missing.

local M = {}

local health = vim.health

function M.check()
  local nana = require("nanabrowser")

  health.start("nanabrowser: core")
  local v = vim.version()
  local ver = string.format("%d.%d.%d", v.major, v.minor, v.patch)
  if vim.fn.has("nvim-0.11") == 1 then
    health.ok("Neovim " .. ver)
  else
    health.error("Neovim 0.11+ required, found " .. ver .. ". The browser and terminal panels do not start.")
  end

  health.start("nanabrowser: browsers")
  local tb = nana.detect_text_browser()
  if tb then
    health.ok(tb .. ": in-editor text browser")
  else
    health.warn("no text browser (w3m, lynx, elinks). <leader>wb opens your external browser instead.", {
      "Arch: sudo pacman -S w3m",
      "Debian/Ubuntu: sudo apt install w3m",
      "Fedora: sudo dnf install w3m",
      "macOS: brew install w3m",
    })
  end

  local ext = nana.detect_external_browser()
  if ext then
    health.ok(ext .. ": external browser (config or $BROWSER)")
  else
    local opener
    for _, exe in ipairs({ "open", "xdg-open", "wslview" }) do
      if vim.fn.executable(exe) == 1 then
        opener = exe
        break
      end
    end
    if opener then
      health.ok(opener .. ": external browser (through vim.ui.open)")
    else
      health.warn("no system opener (open, xdg-open, wslview). gx tries brave, chromium and firefox directly.")
    end
  end

  health.start("nanabrowser: layout")
  local cfg = nana.config
  local need = #cfg.default_panels * (cfg.auto_min_width or 40)
  health.info(string.format("layout = %q, editor width = %d columns", cfg.layout, vim.o.columns))
  if cfg.layout == "auto" then
    health.info(string.format("auto: side-by-side at %d+ columns, tabbed float below that", need))
  end
  health.info("highlights: " .. (cfg.highlights and "fixed colors" or "colorscheme colors"))
  health.info("TODO file: " .. vim.fn.stdpath("data") .. "/nanabrowser_todos.json")
end

return M
