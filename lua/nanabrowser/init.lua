-- nanabrowser.nvim - Browser / Terminal / TODO panels for Neovim
-- Layouts: "float" (tabbed, zero column theft) or "split" (classic side-by-side)

local M = {}

-- ── Version guard ───────────────────────────────────────────────────────────
-- The browser and terminal panels use jobstart({ term = true }). It starts in 0.11.
if vim.fn.has("nvim-0.11") == 0 then
  vim.schedule(function()
    vim.notify("nanabrowser.nvim requires Neovim 0.11+", vim.log.levels.ERROR)
  end)
end

local UA = "Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/537.36 "
  .. "(KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36"

M.config = {
  -- nil = auto-detect. Set explicitly to force a choice. Arguments are allowed ("w3m -no-mouse").
  text_browser = nil, -- auto: w3m > lynx > elinks
  external_browser = nil, -- auto: $BROWSER > vim.ui.open (open / xdg-open / wslview) > brave/chromium/firefox
  layout = "auto", -- "auto" | "float" | "split"
  -- "auto": show every open panel side-by-side (split) when the editor is at
  -- least (#panels * auto_min_width) columns wide, otherwise a tabbed float.
  auto_min_width = 40, -- min columns per panel before "auto" falls back to float
  reader_mode = false, -- true = static -dump render (great for docs), false = interactive
  float = { width = 0.85, height = 0.85, border = "rounded", hints = true }, -- hints = key line on the border
  split = { position = "botright", size = 0.35 }, -- size = fraction of screen height
  default_panels = { "browser", "terminal", "todo" }, -- what <leader>p opens
  home = "https://duckduckgo.com/html",
  -- nil = use the colors of your colorscheme (NormalFloat, FloatBorder, FloatTitle).
  -- Theme changes and blackout/transparent modes then apply to the panels too.
  -- Set a table to use fixed colors: { border = "#89b4fa", bg = "#1e1e2e", bg_nc = "#181825" }
  highlights = nil,
}

M.state = {
  open = { browser = false, terminal = false, todo = false },
  buf = { browser = nil, terminal = nil, todo = nil },
  win = { browser = nil, terminal = nil, todo = nil },
  job = { browser = nil, terminal = nil },
  container = nil, -- float win, or the first split win
  active = nil, -- which panel is focused (float mode)
  last_url = nil,
  history = {}, -- visited URLs this session (newest last), feeds :NanaBrowser completion
  todos = {},
}

local PANELS = {
  browser = { title = "🌐 Browser" },
  terminal = { title = "💻 Terminal" },
  todo = { title = "📝 TODO" },
}
local ORDER = { "browser", "terminal", "todo" }

local ns = vim.api.nvim_create_namespace("nanabrowser")

-- ── Forward declarations ────────────────────────────────────────────────────
local apply_border, build_title, close_container, ensure_split, ensure_float,
  show_layout, panel_keymaps, term_keymaps, todo_keymaps, render_todo, reset_panel

-- ── Small helpers ───────────────────────────────────────────────────────────
local function bufset(buf, name, value)
  vim.api.nvim_set_option_value(name, value, { buf = buf })
end

-- "w3m -no-mouse" -> { "w3m", "-no-mouse" }
local function argv(cmd)
  return vim.split(cmd, "%s+", { trimempty = true })
end

local function first_executable(list)
  for _, cmd in ipairs(list) do
    if vim.fn.executable(argv(cmd)[1]) == 1 then
      return cmd
    end
  end
end

function M.detect_text_browser()
  return M.config.text_browser or first_executable({ "w3m", "lynx", "elinks" })
end

-- Return a fixed command (config or $BROWSER). nil means vim.ui.open selects the opener.
function M.detect_external_browser()
  if M.config.external_browser then
    return M.config.external_browser
  end
  local env = vim.env.BROWSER
  if env and env ~= "" and vim.fn.executable(argv(env)[1]) == 1 then
    return env
  end
end

local function normalize_url(url)
  url = vim.trim(url or "")
  if url == "" then
    return M.config.home
  end
  if url:match("^%a[%w+.-]*://") then
    return url
  end
  if url:match("^[~/]") or url:match("^%.%.?/") then
    return "file://" .. vim.fn.fnamemodify(vim.fn.expand(url), ":p")
  end
  if url:match("^localhost") or url:match("^127%.0%.0%.1") then
    return "http://" .. url
  end
  return "https://" .. url
end

-- Get the URL under the cursor. In visual mode, use the selected text.
local function url_under_cursor()
  local mode = vim.fn.mode()
  local text
  if mode == "v" or mode == "V" or mode == "\22" then
    text = table.concat(vim.fn.getregion(vim.fn.getpos("v"), vim.fn.getpos("."), { type = mode }), "")
    vim.api.nvim_feedkeys(vim.keycode("<Esc>"), "nx", false)
  else
    text = vim.fn.expand("<cWORD>")
  end
  text = vim.trim(text)
  local url = text:match("%a[%w+.-]*://[^%s\"'<>%(%)%[%]]+")
  if url then
    return (url:gsub("[.,;:!?]+$", ""))
  end
  return text:match('["\']([^"\']+)["\']') or text:match("%(([^)]+)%)") or text
end

local function ordered_open()
  local out = {}
  for _, n in ipairs(ORDER) do
    if M.state.open[n] then
      out[#out + 1] = n
    end
  end
  return out
end

-- Return the panel that a window shows, or nil.
local function panel_of(win)
  for n, w in pairs(M.state.win) do
    if w == win then
      return n
    end
  end
end

-- Each group links to a theme group. Thus the panels follow :colorscheme,
-- theme-switcher previews and blackout mode without more work.
local LINKS = {
  NanaPanelNormal = "NormalFloat",
  NanaPanelNC = "NanaPanelNormal",
  NanaPanelBorder = "FloatBorder",
  NanaPanelTitle = "FloatTitle", -- active tab, focused winbar, card titles
  NanaPanelTab = "NanaPanelBorder", -- inactive tabs, unfocused winbar
  NanaPanelKey = "Special", -- key names on the start cards
  NanaPanelHint = "Comment", -- key hints on the float border and the TODO header
  NanaTodoDone = "Comment",
}

local function setup_highlights()
  for group, target in pairs(LINKS) do
    vim.api.nvim_set_hl(0, group, { link = target, default = true })
  end
  local c = M.config.highlights
  if c then
    vim.api.nvim_set_hl(0, "NanaPanelNormal", { bg = c.bg })
    vim.api.nvim_set_hl(0, "NanaPanelNC", { bg = c.bg_nc or c.bg })
    vim.api.nvim_set_hl(0, "NanaPanelBorder", { fg = c.border, bg = c.bg, bold = true })
  end
end

local function new_buf()
  local b = vim.api.nvim_create_buf(false, true)
  bufset(b, "bufhidden", "hide")
  return b
end

-- Delete a panel buffer after a new buffer replaces it. The old buffer is not on screen.
local function wipe(old, new)
  if old and old ~= new and vim.api.nvim_buf_is_valid(old) then
    pcall(vim.api.nvim_buf_delete, old, { force = true })
  end
end

-- Get the card buffer of a panel. Make it if necessary.
-- A card is the static page that PANELS[name].render draws.
local function ensure_buf(name)
  local b = M.state.buf[name]
  if b and vim.api.nvim_buf_is_valid(b) then
    return b
  end
  b = new_buf()
  vim.b[b].nana_card = true
  M.state.buf[name] = b
  panel_keymaps(b, name)
  return b
end

-- Draw the card of a panel. Do not touch program buffers (shell, w3m, reader
-- dump). Thus a new open of the workspace does not erase them.
local function render_panel(name)
  local b = ensure_buf(name)
  if vim.b[b].nana_card and PANELS[name].render then
    PANELS[name].render(b, name)
  end
  return b
end

-- Write read-only lines. marks = { { row, col_start, col_end, hl_group }, ... } (0-based).
local function paint(buf, lines, marks)
  bufset(buf, "modifiable", true)
  vim.api.nvim_buf_set_lines(buf, 0, -1, false, lines)
  bufset(buf, "modifiable", false)
  vim.api.nvim_buf_clear_namespace(buf, ns, 0, -1)
  for _, m in ipairs(marks or {}) do
    vim.api.nvim_buf_set_extmark(buf, ns, m[1], m[2], { end_col = m[3], hl_group = m[4] })
  end
end

-- Start card: a title and rows of { key, description }. A false row is an empty line.
local function render_card(buf, title, rows)
  local lines = { "  " .. title, "" }
  local marks = { { 0, 2, #lines[1], "NanaPanelTitle" } }
  local nav = { false, { "<Tab>", "next panel" }, { "q", "hide (the program continues to run)" } }
  for _, r in ipairs(vim.list_extend(vim.deepcopy(rows), nav)) do
    if r then
      lines[#lines + 1] = string.format("  %-12s %s", r[1], r[2])
      marks[#marks + 1] = { #lines - 1, 2, 2 + #r[1], "NanaPanelKey" }
    else
      lines[#lines + 1] = ""
    end
  end
  paint(buf, lines, marks)
end

-- ── Layout ──────────────────────────────────────────────────────────────────
-- This flag is true while we close our own windows. The WinClosed handler then ignores the event.
local closing = false

local function close_win(w)
  if w and vim.api.nvim_win_is_valid(w) then
    closing = true
    pcall(vim.api.nvim_win_close, w, true)
    closing = false
  end
end

apply_border = function(win, title)
  if not (win and vim.api.nvim_win_is_valid(win)) then
    return
  end
  local wo = vim.wo[win]
  wo.number = false
  wo.relativenumber = false
  wo.signcolumn = "no"
  wo.statuscolumn = "" -- remove a global statuscolumn (snacks.nvim and similar)
  wo.foldcolumn = "0"
  wo.colorcolumn = ""
  wo.cursorline = false
  wo.spell = false
  wo.list = false
  wo.winhl = "Normal:NanaPanelNormal,NormalNC:NanaPanelNC,WinBar:NanaPanelTitle,WinBarNC:NanaPanelTab"
  if M.state.effective_layout == "split" then
    wo.winfixheight = true -- keep the panel height when other splits open or close
    if title then
      wo.winbar = " " .. title:gsub("%%", "%%%%") .. " "
    end
  end
end

build_title = function(names)
  local chunks = {}
  for i, n in ipairs(names) do
    if i > 1 then
      chunks[#chunks + 1] = { "│", "NanaPanelBorder" }
    end
    local t = PANELS[n].title
    if n == M.state.active then
      chunks[#chunks + 1] = { " [" .. t .. "] ", "NanaPanelTitle" }
    else
      chunks[#chunks + 1] = { " " .. t .. " ", "NanaPanelTab" }
    end
  end
  return chunks
end

close_container = function()
  for _, w in pairs(M.state.win) do
    if w ~= M.state.container then
      close_win(w)
    end
  end
  close_win(M.state.container)
  M.state.win = {}
  M.state.container = nil
end

-- Resolve the effective layout. "auto" uses a side-by-side split when the
-- editor is wide enough to give every open panel auto_min_width columns,
-- otherwise a tabbed float.
local function resolve_layout()
  local mode = M.config.layout
  if mode ~= "auto" then
    return mode
  end
  local n = math.max(1, #ordered_open())
  return (vim.o.columns >= n * (M.config.auto_min_width or 40)) and "split" or "float"
end

-- Key hints for the bottom border of the float.
local function float_footer()
  if M.config.float.hints == false then
    return nil
  end
  local keys = {}
  local b = M.state.buf[M.state.active]
  if b and vim.api.nvim_buf_is_valid(b) and vim.bo[b].buftype == "terminal" then
    keys[#keys + 1] = "<Esc> normal mode"
  end
  if #ordered_open() > 1 then
    keys[#keys + 1] = "<Tab> switch"
  end
  if M.state.zoom then
    keys[#keys + 1] = "<leader>z show all"
  elseif resolve_layout() == "split" then
    keys[#keys + 1] = "<leader>z zoom"
  end
  keys[#keys + 1] = "q hide"
  return { { " " .. table.concat(keys, " · ") .. " ", "NanaPanelHint" } }
end

ensure_float = function()
  local names = ordered_open()
  if #names == 0 then
    return close_container()
  end
  if not M.state.active or not M.state.open[M.state.active] then
    M.state.active = names[1]
  end
  local buf = ensure_buf(M.state.active)
  local W, H = vim.o.columns, vim.o.lines
  local w = math.max(20, math.floor(W * M.config.float.width))
  local h = math.max(5, math.floor(H * M.config.float.height))
  local cfg = {
    relative = "editor",
    width = w,
    height = h,
    row = math.floor((H - h) / 2),
    col = math.floor((W - w) / 2),
    style = "minimal",
    border = M.config.float.border,
  }
  -- A title or a footer is not possible without a border.
  if cfg.border ~= "none" then
    cfg.title = build_title(names)
    cfg.title_pos = "center"
    local footer = float_footer()
    if footer then
      cfg.footer = footer
      cfg.footer_pos = "center"
    end
  end
  if M.state.container and vim.api.nvim_win_is_valid(M.state.container) then
    vim.api.nvim_win_set_config(M.state.container, cfg)
    vim.api.nvim_win_set_buf(M.state.container, buf)
  else
    M.state.container = vim.api.nvim_open_win(buf, true, cfg)
  end
  M.state.win = { [M.state.active] = M.state.container }
  vim.wo[M.state.container].winhl = "Normal:NanaPanelNormal,FloatBorder:NanaPanelBorder"
end

ensure_split = function()
  local names = ordered_open()
  if #names == 0 then
    return close_container()
  end
  local orig = vim.api.nvim_get_current_win()
  local orig_panel = panel_of(orig)
  for _, w in pairs(M.state.win) do
    if w ~= M.state.container then
      close_win(w)
    end
  end
  M.state.win = {}

  local h = math.max(5, math.floor(vim.o.lines * M.config.split.size))
  if not M.state.container or not vim.api.nvim_win_is_valid(M.state.container) then
    vim.cmd(string.format("%s %dsplit", M.config.split.position, h))
    M.state.container = vim.api.nvim_get_current_win()
  else
    vim.api.nvim_set_current_win(M.state.container)
    vim.api.nvim_win_set_height(M.state.container, h)
  end

  vim.api.nvim_win_set_buf(M.state.container, ensure_buf(names[1]))
  M.state.win[names[1]] = M.state.container
  apply_border(M.state.container, PANELS[names[1]].title)

  for i = 2, #names do
    -- Use an explicit direction. The 'splitright' value of the user must not change the panel order.
    vim.cmd("rightbelow vsplit")
    local w = vim.api.nvim_get_current_win()
    vim.api.nvim_win_set_buf(w, ensure_buf(names[i]))
    M.state.win[names[i]] = w
    apply_border(w, PANELS[names[i]].title)
  end

  if #names > 1 then
    local width = math.floor(vim.o.columns / #names)
    for _, n in ipairs(names) do
      if M.state.win[n] then
        pcall(vim.api.nvim_win_set_width, M.state.win[n], width)
      end
    end
  end

  -- Go back to the start window. If we closed it, go to the new window of the same panel.
  if vim.api.nvim_win_is_valid(orig) then
    vim.api.nvim_set_current_win(orig)
  elseif orig_panel and M.state.win[orig_panel] then
    vim.api.nvim_set_current_win(M.state.win[orig_panel])
  end
end

show_layout = function()
  if #ordered_open() == 0 then
    return close_container()
  end
  -- zoom overrides the resolved layout with a single floating panel.
  local mode = M.state.zoom and "float" or resolve_layout()
  -- Switching window model (split <-> float) needs the old container torn down.
  if mode ~= M.state.effective_layout then
    close_container()
    M.state.effective_layout = mode
  end
  if mode == "float" then
    ensure_float()
  else
    ensure_split()
  end
end

-- The user closed a panel window (:q, <C-w>c). Hide that panel so the state agrees with the screen.
local function on_win_closed(win)
  if closing or not win then
    return
  end
  if win == M.state.container and M.state.effective_layout == "float" then
    -- The float holds all panels. Thus all panels are now hidden.
    for n in pairs(M.state.open) do
      M.state.open[n] = false
    end
    M.state.win, M.state.container, M.state.active = {}, nil, nil
    return
  end
  local name = panel_of(win)
  if not name then
    return
  end
  M.state.open[name] = false
  M.state.win[name] = nil
  if M.state.container == win then
    M.state.container = nil
  end
  if M.state.active == name then
    M.state.active = ordered_open()[1]
  end
end

-- Focus a panel's window (and drop into insert for terminal buffers).
local function focus_panel(name)
  local win = M.state.win[name] or M.state.container
  if win and vim.api.nvim_win_is_valid(win) then
    vim.api.nvim_set_current_win(win)
    local b = M.state.buf[name]
    if b and vim.bo[b].buftype == "terminal" then
      vim.cmd("startinsert")
    end
  end
end

-- Switch panels with <Tab>/<S-Tab>/<Left>/<Right>. In a single-panel float this
-- swaps which panel is shown; when all panels are visible it just moves focus.
function M.cycle(dir)
  local names = ordered_open()
  if #names < 2 then
    return
  end
  local cur = panel_of(vim.api.nvim_get_current_win()) or M.state.active
  local idx = 1
  for i, n in ipairs(names) do
    if n == cur then
      idx = i
      break
    end
  end
  M.state.active = names[((idx - 1 + dir) % #names) + 1]
  if M.state.effective_layout == "float" then
    ensure_float()
  end
  focus_panel(M.state.active)
end

-- Toggle between all panels visible and a single floating panel (focus one).
-- <Tab>/<Left>/<Right> then switch which panel is focused.
function M.toggle_zoom()
  if #ordered_open() == 0 then
    M.open_panels()
  end
  M.state.zoom = not M.state.zoom
  show_layout()
  focus_panel(M.state.active)
end

-- ── Keymaps ─────────────────────────────────────────────────────────────────
panel_keymaps = function(buf, name)
  local function map(lhs, fn, desc)
    vim.keymap.set("n", lhs, fn, { buffer = buf, silent = true, nowait = true, desc = desc })
  end
  map("q", function()
    M.close(name)
  end, "Hide panel")
  map("<Tab>", function()
    M.cycle(1)
  end, "Next panel")
  map("<S-Tab>", function()
    M.cycle(-1)
  end, "Previous panel")
  map("<Right>", function()
    M.cycle(1)
  end, "Next panel")
  map("<Left>", function()
    M.cycle(-1)
  end, "Previous panel")
  map("<leader>z", function()
    M.toggle_zoom()
  end, "Zoom panel")
end

term_keymaps = function(buf)
  vim.keymap.set("t", "<Esc>", [[<C-\><C-n>]], { buffer = buf, silent = true, desc = "Normal mode" })
end

-- ── Panel open/close primitives ─────────────────────────────────────────────
-- Hide a panel. Its program (shell, w3m) continues to run in the background.
-- To stop the program, quit it in the panel (`exit`, w3m `q`).
function M.close(name)
  M.state.open[name] = false
  if M.state.active == name then
    M.state.active = ordered_open()[1]
  end
  show_layout()
end

-- The program of a panel stopped. Put the start card back in its window.
reset_panel = function(name, dead)
  if M.state.buf[name] ~= dead then
    return
  end
  M.state.buf[name] = nil
  local buf = render_panel(name)
  for _, win in ipairs(vim.fn.win_findbuf(dead)) do
    vim.api.nvim_win_set_buf(win, buf)
    apply_border(win, PANELS[name].title)
  end
  wipe(dead, buf)
  if M.state.effective_layout == "float" and M.state.active == name then
    ensure_float()
  end
end

-- Run cmd as a terminal in the window of panel `name`.
local function start_term(name, win, cmd, title)
  local old = M.state.buf[name]
  local buf = new_buf()
  vim.api.nvim_win_set_buf(win, buf)
  vim.api.nvim_set_current_win(win)
  M.state.buf[name] = buf
  local id
  id = vim.fn.jobstart(cmd, {
    term = true,
    on_exit = function()
      -- Only the current run can clear the job. A replaced run must not clear the new one.
      if M.state.job[name] ~= id then
        return
      end
      M.state.job[name] = nil
      vim.schedule(function()
        if vim.v.exiting == vim.NIL then
          reset_panel(name, buf)
        end
      end)
    end,
  })
  if id <= 0 then
    vim.notify("nanabrowser: cannot start " .. vim.inspect(cmd), vim.log.levels.ERROR)
    return
  end
  M.state.job[name] = id
  panel_keymaps(buf, name)
  term_keymaps(buf)
  apply_border(win, title)
  wipe(old, buf)
  if M.state.effective_layout == "float" then
    ensure_float() -- update the key hints for a terminal
  end
  vim.schedule(function()
    if vim.api.nvim_get_current_win() == win then
      vim.cmd("startinsert")
    end
  end)
end

-- ── Browser ─────────────────────────────────────────────────────────────────
PANELS.browser.render = function(buf)
  render_card(buf, "🌐 Browser", {
    { "<leader>wb", "browse a URL here (text)" },
    { "<leader>wo", "open a URL in your real browser" },
    { "gx", "open URL under cursor externally" },
  })
end

-- Make the command for the text browser. dump = true gives static text.
local function browser_cmd(tb, url, dump)
  local cmd = argv(tb)
  local prog = vim.fs.basename(cmd[1])
  if dump then
    cmd[#cmd + 1] = "-dump"
  end
  if prog == "w3m" then
    vim.list_extend(cmd, { "-o", "user_agent=" .. UA })
  elseif prog == "lynx" then
    cmd[#cmd + 1] = "-useragent=" .. UA
  end
  cmd[#cmd + 1] = url
  return cmd, prog
end

local function run_interactive(win, tb, url)
  local cmd, prog = browser_cmd(tb, url, false)
  start_term("browser", win, cmd, "🌐 " .. prog)
end

local function render_reader(win, tb, url)
  local cmd, prog = browser_cmd(tb, url, true)
  local old = M.state.buf.browser
  local buf = new_buf()
  bufset(buf, "filetype", "markdown")
  vim.api.nvim_win_set_buf(win, buf)
  M.state.buf.browser = buf
  wipe(old, buf)
  paint(buf, { "Loading " .. url .. " ..." })

  local out = {}
  vim.fn.jobstart(cmd, {
    stdout_buffered = true,
    on_stdout = function(_, data)
      if data then
        for _, l in ipairs(data) do
          out[#out + 1] = l
        end
      end
    end,
    on_exit = function()
      if not vim.api.nvim_buf_is_valid(buf) then
        return
      end
      if #out == 0 then
        out = { "(no content returned by " .. prog .. ")" }
      end
      paint(buf, out)
    end,
  })
  panel_keymaps(buf, "browser")
  apply_border(win, "🌐 Reader")
end

-- Command-line completion for :NanaBrowser: recent URLs, then home.
function M.complete_url(arglead)
  local seen, out = {}, {}
  local function add(u)
    if u and u ~= "" and not seen[u] then
      seen[u] = true
      out[#out + 1] = u
    end
  end
  for i = #M.state.history, 1, -1 do
    add(M.state.history[i])
  end
  add(M.config.home)
  if arglead and arglead ~= "" then
    local hit = {}
    for _, u in ipairs(out) do
      if u:find(arglead, 1, true) then
        hit[#hit + 1] = u
      end
    end
    return hit
  end
  return out
end

function M.open_browser(url)
  url = normalize_url(url)
  M.state.last_url = url
  if M.state.history[#M.state.history] ~= url then
    M.state.history[#M.state.history + 1] = url
    if #M.state.history > 50 then
      table.remove(M.state.history, 1)
    end
  end
  local tb = M.detect_text_browser()
  if not tb then
    vim.notify("nanabrowser: no text browser (w3m/lynx/elinks), opening externally", vim.log.levels.WARN)
    return M.open_external(url)
  end

  M.state.open.browser = true
  M.state.active = "browser"
  ensure_buf("browser")
  show_layout()

  local win = M.state.win.browser or M.state.container
  if not (win and vim.api.nvim_win_is_valid(win)) then
    vim.notify("nanabrowser: failed to create browser window", vim.log.levels.ERROR)
    return
  end
  if M.state.job.browser then
    vim.fn.jobstop(M.state.job.browser)
    M.state.job.browser = nil
  end

  if M.config.reader_mode then
    render_reader(win, tb, url)
  else
    run_interactive(win, tb, url)
  end
end

function M.open_browser_prompt()
  vim.ui.input({ prompt = "URL (in-editor): ", default = "https://" }, function(url)
    if url and url ~= "" then
      vim.schedule(function()
        M.open_browser(url)
      end)
    end
  end)
end

function M.open_browser_cursor()
  local url = url_under_cursor()
  if url and url ~= "" then
    M.open_browser(url)
  else
    vim.notify("No URL under cursor", vim.log.levels.WARN)
  end
end

-- ── External browser (JS-heavy sites: GitHub, SO, etc.) ─────────────────────
function M.open_external(url)
  url = normalize_url(url)
  local cmd = M.detect_external_browser()
  if cmd then
    local args = argv(cmd)
    args[#args + 1] = url
    vim.fn.jobstart(args, { detach = true })
    vim.notify("nanabrowser → " .. args[1] .. ": " .. url, vim.log.levels.INFO)
    return
  end
  -- vim.ui.open knows macOS (open), Linux (xdg-open) and WSL (wslview).
  local _, err = vim.ui.open(url)
  if not err then
    vim.notify("nanabrowser → system browser: " .. url, vim.log.levels.INFO)
    return
  end
  local fallback = first_executable({ "brave", "chromium", "google-chrome-stable", "google-chrome", "firefox" })
  if not fallback then
    vim.notify("nanabrowser: no external browser found (" .. err .. ")", vim.log.levels.ERROR)
    return
  end
  vim.fn.jobstart({ fallback, url }, { detach = true })
  vim.notify("nanabrowser → " .. fallback .. ": " .. url, vim.log.levels.INFO)
end

function M.open_external_prompt()
  vim.ui.input({ prompt = "URL (external): ", default = "https://" }, function(url)
    if url and url ~= "" then
      vim.schedule(function()
        M.open_external(url)
      end)
    end
  end)
end

function M.open_external_cursor()
  local url = url_under_cursor()
  if url and url ~= "" then
    M.open_external(url)
  else
    vim.notify("No URL under cursor", vim.log.levels.WARN)
  end
end

-- ── Terminal ────────────────────────────────────────────────────────────────
PANELS.terminal.render = function(buf)
  render_card(buf, "💻 Terminal", {
    { "<leader>tt", "start a shell here" },
    { "<Esc>", "go to normal mode (in the shell)" },
  })
end

function M.open_terminal()
  M.state.open.terminal = true
  M.state.active = "terminal"
  ensure_buf("terminal")
  show_layout()

  local win = M.state.win.terminal or M.state.container
  if not (win and vim.api.nvim_win_is_valid(win)) then
    return
  end
  if M.state.job.terminal then
    vim.api.nvim_set_current_win(win)
    vim.cmd("startinsert")
    return
  end
  start_term("terminal", win, vim.o.shell, "💻 Terminal")
end

function M.toggle_terminal()
  if M.state.open.terminal then
    M.close("terminal")
  else
    M.open_terminal()
  end
end

-- ── TODO ────────────────────────────────────────────────────────────────────
local todos_loaded = false

local function todo_file()
  return vim.fn.stdpath("data") .. "/nanabrowser_todos.json"
end

function M.load_todos()
  todos_loaded = true
  local f = todo_file()
  if vim.fn.filereadable(f) == 1 then
    local ok, data = pcall(vim.fn.json_decode, table.concat(vim.fn.readfile(f), "\n"))
    if ok and type(data) == "table" then
      M.state.todos = data
    end
  end
end

-- Load the list before the first read. A save before a load must not erase the file.
local function todos()
  if not todos_loaded then
    M.load_todos()
  end
  return M.state.todos
end

function M.save_todos()
  -- On a new install the data directory can be missing. Make it first.
  vim.fn.mkdir(vim.fn.stdpath("data"), "p")
  vim.fn.writefile({ vim.fn.json_encode(todos()) }, todo_file())
end

render_todo = function(buf)
  buf = buf or M.state.buf.todo
  if not (buf and vim.api.nvim_buf_is_valid(buf)) then
    return
  end
  local head = "  📝 TODO   "
  local hint = "a add · x toggle · e edit · d delete"
  local lines = { head .. hint, "" }
  local marks = { { 0, 2, #head, "NanaPanelTitle" }, { 0, #head, #head + #hint, "NanaPanelHint" } }
  local list = todos()
  if #list == 0 then
    lines[#lines + 1] = "  No TODOs. Press a to add one."
  else
    for _, t in ipairs(list) do
      lines[#lines + 1] = string.format("  %s %s", t.done and "[✓]" or "[ ]", t.text)
      if t.done then
        marks[#marks + 1] = { #lines - 1, 2, #lines[#lines], "NanaTodoDone" }
      end
    end
  end
  paint(buf, lines, marks)
  todo_keymaps(buf)
end
PANELS.todo.render = render_todo

todo_keymaps = function(buf)
  local function map(lhs, fn, desc)
    vim.keymap.set("n", lhs, fn, { buffer = buf, silent = true, nowait = true, desc = desc })
  end
  local function changed()
    M.save_todos()
    render_todo(buf)
  end
  local function at_cursor()
    local i = vim.fn.line(".") - 2 -- 2 header lines
    return todos()[i], i
  end
  local function toggle()
    local t = at_cursor()
    if t then
      t.done = not t.done
      changed()
    end
  end
  map("a", function()
    vim.ui.input({ prompt = "New TODO: " }, function(text)
      if text and text ~= "" then
        table.insert(todos(), { text = text, done = false })
        changed()
      end
    end)
  end, "Add TODO")
  map("e", function()
    local t = at_cursor()
    if not t then
      return
    end
    vim.ui.input({ prompt = "Edit TODO: ", default = t.text }, function(text)
      if text and text ~= "" then
        t.text = text
        changed()
      end
    end)
  end, "Edit TODO")
  map("d", function()
    local t, i = at_cursor()
    if t then
      table.remove(todos(), i)
      changed()
    end
  end, "Delete TODO")
  map("x", toggle, "Toggle TODO")
  map("<CR>", toggle, "Toggle TODO")
end

function M.focus_todo()
  M.state.open.todo = true
  M.state.active = "todo"
  render_panel("todo")
  show_layout()
  local win = M.state.win.todo or M.state.container
  if win and vim.api.nvim_win_is_valid(win) then
    vim.api.nvim_set_current_win(win)
  end
end

M.open_todos = M.focus_todo

function M.toggle_todos()
  if M.state.open.todo then
    M.close("todo")
  else
    M.focus_todo()
  end
end

-- ── All panels ──────────────────────────────────────────────────────────────
function M.open_panels()
  for _, n in ipairs(M.config.default_panels) do
    if PANELS[n] then
      M.state.open[n] = true
      render_panel(n)
    end
  end
  M.state.active = M.config.default_panels[1]
  show_layout()
end

-- ── Extension API ───────────────────────────────────────────────────────────
-- Register a custom panel (file tree, DB client, notes, …) without touching the
-- core. spec = { title = string, render = function(buf, name) end }. After this,
-- add `name` to default_panels (or call open_panel) and it joins the workspace,
-- the auto/split/float layouts, zoom cycling and :Nana* commands automatically.
function M.register_panel(name, spec)
  assert(type(name) == "string" and name ~= "", "register_panel: name required")
  spec = spec or {}
  PANELS[name] = { title = spec.title or name, render = spec.render }
  if not vim.tbl_contains(ORDER, name) then
    ORDER[#ORDER + 1] = name
  end
  M.state.open[name] = M.state.open[name] or false
end

-- Names of all known panels (built-in + registered), in workspace order.
function M.panel_names()
  return vim.deepcopy(ORDER)
end

-- Open a single panel by name (built-in or registered) and focus it.
function M.open_panel(name)
  if not PANELS[name] then
    vim.notify("nanabrowser: unknown panel '" .. tostring(name) .. "'", vim.log.levels.WARN)
    return
  end
  M.state.open[name] = true
  M.state.active = name
  render_panel(name)
  show_layout()
  focus_panel(name)
end

-- Hide all panels. Their programs continue to run.
function M.close_all_panels()
  for _, n in ipairs(ORDER) do
    M.state.open[n] = false
  end
  M.state.active = nil
  close_container()
end

function M.toggle_panels()
  if ordered_open()[1] then
    M.close_all_panels()
  else
    M.open_panels()
  end
end

-- ── Setup ───────────────────────────────────────────────────────────────────
-- The autocmds are in one group. Thus a second load of this module does not add them again.
local group = vim.api.nvim_create_augroup("nanabrowser", { clear = true })
vim.api.nvim_create_autocmd("ColorScheme", { group = group, callback = setup_highlights })
-- Re-evaluate the layout when the editor is resized so "auto" can flip
-- between side-by-side and tabbed as the window crosses the width threshold.
vim.api.nvim_create_autocmd("VimResized", {
  group = group,
  callback = function()
    if #ordered_open() > 0 then
      show_layout()
    end
  end,
})
vim.api.nvim_create_autocmd("WinClosed", {
  group = group,
  callback = function(ev)
    on_win_closed(tonumber(ev.match))
  end,
})
setup_highlights()

function M.setup(opts)
  M.config = vim.tbl_deep_extend("force", M.config, opts or {})
  setup_highlights()
end

return M
