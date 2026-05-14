local M = {}

local indicators = require("radar.ui.indicators")

---Format file path to relative path from cwd
---@param path string
---@return string
function M.get_formatted_filepath(path)
  return vim.fn.fnamemodify(path, ":p:.")
end

---Resolve a grid dimension value (float 0-1 = percentage, integer = absolute)
---@param value number
---@param terminal_size integer vim.o.columns or vim.o.lines
---@param min_size integer
---@return integer
local function resolve_dimension(value, terminal_size, min_size)
  local resolved = value <= 1 and math.floor(terminal_size * value)
    or math.floor(value)
  return math.max(resolved, min_size)
end

---Calculate window origin based on config position setting
---@param config Radar.Config
---@param width integer Resolved window width
---@param height integer Resolved window height
---@return { row: integer, col: integer }
local function calculate_origin(config, width, height)
  local positions = {
    center = {
      row = math.floor((vim.o.lines - height) / 2),
      col = math.floor((vim.o.columns - width) / 2),
    },
    top_left = { row = 0, col = 0 },
    top_right = { row = 0, col = vim.o.columns - width },
    bottom_left = { row = vim.o.lines - height, col = 0 },
    bottom_right = {
      row = vim.o.lines - height,
      col = vim.o.columns - width,
    },
  }

  return positions[config.radar.position] or positions.center
end

---Build the content lines and section line ranges for the unified buffer
---@param config Radar.Config
---@return string[], Radar.SectionRanges
local function build_content(config)
  local state = require("radar.state")
  local width = resolve_dimension(config.radar.size.width, vim.o.columns, 80)
  -- Account for left + right window border (2 cells)
  local content_width = math.max(width - 2, 40)

  ---@type string[]
  local lines = {}
  ---@type Radar.SectionRanges
  local section_ranges = {
    alt = { start = 0, ["end"] = 0 },
    locks = { start = 0, ["end"] = 0 },
    recent = { start = 0, ["end"] = 0 },
  }

  local function add_line(text)
    table.insert(lines, text)
    return #lines
  end

  -- ── Alternative file ──
  local alt_label = config.keys.alternative or config.keys.prefix
  local alt_file = state.get_source_alt_file()
  local alt_text
  if alt_file then
    alt_text =
      string.format(" [%s] %s", alt_label, vim.fn.fnamemodify(alt_file, ":p:."))
  else
    alt_text = string.format(" [%s] - No other file yet", alt_label)
  end
  section_ranges.alt.start = add_line(alt_text)
  section_ranges.alt["end"] = #lines

  -- ── Section divider ──
  add_line("")

  -- ── Locks section ──
  local locks_count = #state.get_locks()
  local locks_title = " " .. config.radar.titles.locks
  local locks_header_full = locks_title
    .. string.rep(
      "─",
      math.max(
        content_width
          - vim.fn.strdisplaywidth(locks_title)
          - vim.fn.strdisplaywidth(tostring(locks_count))
          - 1,
        0
      )
    )
    .. " "
    .. locks_count
  section_ranges.locks.start = add_line(locks_header_full)

  if locks_count > 0 then
    for _, lock in ipairs(state.get_locks()) do
      local path = vim.fn.fnamemodify(lock.filename, ":p:.")
      local left = string.format(" [%s] %s", lock.label, path)
      local abs_path = vim.fn.fnamemodify(lock.filename, ":p")
      local bufnr = vim.fn.bufnr(abs_path)
      local buf_indicators = indicators.get_buffer_indicators(bufnr)
      local line =
        indicators.right_align_line(left, buf_indicators, content_width, 0)
      add_line(line)
    end
  elseif config.radar.show_empty_message then
    add_line(" No locks yet — press l to lock files")
  end
  section_ranges.locks["end"] = #lines

  -- ── Section divider ──
  add_line("")

  -- ── Recent section ──
  local recent_count = #state.get_recent_files()
  local recent_title = " " .. config.radar.titles.recent
  local recent_header_full = recent_title
    .. string.rep(
      "─",
      math.max(
        content_width
          - vim.fn.strdisplaywidth(recent_title)
          - vim.fn.strdisplaywidth(tostring(recent_count))
          - 1,
        0
      )
    )
    .. " "
    .. recent_count
  section_ranges.recent.start = add_line(recent_header_full)

  if recent_count > 0 then
    for i, filename in ipairs(state.get_recent_files()) do
      local label = config.keys.recent[i]
      local path = vim.fn.fnamemodify(filename, ":p:.")
      local left
      if label then
        left = string.format(" [%s] %s", label, path)
      else
        left = string.format("     %s", path)
      end
      local bufnr = vim.fn.bufnr(filename)
      local buf_indicators = indicators.get_buffer_indicators(bufnr)
      local line =
        indicators.right_align_line(left, buf_indicators, content_width, 0)
      add_line(line)
    end
  elseif config.radar.show_empty_message then
    add_line(" No recent files yet")
  end
  section_ranges.recent["end"] = #lines

  return lines, section_ranges
