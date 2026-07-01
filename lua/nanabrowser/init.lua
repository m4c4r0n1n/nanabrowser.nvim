-- nanabrowser.nvim - Browser / Terminal / TODO panels for Neovim
-- Layouts: "float" (tabbed, zero column theft) or "split" (classic side-by-side)

local M = {}

-- ── Version guard (fragility fix) ───────────────────────────────────────────
if vim.fn.has("nvim-0.10") == 0 then
  vim.schedule(function()
    vim.notify("nanabrowser.nvim requires Neovim 0.10+", vim.log.levels.ERROR)
  end)
end

local UA = "Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/537.36 "
  .. "(KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36"

M.config = {
  -- nil = auto-detect. Set explicitly to force a choice.
  text_browser = nil, -- auto: w3m > lynx > elinks
  external_browser = nil, -- auto: $BROWSER > xdg-open > brave/chromium/firefox
  layout = "float", -- "float" | "split"
  reader_mode = false, -- true = static -dump render (great for docs), false = interactive
  float = { width = 0.85, height = 0.85, border = "rounded" },
  split = { position = "botright", size = 0.35 }, -- size = fraction of screen height
  default_panels = { "browser", "terminal", "todo" }, -- what <leader>p opens
  home = "https://duckduckgo.com/html",
  highlights = { border = "#89b4fa", bg = "#1e1e2e", bg_nc = "#181825" },
}

M.state = {
  open = { browser = false, terminal = false, todo = false },
  buf = { browser = nil, terminal = nil, todo = nil },
  win = { browser = nil, terminal = nil, todo = nil },
  job = { browser = nil, terminal = nil },
  container = nil, -- float win, or the first split win
  active = nil, -- which panel is focused (float mode)
  last_url = nil,
  todos = {},
}

local PANELS = {
  browser = { title = "🌐 Browser" },
  terminal = { title = "💻 Terminal" },
  todo = { title = "📝 TODO" },
}
local ORDER = { "browser", "terminal", "todo" }

-- ── Forward declarations ────────────────────────────────────────────────────
local apply_border, build_title, close_container, ensure_split, ensure_float,
  show_layout, panel_keymaps, term_keymaps, todo_keymaps, render_todo,
  render_browser_placeholder, render_terminal_placeholder

-- ── Small helpers ───────────────────────────────────────────────────────────
local function bufset(buf, name, value)
  vim.api.nvim_set_option_value(name, value, { buf = buf })
end

local function first_executable(list)
  for _, exe in ipairs(list) do
    if vim.fn.executable((exe:match("^(%S+)"))) == 1 then
      return exe
    end
  end
end

local function detect_text_browser()
  return M.config.text_browser or first_executable({ "w3m", "lynx", "elinks" })
end

local function detect_external_browser()
  if M.config.external_browser then
    return M.config.external_browser
  end
  local env = vim.env.BROWSER
  if env and env ~= "" and vim.fn.executable((env:match("^(%S+)"))) == 1 then
    return env
  end
  return first_executable({
    "xdg-open", "brave", "chromium", "google-chrome-stable", "google-chrome", "firefox",
  })
end

local function normalize_url(url)
  if not url or url == "" then
    return M.config.home
  end
  if not url:match("^%w+://") then
    url = "https://" .. url
  end
  return url
end

local function url_under_cursor()
  local w = vim.fn.expand("<cWORD>")
  return w:match('["\']([^"\']+)["\']') or w:match("%(([^)]+)%)") or w
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

local function setup_highlights()
  local c = M.config.highlights
  vim.api.nvim_set_hl(0, "NanaPanelNormal", { bg = c.bg })
  vim.api.nvim_set_hl(0, "NanaPanelNC", { bg = c.bg_nc })
  vim.api.nvim_set_hl(0, "NanaPanelBorder", { fg = c.border, bg = c.bg, bold = true })
end

local function ensure_buf(name)
  local b = M.state.buf[name]
  if b and vim.api.nvim_buf_is_valid(b) then
    return b
  end
  b = vim.api.nvim_create_buf(false, true)
  bufset(b, "bufhidden", "hide")
  bufset(b, "buflisted", false)
  M.state.buf[name] = b
  panel_keymaps(b, name)
  return b
