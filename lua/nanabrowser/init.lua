local M = {}

M.config = {
  user_agent = "Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/537.36",
  timeout = 30,
  width = 100, -- Terminal width for rendering
  show_images = true, -- Convert images to ASCII
  image_width = 80, -- Width for ASCII images
}

-- Browser state
M.state = {
  history = {},
  current_index = 0,
  links = {}, -- Links on current page
  current_url = nil,
  current_buf = nil,
}

function M.setup(opts)
  M.config = vim.tbl_deep_extend("force", M.config, opts or {})
end

-- Check dependencies
local function check_dependencies()
  if vim.fn.executable("w3m") ~= 1 then
    vim.notify("nanabrowser: w3m is not installed", vim.log.levels.ERROR)
    return false
  end
  if M.config.show_images and vim.fn.executable("chafa") ~= 1 then
    vim.notify("nanabrowser: chafa is not installed (needed for images)", vim.log.levels.WARN)
  end
  return true
end

-- Render webpage using w3m
local function render_page(url)
  if not check_dependencies() then
    return nil, nil
  end

  -- Use w3m to dump the page as text with proper formatting
  local cmd = string.format(
    'w3m -dump -T text/html -cols %d "%s"',
    M.config.width,
    url
  )

  local handle = io.popen(cmd)
  if not handle then
    vim.notify("nanabrowser: Failed to render page", vim.log.levels.ERROR)
    return nil, nil
  end

  local content = handle:read("*a")
  handle:close()

  -- Extract links using w3m
  local links_cmd = string.format('w3m -dump_source "%s" | grep -oP "href=[\\"\\x27]\\K[^\\"\\x27]+"', url)
  local links_handle = io.popen(links_cmd)
  local links = {}

  if links_handle then
    for link in links_handle:lines() do
      -- Only include http(s) links
      if link:match("^https?://") then
        table.insert(links, link)
      elseif link:match("^/") then
        -- Relative link - make absolute
        local base = url:match("(https?://[^/]+)")
        if base then
          table.insert(links, base .. link)
        end
      end
    end
    links_handle:close()
  end

  return content, links
end

-- Display page in buffer
local function display_page(url, content, links)
  -- Create new buffer
  vim.cmd("enew")
  local buf = vim.api.nvim_get_current_buf()

  M.state.current_buf = buf
  M.state.current_url = url
  M.state.links = links

  -- Split content into lines
  local lines = {}
  for line in content:gmatch("[^\r\n]+") do
    table.insert(lines, line)
  end

  -- Add header with URL and navigation info
  local header = {
    "═══════════════════════════════════════════════════════════════════",
    "  URL: " .. url,
    "  Links: " .. #links .. " | [Enter] on link number to open",
    "  [<C-o>] Back | [<C-i>] Forward | [<leader>wb] New URL",
    "═══════════════════════════════════════════════════════════════════",
    "",
  }

  -- Add links list at the bottom
  local footer = { "", "──── Links ────" }
  for i, link in ipairs(links) do
    if i <= 50 then -- Limit to 50 links for readability
      table.insert(footer, string.format("[%d] %s", i, link))
    end
  end

  -- Combine header + content + footer
  local all_lines = {}
  vim.list_extend(all_lines, header)
  vim.list_extend(all_lines, lines)
  vim.list_extend(all_lines, footer)

  -- Set buffer content
  vim.api.nvim_buf_set_lines(buf, 0, -1, false, all_lines)

  -- Set buffer options
  vim.api.nvim_buf_set_option(buf, "filetype", "nanabrowser")
  vim.api.nvim_buf_set_option(buf, "buftype", "nofile")
  vim.api.nvim_buf_set_option(buf, "modifiable", false)
  vim.api.nvim_buf_set_name(buf, "nanabrowser://" .. url)

  -- Set buffer keymaps
  local opts = { buffer = buf, silent = true }

  -- Navigate links
  vim.keymap.set("n", "<CR>", function()
    M.follow_link_number()
  end, opts)

  -- Back/Forward
  vim.keymap.set("n", "<C-o>", function()
    M.go_back()
  end, opts)

  vim.keymap.set("n", "<C-i>", function()
    M.go_forward()
  end, opts)

  -- Refresh
  vim.keymap.set("n", "r", function()
    M.refresh()
  end, opts)

  -- Go to top
  vim.cmd("normal! gg")
end

-- Open URL
function M.open_url(url)
  if not url or url == "" then
    vim.notify("nanabrowser: No URL provided", vim.log.levels.WARN)
    return
  end

  -- Validate URL
  if not url:match("^https?://") then
    url = "https://" .. url
  end

  vim.notify("nanabrowser: Loading " .. url .. "...", vim.log.levels.INFO)

  -- Render in background
  vim.schedule(function()
    local content, links = render_page(url)
    if not content then
      return
    end

    -- Add to history
    if M.state.current_index > 0 then
      -- Remove forward history if we're navigating from middle
      for i = M.state.current_index + 1, #M.state.history do
        M.state.history[i] = nil
      end
    end

    table.insert(M.state.history, url)
    M.state.current_index = #M.state.history

    display_page(url, content, links)
    vim.notify("nanabrowser: Loaded " .. url, vim.log.levels.INFO)
  end)
end

-- Follow link by number
function M.follow_link_number()
  local line = vim.fn.getline(".")
  local link_num = line:match("^%[(%d+)%]")

  if link_num then
    link_num = tonumber(link_num)
    if link_num and M.state.links[link_num] then
      M.open_url(M.state.links[link_num])
    else
      vim.notify("nanabrowser: Invalid link number", vim.log.levels.WARN)
    end
  else
    vim.notify("nanabrowser: No link number on this line", vim.log.levels.WARN)
  end
end

-- Navigate back
function M.go_back()
  if M.state.current_index > 1 then
    M.state.current_index = M.state.current_index - 1
    local url = M.state.history[M.state.current_index]

    vim.schedule(function()
      local content, links = render_page(url)
      if content then
        display_page(url, content, links)
      end
    end)
  else
    vim.notify("nanabrowser: Already at oldest page", vim.log.levels.WARN)
  end
end

-- Navigate forward
function M.go_forward()
  if M.state.current_index < #M.state.history then
    M.state.current_index = M.state.current_index + 1
    local url = M.state.history[M.state.current_index]

    vim.schedule(function()
      local content, links = render_page(url)
      if content then
        display_page(url, content, links)
      end
    end)
  else
    vim.notify("nanabrowser: Already at newest page", vim.log.levels.WARN)
  end
end

-- Refresh current page
function M.refresh()
  if M.state.current_url then
    vim.schedule(function()
      local content, links = render_page(M.state.current_url)
      if content then
        display_page(M.state.current_url, content, links)
      end
    end)
  end
end

-- Get URL under cursor
function M.open_url_under_cursor()
  local url = vim.fn.expand("<cWORD>")
  url = url:match('["\']([^"\']+)["\']') or url:match('%(([^)]+)%)') or url

  if url and url ~= "" then
    M.open_url(url)
  else
    vim.notify("nanabrowser: No URL under cursor", vim.log.levels.WARN)
  end
end

-- Prompt for URL
function M.open_url_prompt()
  vim.ui.input({ prompt = "Enter URL: ", default = "https://" }, function(url)
    if url and url ~= "" then
      M.open_url(url)
    end
  end)
end

return M