end

---Apply highlights to the unified buffer
---@param bufnr integer
local function apply_highlights(bufnr)
  local ns = vim.api.nvim_create_namespace("radar.ui")
  local locks_ns = vim.api.nvim_create_namespace("radar.locks")
  local recent_ns = vim.api.nvim_create_namespace("radar.recent")
  local lines = vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)

  -- Clear existing highlights
  vim.api.nvim_buf_clear_namespace(bufnr, ns, 0, -1)
  vim.api.nvim_buf_clear_namespace(bufnr, locks_ns, 0, -1)
  vim.api.nvim_buf_clear_namespace(bufnr, recent_ns, 0, -1)

  local state = require("radar.state")
  local section_ranges = state.get_section_line_ranges()
  if not section_ranges then
    return
  end

  -- ── Structural highlights ──

  -- Section header lines (first line of each section range)
  local header_lines = {
    { section = "locks", name = "locks" },
    { section = "recent", name = "recent" },
  }

  for _, hl in ipairs(header_lines) do
    local range = section_ranges[hl.section]
    if range and range.start > 0 then
      local line_idx = range.start - 1 -- 0-indexed extmark
      local line = lines[range.start]
      if line then
        -- Highlight label prefix (e.g., "🔒 Locks" or "📡 Recent")
        -- Find label end: the text before the ── fill
        local label_end = line:find("[─━]")
        if label_end then
          vim.api.nvim_buf_set_extmark(bufnr, ns, line_idx, 0, {
            end_col = label_end - 1,
            hl_group = "@function.builtin",
          })
          -- Highlight the count number after the dashes
          vim.api.nvim_buf_set_extmark(bufnr, ns, line_idx, label_end - 1, {
            end_col = #line,
            hl_group = "@comment",
          })
        else
          vim.api.nvim_buf_set_extmark(bufnr, ns, line_idx, 0, {
            end_col = #line,
            hl_group = "@function.builtin",
          })
        end
      end
    end
  end

  -- Highlight key labels on item lines ([1], [a], [<Space>])
  local function highlight_key_labels(range)
    if not range or range.start == 0 then
      return
    end
    for line_nr = range.start, range["end"] do
      local line = lines[line_nr]
      if line then
        local bracket_start = line:find("%[")
        local bracket_end = line:find("]")
        if bracket_start and bracket_end and bracket_end > bracket_start then
          vim.api.nvim_buf_set_extmark(
            bufnr,
            ns,
            line_nr - 1,
            bracket_start - 1,
            { end_col = bracket_end, hl_group = "@keyword" }
          )
        end
      end
    end
  end

  highlight_key_labels(section_ranges.alt)
  highlight_key_labels(section_ranges.locks)
  highlight_key_labels(section_ranges.recent)

  -- Footer line: dim it
  local last_line = #lines
  if last_line > 0 then
    vim.api.nvim_buf_set_extmark(bufnr, ns, last_line - 1, 0, {
      end_col = #lines[last_line],
      hl_group = "@comment",
    })
  end

  -- ── Current file highlighting ──

  -- Get current file for highlighting (use the source buffer, not the radar buffer)
  local curr_filepath = ""
  if
    state.get_source_bufnr() and vim.api.nvim_buf_is_valid(state.get_source_bufnr())
  then
    curr_filepath = vim.api.nvim_buf_get_name(state.get_source_bufnr())
  end
  local curr_filepath_formatted = ""
  if curr_filepath ~= "" then
    curr_filepath_formatted = vim.fn.fnamemodify(curr_filepath, ":p:.")
  end

  -- Highlight locks entries that match current file
  if section_ranges.locks and section_ranges.locks.start > 0 then
    local lock_start = section_ranges.locks.start
    for i, lock in ipairs(state.get_locks()) do
      local line_nr = lock_start + i
      local line = lines[line_nr]
      if line and lock.filename == curr_filepath_formatted then
        vim.api.nvim_buf_set_extmark(bufnr, locks_ns, line_nr - 1, 0, {
          end_col = #line,
          hl_group = "@function",
        })
      end
    end
  end

  -- Highlight recent entries that match current file
  if section_ranges.recent and section_ranges.recent.start > 0 then
    local recent_start = section_ranges.recent.start
    for i, filename in ipairs(state.get_recent_files()) do
      local line_nr = recent_start + i
      local line = lines[line_nr]
      if line and filename == curr_filepath then
        vim.api.nvim_buf_set_extmark(bufnr, recent_ns, line_nr - 1, 0, {
          end_col = #line,
          hl_group = "@function",
        })
      end
    end
  end

  -- ── Indicator highlighting ──
  indicators.highlight_indicators(bufnr, ns, lines)
