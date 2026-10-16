local M = {}

local indicators = require("radar.ui.indicators")
local path_utils = require("radar.path")

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

---Build the content lines, section line ranges and line targets for the
---unified buffer
---@param config Radar.Config
---@return string[], Radar.SectionRanges, table<integer, Radar.RadarLineEntry>
local function build_content(config)
  local state = require("radar.data.state")
  local width = resolve_dimension(config.radar.size.width, vim.o.columns, 80)
  -- Account for internal padding on both sides (window width excludes border already)
  local pad_x = config.radar.padding and config.radar.padding.x or 1
  local pad_y = config.radar.padding and config.radar.padding.y or 1
  local content_width = math.max(width - pad_x, 40)
  local pad_str = string.rep(" ", pad_x)

  ---@type string[]
  local lines = {}
  ---@type table<integer, Radar.RadarLineEntry>
  local line_map = {}

  -- Top vertical padding
  for _ = 1, pad_y do
    table.insert(lines, pad_str)
  end

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
  local alt_label = config.keys.alternative
  local alt_file = state.get_source_alt_file()
  local alt_text
  if alt_file then
    alt_text = pad_str
      .. string.format("[%s] %s", alt_label, path_utils.display(alt_file))
  else
    alt_text = pad_str .. string.format("[%s] - No other file yet", alt_label)
  end
  section_ranges.alt.start = add_line(alt_text)
  section_ranges.alt["end"] = #lines

  -- ── Section divider ──
  add_line(pad_str)

  -- ── Locks section ──
  -- Skip stale locks whose files no longer exist
  local visible_locks = vim.tbl_filter(function(lock)
    return path_utils.is_url(lock.filename)
      or vim.fn.filereadable(path_utils.to_absolute(lock.filename)) == 1
  end, state.get_locks())
  local locks_count = #visible_locks
  local locks_title = pad_str .. config.radar.titles.locks
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

  for _, lock in ipairs(visible_locks) do
    local path = path_utils.display(lock.filename)
    local left = pad_str .. string.format("[%s] %s", lock.label, path)
    local bufnr = vim.fn.bufnr(path_utils.to_absolute(lock.filename))
    local buf_indicators = indicators.get_buffer_indicators(bufnr)
    local line = indicators.right_align_line(left, buf_indicators, content_width, 0)
    line_map[add_line(line)] = { section = "locks", target = lock.filename }
  end
  if locks_count == 0 and config.radar.show_empty_message then
    add_line(pad_str .. "No locks yet — press l to lock files")
  end
  section_ranges.locks["end"] = #lines

  -- ── Section divider ──
  add_line(pad_str)

  -- ── Recent section ──
  local recent_count = #state.get_recent_files()
  local recent_title = pad_str .. config.radar.titles.recent
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
      local path = path_utils.display(filename)
      local left
      if label then
        left = pad_str .. string.format("[%s] %s", label, path)
      else
        left = string.format("     %s", path)
      end
      local bufnr = vim.fn.bufnr(filename)
      local buf_indicators = indicators.get_buffer_indicators(bufnr)
      local line =
        indicators.right_align_line(left, buf_indicators, content_width, 0)
      line_map[add_line(line)] = { section = "recent", target = filename }
    end
  elseif config.radar.show_empty_message then
    add_line(pad_str .. "No recent files yet")
  end
  section_ranges.recent["end"] = #lines

  -- Bottom vertical padding
  for _ = 1, pad_y do
    table.insert(lines, pad_str)
  end

  return lines, section_ranges, line_map
end

