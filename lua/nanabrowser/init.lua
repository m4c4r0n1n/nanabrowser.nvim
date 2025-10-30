local M = {}

M.config = {
  converter = "pandoc", -- pandoc, w3m, lynx, html2text
  output_format = "markdown", -- markdown, plain
  user_agent = "Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/537.36",
  timeout = 30, -- curl timeout in seconds
  default_width = 80, -- text width for conversion
}

function M.setup(opts)
  M.config = vim.tbl_deep_extend("force", M.config, opts or {})
end

-- Check if required tools are available
local function check_dependencies()
  local curl_available = vim.fn.executable("curl") == 1
  local pandoc_available = vim.fn.executable("pandoc") == 1

  if not curl_available then
    vim.notify("nanabrowser: curl is not installed", vim.log.levels.ERROR)
    return false
  end

  if M.config.converter == "pandoc" and not pandoc_available then
    vim.notify("nanabrowser: pandoc is not installed", vim.log.levels.ERROR)
    return false
  end

  return true
end

-- Fetch webpage HTML
local function fetch_url(url)
  if not check_dependencies() then
    return nil
  end

  local cmd = string.format(
    'curl -sL -A "%s" --max-time %d "%s"',
    M.config.user_agent,
    M.config.timeout,
    url
  )

  local handle = io.popen(cmd)
  if not handle then
    vim.notify("nanabrowser: Failed to fetch URL", vim.log.levels.ERROR)
    return nil
  end

  local html = handle:read("*a")
  handle:close()

  return html
end

-- Convert HTML to ASCII/Markdown using pandoc
local function convert_html(html)
  local tmp_file = os.tmpname()
  local output_file = os.tmpname()

  -- Write HTML to temp file
  local f = io.open(tmp_file, "w")
  if not f then
    vim.notify("nanabrowser: Failed to create temp file", vim.log.levels.ERROR)
    return nil
  end
  f:write(html)
  f:close()

  -- Convert with pandoc
  local output_format = M.config.output_format == "plain" and "plain" or "markdown"
  local cmd = string.format(
    'pandoc -f html -t %s --wrap=auto --columns=%d "%s" -o "%s"',
    output_format,
    M.config.default_width,
    tmp_file,
    output_file
  )

  os.execute(cmd)

  -- Read converted content
  local out = io.open(output_file, "r")
  if not out then
    vim.notify("nanabrowser: Failed to read converted content", vim.log.levels.ERROR)
    os.remove(tmp_file)
    return nil
  end

  local content = out:read("*a")
  out:close()

  -- Cleanup
  os.remove(tmp_file)
  os.remove(output_file)

  return content
end

-- Open URL in new buffer
function M.open_url(url)
  if not url or url == "" then
    vim.notify("nanabrowser: No URL provided", vim.log.levels.WARN)
    return
  end

  -- Validate URL
  if not url:match("^https?://") then
    url = "https://" .. url
  end

  vim.notify("nanabrowser: Fetching " .. url .. "...", vim.log.levels.INFO)

  -- Fetch and convert asynchronously to not block UI
  vim.schedule(function()
    local html = fetch_url(url)
    if not html then
      return
    end

    local content = convert_html(html)
    if not content then
      return
    end

    -- Create new buffer
    vim.cmd("enew")
    local buf = vim.api.nvim_get_current_buf()

    -- Split content into lines
    local lines = {}
    for line in content:gmatch("[^\r\n]+") do
      table.insert(lines, line)
    end

    -- Set buffer content
    vim.api.nvim_buf_set_lines(buf, 0, -1, false, lines)

    -- Set buffer options
    vim.api.nvim_buf_set_option(buf, "filetype", "markdown")
    vim.api.nvim_buf_set_option(buf, "buftype", "nofile")
    vim.api.nvim_buf_set_name(buf, "nanabrowser://" .. url)

    -- Add URL as first line (commented)
    vim.api.nvim_buf_set_lines(buf, 0, 0, false, { "<!-- " .. url .. " -->", "" })

    vim.notify("nanabrowser: Loaded " .. url, vim.log.levels.INFO)
  end)
end

-- Get URL under cursor or from visual selection
function M.open_url_under_cursor()
  local url = vim.fn.expand("<cWORD>")

  -- Extract URL if surrounded by quotes or parentheses
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