end

---Check if radar exists (window valid)
---@return boolean
function M.exists()
  local state = require("radar.state")
  return state.get_radar_winid() ~= nil
    and vim.api.nvim_win_is_valid(state.get_radar_winid())
end

---Close radar window
---@return nil
function M.close()
  local state = require("radar.state")
  if
    state.get_radar_winid() and vim.api.nvim_win_is_valid(state.get_radar_winid())
  then
    vim.api.nvim_win_close(state.get_radar_winid(), false)
  end
  -- Close help window if open
  require("radar.ui.help").close()
  state.set_radar_winid(nil)
  state.set_focused_section(nil)
  state.set_section_line_ranges(nil)
end

---Toggle radar visibility
---@param config Radar.Config
---@return nil
function M.toggle(config)
  if M.exists() then
    M.close()
  else
    M.open(config)
  end
end

---Open radar and focus locks section
---@param config Radar.Config
---@return nil
function M.open(config)
  local debug = require("radar.debug")
  local state = require("radar.state")

  -- Store the buffer we're opening from
  state.set_source_bufnr(vim.api.nvim_get_current_buf())
  debug.log("=== radar.open() ===")
  debug.log("  source_bufnr set to =", state.get_source_bufnr())
  debug.log(
    "  source buf name =",
    vim.api.nvim_buf_get_name(state.get_source_bufnr())
  )
  debug.log("  current buffer =", vim.api.nvim_get_current_buf())
  debug.flush()

  -- Capture the alternate file before focus changes
  local alternative = require("radar.alternative")
  state.set_source_alt_file(alternative.get_alternative_file())

  if not M.exists() then
    M.create(config)
  end
end

---Get buffer ID of the single radar window
---@return integer?
function M.get_focused_bufid()
  local state = require("radar.state")
  if
    not state.get_radar_winid()
    or not vim.api.nvim_win_is_valid(state.get_radar_winid())
  then
    return nil
  end
  return vim.api.nvim_win_get_buf(state.get_radar_winid())
end