end

-- ── Layout ──────────────────────────────────────────────────────────────────
apply_border = function(win, title)
  if not (win and vim.api.nvim_win_is_valid(win)) then
    return
  end
  vim.wo[win].number = false
  vim.wo[win].relativenumber = false
  vim.wo[win].signcolumn = "no"
  vim.wo[win].cursorline = false
  vim.wo[win].winhl = "Normal:NanaPanelNormal,NormalNC:NanaPanelNC"
  if M.config.layout == "split" and title then
    vim.wo[win].winbar = "%#NanaPanelBorder# " .. title .. " "
  end
end

build_title = function(names)
  local parts = {}
  for _, n in ipairs(names) do
    local t = PANELS[n].title
    if n == M.state.active then
      t = "[" .. t .. "]"
    end
    parts[#parts + 1] = " " .. t .. " "
  end
  return table.concat(parts, "│")
end

close_container = function()
  for _, n in ipairs(ORDER) do
    local w = M.state.win[n]
    if w and w ~= M.state.container and vim.api.nvim_win_is_valid(w) then
      pcall(vim.api.nvim_win_close, w, true)
    end
    M.state.win[n] = nil
  end
  if M.state.container and vim.api.nvim_win_is_valid(M.state.container) then
    pcall(vim.api.nvim_win_close, M.state.container, true)
  end
  M.state.container = nil
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
    title = build_title(names),
    title_pos = "center",
  }
  if M.state.container and vim.api.nvim_win_is_valid(M.state.container) then
    vim.api.nvim_win_set_config(M.state.container, cfg)
    vim.api.nvim_win_set_buf(M.state.container, buf)
  else
    M.state.container = vim.api.nvim_open_win(buf, true, cfg)
  end
  M.state.win = { browser = nil, terminal = nil, todo = nil }
  M.state.win[M.state.active] = M.state.container
  vim.wo[M.state.container].winhl = "Normal:NanaPanelNormal,FloatBorder:NanaPanelBorder"
end

ensure_split = function()
  local names = ordered_open()
  if #names == 0 then
    return close_container()
  end
  local orig = vim.api.nvim_get_current_win()
  for _, n in ipairs(ORDER) do
    local w = M.state.win[n]
    if w and w ~= M.state.container and vim.api.nvim_win_is_valid(w) then
      pcall(vim.api.nvim_win_close, w, true)
    end
    M.state.win[n] = nil
  end

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
    vim.cmd("vsplit")
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

  if vim.api.nvim_win_is_valid(orig) then
    vim.api.nvim_set_current_win(orig)
  end
end

show_layout = function()
  if #ordered_open() == 0 then
    return close_container()
  end
  if M.config.layout == "float" then
    ensure_float()
  else
    ensure_split()
  end
end