---Apply highlights to the unified buffer
---@param bufnr integer
---@param config Radar.Config
local function apply_highlights(bufnr, config)
  local ns = vim.api.nvim_create_namespace("radar.ui")
  local locks_ns = vim.api.nvim_create_namespace("radar.locks")
  local recent_ns = vim.api.nvim_create_namespace("radar.recent")
  local lines = vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)

  -- Clear existing highlights
  vim.api.nvim_buf_clear_namespace(bufnr, ns, 0, -1)
  vim.api.nvim_buf_clear_namespace(bufnr, locks_ns, 0, -1)
  vim.api.nvim_buf_clear_namespace(bufnr, recent_ns, 0, -1)

  local state = require("radar.data.state")
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
          local pad_x = config.radar.padding and config.radar.padding.x or 0
          vim.api.nvim_buf_set_extmark(bufnr, ns, line_idx, pad_x, {
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
    curr_filepath_formatted = path_utils.to_lock_path(curr_filepath)
  end

  -- Locks store lock paths, recent entries store buffer names
  for line_nr, entry in pairs(state.get_radar_line_mapping()) do
    local is_lock = entry.section == "locks"
    local current = is_lock and curr_filepath_formatted or curr_filepath
    local line = lines[line_nr]
    if line and entry.target == current then
      local entry_ns = is_lock and locks_ns or recent_ns
      vim.api.nvim_buf_set_extmark(bufnr, entry_ns, line_nr - 1, 0, {
        end_col = #line,
        hl_group = "@function",
      })
    end
  end

  -- ── Indicator highlighting ──
  indicators.highlight_indicators(bufnr, ns, lines)
end

---Check if radar exists (window valid)
---@return boolean
function M.exists()
  local state = require("radar.data.state")
  return state.get_radar_winid() ~= nil
    and vim.api.nvim_win_is_valid(state.get_radar_winid())
end

---Forget the radar window and everything captured for it
---@return nil
local function reset_state()
  local state = require("radar.data.state")
  state.set_radar_winid(nil)
  state.set_radar_bufid(nil)
  state.set_source_bufnr(nil)
  state.set_source_alt_file(nil)
  state.set_focused_section(nil)
  state.set_section_line_ranges(nil)
  state.set_radar_line_mapping({})
end

---Close radar window
---@return nil
function M.close()
  local state = require("radar.data.state")
  -- Reset BEFORE closing the window so BufEnter autocmds don't
  -- see a valid radar and trigger a spurious update().
  local winid = state.get_radar_winid()
  reset_state()
  if winid and vim.api.nvim_win_is_valid(winid) then
    vim.api.nvim_win_close(winid, false)
  end
  -- Close help window if open
  require("radar.ui.help").close()
  require("radar.ui.hud").refresh()
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
  local state = require("radar.data.state")

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
  local alternative = require("radar.data.alternative")
  state.set_source_alt_file(alternative.get_alternative_file() or false)

  if not M.exists() then
    M.create(config)
  end
end

---Determine current section from cursor position
---@return "locks" | "recent" | nil
function M.get_focused_section_from_cursor()
  local state = require("radar.data.state")
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
  local state = require("radar.data.state")
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

---Render content, line targets and highlights into the radar buffer
---@param bufnr integer
---@param config Radar.Config
---@return integer line_count
local function render(bufnr, config)
  local state = require("radar.data.state")

  require("radar.data.recent").update_state(config)

  local lines, section_ranges, line_map = build_content(config)
  state.set_section_line_ranges(section_ranges)
  state.set_radar_line_mapping(line_map)

  vim.api.nvim_set_option_value("modifiable", true, { buf = bufnr })
  vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, lines)
  vim.api.nvim_set_option_value("modifiable", false, { buf = bufnr })

  apply_highlights(bufnr, config)

  return #lines
end

---Resolve the radar window config and remember its origin for tabs/edit
---@param config Radar.Config
---@param line_count integer
---@return vim.api.keyset.win_config
local function resolve_win_config(config, line_count)
  local state = require("radar.data.state")
  local width = resolve_dimension(config.radar.size.width, vim.o.columns, 80)
  local height = math.min(
    line_count,
    resolve_dimension(config.radar.size.height, vim.o.lines, 12)
  )

  local win_config =
    require("radar.ui.window").resolve_config(config, config.radar.win_preset, {
      width = width,
      height = height,
      title = " " .. config.radar.titles.main .. " ",
      title_pos = "left",
      border = config.radar.border,
    })

  ---@diagnostic disable-next-line: undefined-field
  state.set_radar_origin({
    ---@diagnostic disable-next-line: undefined-field
    row = math.floor(win_config.row or 0),
    ---@diagnostic disable-next-line: undefined-field
    col = math.floor(win_config.col or 0),
  })

  return win_config
end

---Line and section of the source file's entry, else the first lock line
---@param line_count integer
---@return integer, "locks" | "recent"
local function source_cursor(line_count)
  local state = require("radar.data.state")
  local line_map = state.get_radar_line_mapping()

  local src_buf = state.get_source_bufnr()
  local buf_name = src_buf
      and vim.api.nvim_buf_is_valid(src_buf)
      and vim.api.nvim_buf_get_name(src_buf)
    or ""
  if buf_name ~= "" then
    local src_filepath = path_utils.to_lock_path(buf_name)
    for line = 1, line_count do
      local entry = line_map[line]
      if
        entry
        and entry.target == (entry.section == "locks" and src_filepath or buf_name)
      then
        return line, entry.section
      end
    end
  end

  return state.get_section_line_ranges().locks.start + 1, "locks"
end

---Place the cursor on the source file's entry
---@param winid integer
---@param line_count integer
local function place_cursor(winid, line_count)
  local cursor_line, focused_section = source_cursor(line_count)
  require("radar.data.state").set_focused_section(focused_section)
  if cursor_line <= line_count then
    vim.api.nvim_win_set_cursor(winid, { cursor_line, 0 })
  end
end

---Create the unified radar window
---@param config Radar.Config
---@return nil
function M.create(config)
  local debug = require("radar.debug")
  local state = require("radar.data.state")

  debug.log("create() called")
  debug.log("  locks count =", #state.get_locks())
  debug.log("  recent count =", #state.get_recent_files())

  local bufnr = vim.api.nvim_create_buf(false, true)
  vim.api.nvim_set_option_value("buftype", "nofile", { buf = bufnr })
  vim.api.nvim_set_option_value("bufhidden", "wipe", { buf = bufnr })
  vim.api.nvim_set_option_value("swapfile", false, { buf = bufnr })

  local line_count = render(bufnr, config)
  require("radar.ui.keys").setup_all_keymaps(bufnr, config)

  local win_config = resolve_win_config(config, line_count)
  local winid = vim.api.nvim_open_win(bufnr, true, win_config)

  vim.api.nvim_set_option_value("winblend", config.radar.winblend, { win = winid })
  vim.api.nvim_set_option_value(
    "winhighlight",
    "Normal:NormalFloat",
    { win = winid }
  )
  for opt, value in pairs(config.radar.win_opts) do
    vim.api.nvim_set_option_value(opt, value, { win = winid })
  end

  state.set_radar_winid(winid)
  state.set_radar_bufid(bufnr)
  -- Windows closed without M.close() (:q, <C-w>c) still wipe the buffer
  vim.api.nvim_create_autocmd("BufWipeout", {
    buffer = bufnr,
    once = true,
    callback = function()
      if state.get_radar_bufid() == bufnr then
        reset_state()
        require("radar.ui.help").close()
        vim.schedule(require("radar.ui.hud").refresh)
      end
    end,
  })
  place_cursor(winid, line_count)
  require("radar.ui.hud").refresh()

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
  local state = require("radar.data.state")
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
  local state = require("radar.data.state")
  if
    not state.get_radar_winid()
    or not vim.api.nvim_win_is_valid(state.get_radar_winid())
  then
    return
  end

  local keys = config.keys
  local function range(labels)
    return #labels > 1 and (labels[1] .. "-" .. labels[#labels]) or labels[1] or ""
  end

  local lines = require("radar.ui.help").format({
    {
      title = "File Keys",
      rows = {
        { range(keys.locks), "Open lock" },
        { range(keys.recent), "Open recent" },
        { keys.alternative, "Alternative file" },
        { keys.line.open, "Open file" },
        { keys.line.vertical, "Window vertically" },
        { keys.line.horizontal, "Window horizontally" },
        { keys.line.tab, "Open in new tab" },
        { keys.line.float, "Float" },
        {
          table.concat(
            { keys.vertical, keys.horizontal, keys.tab, keys.float },
            "/"
          ) .. " + key",
          "Open in split/tab/float",
        },
      },
    },
    {
      title = "Actions",
      rows = {
        { keys.lock, "Lock/unlock" },
        { "e", "Edit locks" },
        { "t", "Tabs sidebar" },
        { "<Tab>/<S-Tab>", "Cycle section" },
        { "?", "Toggle help" },
        { "q/<Esc>/" .. keys.prefix, "Close radar" },
      },
    },
    {
      title = "Outside the radar, after " .. keys.prefix,
      rows = {
        { range(keys.locks), "Jump to lock" },
        { range(keys.recent), "Jump to recent" },
        { keys.prefix, "Open radar" },
        { "<Tab>", "Alternative file" },
        { keys.lock, "Lock/unlock buffer" },
        { keys.hud_toggle, "Toggle HUD" },
      },
    },
  })

  require("radar.ui.help").show({
    parent_winid = state.get_radar_winid(),
    title = "  RADAR HELP  ",
    lines = lines,
  })
end

---Re-render the open radar in place, or create it
---@param config Radar.Config
---@return nil
function M.update(config)
  local debug = require("radar.debug")
  local state = require("radar.data.state")
  debug.log("update() called")

  if not M.exists() then
    debug.log("  radar does not exist, delegating to create")
    M.create(config)
    return
  end

  local winid = state.get_radar_winid() --[[@as integer]]
  local bufnr = state.get_radar_bufid()
  if not bufnr or vim.api.nvim_win_get_buf(winid) ~= bufnr then
    local source_bufnr, source_alt_file =
      state.get_source_bufnr(), state.get_source_alt_file()
    M.close()
    state.set_source_bufnr(source_bufnr)
    state.set_source_alt_file(source_alt_file)
    M.create(config)
    return
  end

  local line_count = render(bufnr, config)

  local win_config = resolve_win_config(config, line_count)
  ---@type vim.api.keyset.win_config
  local geometry = { width = win_config.width, height = win_config.height }
  if win_config.relative ~= "cursor" then
    geometry.relative = win_config.relative
    geometry.win = win_config.win
    geometry.anchor = win_config.anchor
    geometry.row = win_config.row
    geometry.col = win_config.col
  end
  vim.api.nvim_win_set_config(winid, geometry)

  place_cursor(winid, line_count)
  debug.flush()
end

return M