---Determine current section from cursor position
---@return "locks" | "recent" | nil
function M.get_focused_section_from_cursor()
  local state = require("radar.state")
  if
    not state.get_radar_winid()
    or not vim.api.nvim_win_is_valid(state.get_radar_winid())
  then
    return nil
  end

  local cursor_line = vim.api.nvim_win_get_cursor(state.get_radar_winid())[1]
  local ranges = state.get_section_line_ranges()

  if not ranges then
    return nil
  end

  if cursor_line >= ranges.locks.start and cursor_line <= ranges.locks["end"] then
    return "locks"
  end
  if cursor_line >= ranges.recent.start and cursor_line <= ranges.recent["end"] then
    return "recent"
  end

  return nil
end

---Cycle focus to next section (Tab)
---@return nil
function M.cycle_focus_next()
  local state = require("radar.state")
  if
    not state.get_radar_winid()
    or not vim.api.nvim_win_is_valid(state.get_radar_winid())
  then
    return
  end

  local current = state.get_focused_section() or "locks"
  local ranges = state.get_section_line_ranges()
  if not ranges then
    return
  end

  -- alt → locks → recent → alt
  local next_section = current == "locks" and "recent" or "locks"
  local target_range = ranges[next_section]
  if target_range and target_range.start > 0 then
    vim.api.nvim_win_set_cursor(state.get_radar_winid(), { target_range.start, 0 })
    state.set_focused_section(next_section)
  end
end

---Cycle focus to previous section (S-Tab)
---@return nil
function M.cycle_focus_prev()
  -- Same as next for 2 focusable sections (locks, recent)
  M.cycle_focus_next()
end