-- Cycle the active panel (float mode tab switching)
function M.cycle(dir)
  if M.config.layout ~= "float" then
    return
  end
  local names = ordered_open()
  if #names < 2 then
    return
  end
  local idx = 1
  for i, n in ipairs(names) do
    if n == M.state.active then
      idx = i
      break
    end
  end
  M.state.active = names[((idx - 1 + dir) % #names) + 1]
  ensure_float()
  local win = M.state.container
  if win and vim.api.nvim_win_is_valid(win) then
    vim.api.nvim_set_current_win(win)
    local b = M.state.buf[M.state.active]
    if b and vim.bo[b].buftype == "terminal" then
      vim.cmd("startinsert")
    end
  end
end

-- ── Keymaps ─────────────────────────────────────────────────────────────────
panel_keymaps = function(buf, name)
  local o = { buffer = buf, silent = true, nowait = true }
  vim.keymap.set("n", "q", function()
    M.close(name)
  end, o)
  vim.keymap.set("n", "<Tab>", function()
    M.cycle(1)
  end, o)
  vim.keymap.set("n", "<S-Tab>", function()
    M.cycle(-1)
  end, o)
end

term_keymaps = function(buf)
  vim.keymap.set("t", "<Esc>", [[<C-\><C-n>]], { buffer = buf, silent = true })
end

-- ── Panel open/close primitives ─────────────────────────────────────────────
function M.close(name)
  M.state.open[name] = false
  if M.state.job[name] then
    vim.fn.jobstop(M.state.job[name])
    M.state.job[name] = nil
  end
  if M.state.active == name then
    M.state.active = ordered_open()[1]
  end
  show_layout()
end

-- ── Browser ─────────────────────────────────────────────────────────────────
render_browser_placeholder = function()
  local b = M.state.buf.browser
  if not (b and vim.api.nvim_buf_is_valid(b)) then
    return
  end
  bufset(b, "modifiable", true)
  vim.api.nvim_buf_set_lines(b, 0, -1, false, {
    "  🌐 Browser",
    "",
    "  <leader>wb   browse a URL here (text)",
    "  <leader>wo   open a URL in your real browser",
    "  gx           open URL under cursor externally",
    "",
    "  Waiting for a URL...",
  })
  bufset(b, "modifiable", false)
end

local function run_interactive(win, tb, url)
  local buf = vim.api.nvim_create_buf(false, true)
  bufset(buf, "bufhidden", "hide")
  bufset(buf, "buflisted", false)
  vim.api.nvim_win_set_buf(win, buf)
  vim.api.nvim_set_current_win(win)

  local prog = tb:match("^(%S+)")
  local cmd
  if prog == "w3m" then
    cmd = { "w3m", "-o", "user_agent=" .. UA, url }
  elseif prog == "lynx" then
    cmd = { "lynx", "-useragent=" .. UA, url }
  else
    cmd = { prog, url }
  end

  M.state.job.browser = vim.fn.jobstart(cmd, {
    term = true,
    on_exit = function()
      M.state.job.browser = nil
    end,
  })
  M.state.buf.browser = buf
  panel_keymaps(buf, "browser")
  term_keymaps(buf)
  apply_border(win, "🌐 " .. prog)
  vim.schedule(function()
    if vim.api.nvim_win_is_valid(win) then
      vim.cmd("startinsert")
    end
  end)
end

local function render_reader(win, tb, url)
  local prog = tb:match("^(%S+)")
  local buf = vim.api.nvim_create_buf(false, true)
  bufset(buf, "bufhidden", "hide")
  bufset(buf, "buflisted", false)
  bufset(buf, "filetype", "markdown")
  vim.api.nvim_win_set_buf(win, buf)
  M.state.buf.browser = buf
  vim.api.nvim_buf_set_lines(buf, 0, -1, false, { "Loading " .. url .. " ..." })

  local args
  if prog == "w3m" then
    args = { "w3m", "-dump", "-o", "user_agent=" .. UA, url }
  elseif prog == "lynx" then
    args = { "lynx", "-dump", "-useragent=" .. UA, url }
  else
    args = { prog, "-dump", url }
  end

  local out = {}
  vim.fn.jobstart(args, {
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
      bufset(buf, "modifiable", true)
      vim.api.nvim_buf_set_lines(buf, 0, -1, false, out)
      bufset(buf, "modifiable", false)
    end,
  })
  panel_keymaps(buf, "browser")
  apply_border(win, "🌐 Reader")
end

function M.open_browser(url)
  url = normalize_url(url)
  M.state.last_url = url
  local tb = detect_text_browser()
  if not tb then
    vim.notify(
      "nanabrowser: no text browser (w3m/lynx/elinks) found — opening externally",
      vim.log.levels.WARN
    )
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
  local ext = detect_external_browser()
  if not ext then
    vim.notify("nanabrowser: no external browser found", vim.log.levels.ERROR)
    return
  end
  local prog = ext:match("^(%S+)")
  vim.fn.jobstart({ prog, url }, { detach = true })
  vim.notify("nanabrowser → " .. prog .. ": " .. url, vim.log.levels.INFO)
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
render_terminal_placeholder = function()
  local b = M.state.buf.terminal
  if not (b and vim.api.nvim_buf_is_valid(b)) then
    return
  end
  bufset(b, "modifiable", true)
  vim.api.nvim_buf_set_lines(b, 0, -1, false, {
    "  💻 Terminal",
    "",
    "  <leader>tt   start a shell here",
  })
  bufset(b, "modifiable", false)
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

  local buf = vim.api.nvim_create_buf(false, true)
  bufset(buf, "bufhidden", "hide")
  bufset(buf, "buflisted", false)
  vim.api.nvim_win_set_buf(win, buf)
  vim.api.nvim_set_current_win(win)
  M.state.buf.terminal = buf
  M.state.job.terminal = vim.fn.jobstart(vim.o.shell, {
    term = true,
    on_exit = function()
      M.state.job.terminal = nil
    end,
  })
  panel_keymaps(buf, "terminal")
  term_keymaps(buf)
  apply_border(win, "💻 Terminal")
  vim.schedule(function()
    if vim.api.nvim_win_is_valid(win) then
      vim.cmd("startinsert")
    end
  end)
end

function M.toggle_terminal()
  if M.state.open.terminal then
    M.close("terminal")
  else
    M.open_terminal()
  end
end

-- ── TODO ────────────────────────────────────────────────────────────────────
local function todo_file()
  return vim.fn.stdpath("data") .. "/nanabrowser_todos.json"
end

function M.load_todos()
  local f = todo_file()
  if vim.fn.filereadable(f) == 1 then
    local ok, data = pcall(vim.fn.json_decode, table.concat(vim.fn.readfile(f), "\n"))
    if ok and type(data) == "table" then
      M.state.todos = data
    end
  end
end

function M.save_todos()
  vim.fn.writefile({ vim.fn.json_encode(M.state.todos) }, todo_file())
end

render_todo = function()
  local b = M.state.buf.todo
  if not (b and vim.api.nvim_buf_is_valid(b)) then
    return
  end
  local lines = { "  📝 TODO   [a]dd [x]toggle [d]el", "" }
  if #M.state.todos == 0 then
    lines[#lines + 1] = "  No TODOs — press 'a'"
  else
    for _, t in ipairs(M.state.todos) do
      lines[#lines + 1] = string.format("  %s %s", t.done and "[✓]" or "[ ]", t.text)
    end
  end
  bufset(b, "modifiable", true)
  vim.api.nvim_buf_set_lines(b, 0, -1, false, lines)
  bufset(b, "modifiable", false)
end

todo_keymaps = function(buf)
  local o = { buffer = buf, silent = true, nowait = true }
  local function idx_at_cursor()
    return vim.fn.line(".") - 2 -- 2 header lines
  end
  vim.keymap.set("n", "a", function()
    vim.ui.input({ prompt = "New TODO: " }, function(text)
      if text and text ~= "" then
        table.insert(M.state.todos, { text = text, done = false })
        M.save_todos()
        render_todo()
      end
    end)
  end, o)
  vim.keymap.set("n", "d", function()
    local i = idx_at_cursor()
    if i > 0 and i <= #M.state.todos then
      table.remove(M.state.todos, i)
      M.save_todos()
      render_todo()
    end
  end, o)
  vim.keymap.set("n", "x", function()
    local i = idx_at_cursor()
    if i > 0 and i <= #M.state.todos then
      M.state.todos[i].done = not M.state.todos[i].done
      M.save_todos()
      render_todo()
    end
  end, o)
end

function M.focus_todo()
  M.state.open.todo = true
  M.state.active = "todo"
  ensure_buf("todo")
  render_todo()
  todo_keymaps(M.state.buf.todo)
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
    M.state.open[n] = true
    ensure_buf(n)
    if n == "browser" then
      render_browser_placeholder()
    elseif n == "terminal" then
      render_terminal_placeholder()
    elseif n == "todo" then
      render_todo()
      todo_keymaps(M.state.buf.todo)
    end
  end
  M.state.active = M.config.default_panels[1]
  show_layout()
end

function M.close_all_panels()
  for _, n in ipairs(ORDER) do
    M.state.open[n] = false
    if M.state.job[n] then
      vim.fn.jobstop(M.state.job[n])
      M.state.job[n] = nil
    end
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
function M.setup(opts)
  M.config = vim.tbl_deep_extend("force", M.config, opts or {})
  M.load_todos()
  setup_highlights()
  vim.api.nvim_create_autocmd("ColorScheme", { callback = setup_highlights })
end

return M
