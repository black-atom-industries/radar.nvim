local M = {}

---@type integer?
local _winid = nil

---@type integer?
local _bufnr = nil

---@type integer?
local _parent_winid = nil

---Create a minimal non-file buffer
---@param lines string[]
---@return integer bufnr
local function create_help_buffer(lines)
  local bufnr = vim.api.nvim_create_buf(false, true)
  vim.api.nvim_set_option_value("buftype", "nofile", { buf = bufnr })
  vim.api.nvim_set_option_value("bufhidden", "wipe", { buf = bufnr })
  vim.api.nvim_set_option_value("swapfile", false, { buf = bufnr })
  vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, lines)
  return bufnr
end

---Center a help popup over a parent window
---@param parent_winid integer
---@param content_width integer
---@param content_height integer
---@return { row: integer, col: integer }
local function calculate_position(parent_winid, content_width, content_height)
  local parent_config = vim.api.nvim_win_get_config(parent_winid)
  local parent_width = vim.api.nvim_win_get_width(parent_winid)
  local parent_height = vim.api.nvim_win_get_height(parent_winid)

  local row = parent_config.row
      and (parent_config.row + math.max(
        math.floor((parent_height - content_height) / 2),
        0
      ))
    or math.floor((vim.o.lines - content_height) / 2)

  local col = parent_config.col
      and (parent_config.col + math.max(
        math.floor((parent_width - content_width) / 2),
        0
      ))
    or math.floor((vim.o.columns - content_width) / 2)

  return { row = row, col = col }
end

---Set up keymaps to close the help popup
---@param bufnr integer
local function setup_close_keymaps(bufnr)
  local opts = { buffer = bufnr, silent = true, noremap = true, nowait = true }
  vim.keymap.set(
    "n",
    "q",
    M.close,
    vim.tbl_extend("force", opts, { desc = "Close help" })
  )
  vim.keymap.set(
    "n",
    "<Esc>",
    M.close,
    vim.tbl_extend("force", opts, { desc = "Close help" })
  )
  vim.keymap.set(
    "n",
    "?",
    M.close,
    vim.tbl_extend("force", opts, { desc = "Close help" })
  )
end

---Show a help popup centered over a parent window
---@param opts table
---@param opts.parent_winid integer Window to center over & return focus to
---@param opts.title string Border title (e.g. "  RADAR HELP  ")
---@param opts.lines string[] Content lines (fully pre-formatted)
---@param opts.width? integer Override width (default: computed from longest line + 2)
---@param opts.height? integer Override height (default: from #lines)
function M.show(opts)
  if not opts.parent_winid or not vim.api.nvim_win_is_valid(opts.parent_winid) then
    return
  end

  -- Close existing help if open
  if _winid and vim.api.nvim_win_is_valid(_winid) then
    M.close()
  end

  _parent_winid = opts.parent_winid

  -- Calculate dimensions
  local content_width = opts.width
  if not content_width then
    local max_line_len = 0
    for _, line in ipairs(opts.lines) do
      local w = vim.fn.strdisplaywidth(line)
      if w > max_line_len then
        max_line_len = w
      end
    end
    content_width = max_line_len + 2 -- padding for border
  end

  local content_height = opts.height or #opts.lines

  -- Pad lines to uniform width (avoids right-border overlap)
  local padded_lines = {}
  for _, line in ipairs(opts.lines) do
    if #line < content_width then
      table.insert(padded_lines, line .. string.rep(" ", content_width - #line))
    else
      table.insert(padded_lines, line)
    end
  end

  -- Create buffer
  local bufnr = create_help_buffer(padded_lines)
  _bufnr = bufnr

  -- Calculate position
  local pos = calculate_position(_parent_winid, content_width, content_height)

  -- Create window
  local win_config = {
    relative = "editor",
    row = pos.row,
    col = pos.col,
    width = content_width,
    height = content_height,
    style = "minimal",
    border = "single",
    title = opts.title,
    title_pos = "center",
    focusable = true,
    zindex = 150,
  }

  local winid = vim.api.nvim_open_win(bufnr, true, win_config)
  _winid = winid

  vim.api.nvim_set_option_value(
    "winhighlight",
    "Normal:NormalFloat",
    { win = winid }
  )

  -- Set up close keymaps
  setup_close_keymaps(bufnr)
end

---Close the help popup and return focus to parent window
function M.close()
  if _winid and vim.api.nvim_win_is_valid(_winid) then
    vim.api.nvim_win_close(_winid, true)
  end
  _winid = nil
  _bufnr = nil

  -- Return focus to parent window if still valid
  if _parent_winid and vim.api.nvim_win_is_valid(_parent_winid) then
    pcall(vim.api.nvim_set_current_win, _parent_winid)
  end
  _parent_winid = nil
end

---Toggle help popup
---@param opts table Same as M.show()
function M.toggle(opts)
  if _winid and vim.api.nvim_win_is_valid(_winid) then
    M.close()
  else
    M.show(opts)
  end
end

---Check if help popup is currently open
---@return boolean
function M.is_open()
  return _winid ~= nil and vim.api.nvim_win_is_valid(_winid)
end

return M