---Create the unified radar window
---@param config Radar.Config
---@return nil
function M.create(config)
  local debug = require("radar.debug")
  local state = require("radar.state")

  debug.log("create() called")
  debug.log("  locks count =", #state.get_locks())
  debug.log("  recent count =", #state.get_recent_files())

  -- Update recent files first
  local recent = require("radar.recent")
  recent.update_state(config)

  -- Build content lines
  local lines, section_ranges = build_content(config)
  state.set_section_line_ranges(section_ranges)

  debug.log("  content lines =", #lines)
  debug.log("  section_ranges =", section_ranges)

  -- Calculate window dimensions
  local width = resolve_dimension(config.radar.size.width, vim.o.columns, 80)
  local content_height = #lines
  local total_height = math.min(
    content_height,
    resolve_dimension(config.radar.size.height, vim.o.lines, 12)
  )
  local origin = calculate_origin(config, width, total_height)

  debug.log(
    "  window: ",
    width,
    "x",
    total_height,
    "at",
    origin.row,
    ",",
    origin.col
  )

  -- Store for tabs/edit to reuse
  state.set_radar_origin(origin)

  -- Create buffer
  local bufnr = vim.api.nvim_create_buf(false, true)
  vim.api.nvim_set_option_value("buftype", "nofile", { buf = bufnr })
  vim.api.nvim_set_option_value("bufhidden", "hide", { buf = bufnr })
  vim.api.nvim_set_option_value("swapfile", false, { buf = bufnr })
  vim.api.nvim_set_option_value("modifiable", false, { buf = bufnr })

  -- Set content
  vim.api.nvim_set_option_value("modifiable", true, { buf = bufnr })
  vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, lines)
  vim.api.nvim_set_option_value("modifiable", false, { buf = bufnr })

  -- Set up buffer-local keymaps
  local keys = require("radar.keys")
  keys.setup_all_keymaps(bufnr, config)

  -- Compute cursor position BEFORE creating window (BufEnter autocmds
  -- triggered by nvim_open_win can mutate state.get_recent_files() via
  -- get_alternative_file() returning the source buffer as alt file)
  local cursor_line = nil
  local focused_section = "locks"

  local src_buf = state.get_source_bufnr()
  if src_buf and vim.api.nvim_buf_is_valid(src_buf) then
    local buf_name = vim.api.nvim_buf_get_name(src_buf)
    local src_filepath = vim.fn.fnamemodify(buf_name, ":p:.")
    if src_filepath ~= "" then
      -- Check locks first
      for i, lock in ipairs(state.get_locks()) do
        if lock.filename == src_filepath then
          cursor_line = section_ranges.locks.start + i
          focused_section = "locks"
          break
        end
      end

      -- Check recent files if not found in locks
      if not cursor_line then
        for i, filename in ipairs(state.get_recent_files()) do
          if filename == buf_name then
            cursor_line = section_ranges.recent.start + i
            focused_section = "recent"
            break
          end
        end
      end
    end
  end

  -- Fallback to first locks entry
  if not cursor_line then
    cursor_line = section_ranges.locks.start + 1
  end

  -- Create window
  local win_opts = {
    relative = "editor",
    row = origin.row,
    col = origin.col,
    width = width,
    height = total_height,
    style = "minimal",
    border = config.radar.border,
    title = " " .. config.radar.titles.main .. " ",
    title_pos = "left",
    focusable = true,
    zindex = 100,
  }

  local winid = vim.api.nvim_open_win(bufnr, true, win_opts)

  -- Apply window options
  vim.api.nvim_set_option_value("winblend", config.radar.winblend, { win = winid })
  -- Ensure solid non-transparent background
  vim.api.nvim_set_option_value(
    "winhighlight",
    "Normal:NormalFloat",
    { win = winid }
  )
  for opt, value in pairs(config.radar.win_opts) do
    vim.api.nvim_set_option_value(opt, value, { win = winid })
  end

  -- Apply highlights
  apply_highlights(bufnr)

  -- Store in state
  state.set_radar_winid(winid)
  state.set_focused_section(focused_section)

  if cursor_line <= #lines then
    vim.api.nvim_win_set_cursor(winid, { cursor_line, 0 })
  end

  debug.flush()

  debug.log("  radar window created, winid =", winid)
  debug.flush()
end

---Close radar help window
---@return nil
function M.close_help()
  require("radar.ui.help").close()
end

---Toggle radar help popup
---@param config Radar.Config
---@return nil
function M.toggle_help(config)
  local state = require("radar.state")
  if
    not state.get_radar_winid()
    or not vim.api.nvim_win_is_valid(state.get_radar_winid())
  then
    return
  end

  local help = require("radar.ui.help")
  if help.is_open() then
    help.close()
  else
    M.show_help(config)
  end
end

---Show radar help popup centered over the radar window
---@param config Radar.Config
---@return nil
function M.show_help(config)
  local state = require("radar.state")
  if
    not state.get_radar_winid()
    or not vim.api.nvim_win_is_valid(state.get_radar_winid())
  then
    return
  end

  local alt_label = config.keys.alternative or config.keys.prefix

  local lines = {
    "                          ",
    "  File Keys               ",
    "    1-9    Open lock        ",
    "    a-g    Open recent      ",
    "    <Spc>  Alternative file ",
    "    <CR>   Open file        ",
    "    V      Window vertically",
    "    S      Window horizontally",
    "    T      Open in new tab  ",
    "    F      Float            ",
    "                          ",
    "  Actions                 ",
    "    l      Lock/unlock      ",
    "    e      Edit locks       ",
    "    t      Tabs sidebar     ",
    "    <Tab>  Cycle section    ",
    "    q      Close radar      ",
    "                          ",
  }

  -- Substitute actual alt key
  for i, line in ipairs(lines) do
    lines[i] = line:gsub("<Spc>", "[" .. alt_label .. "]")
  end

  require("radar.ui.help").show({
    parent_winid = state.get_radar_winid(),
    title = "  RADAR HELP  ",
    lines = lines,
  })
end

---Update radar window (close and recreate)
---@param config Radar.Config
---@return nil
function M.update(config)
  local debug = require("radar.debug")
  debug.log("update() called")

  if not M.exists() then
    debug.log("  radar does not exist, delegating to create")
    M.create(config)
    return
  end

  -- Update recent files
  local recent = require("radar.recent")
  recent.update_state(config)

  -- Close and recreate
  debug.log("  closing window and recreating")
  M.close()
  M.create(config)
  debug.flush()
end

return M
