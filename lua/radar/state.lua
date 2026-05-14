---@class Radar.TabsLineMapping
---@field tabid integer
---@field winid integer?
---@field filepath string?

---@class Radar.State
local M = {}

-- Internal state (not directly accessible from outside)
local _state = {
  ---@type Radar.Lock[]
  locks = {},
  ---@type string[]
  recent_files = {},
  ---@type string[]
  session_files = {},
  ---@type integer?
  radar_winid = nil,
  ---@type "locks" | "recent"?
  focused_section = nil,
  ---@type Radar.SectionRanges?
  section_line_ranges = nil,
  ---@type { row: integer, col: integer }?
  radar_origin = nil,
  ---@type integer?
  edit_winid = nil,
  ---@type integer?
  edit_bufid = nil,
  ---@type integer?
  source_bufnr = nil,
  ---@type string?
  source_alt_file = nil,
  ---@type integer?
  tabs_winid = nil,
  ---@type integer?
  tabs_bufid = nil,
  ---@type Radar.TabsLineMapping[]
  tabs_line_mapping = {},
}

---Reset all state to defaults (for testing)
function M.reset()
  _state = {
    locks = {},
    recent_files = {},
    session_files = {},
    radar_winid = nil,
    focused_section = nil,
    section_line_ranges = nil,
    radar_origin = nil,
    edit_winid = nil,
    edit_bufid = nil,
    source_bufnr = nil,
    source_alt_file = nil,
    tabs_winid = nil,
    tabs_bufid = nil,
    tabs_line_mapping = {},
  }
end

-- Getters
---@return Radar.Lock[]
function M.get_locks()
  return _state.locks
end

---@return string[]
function M.get_recent_files()
  return _state.recent_files
end

---@return string[]
function M.get_session_files()
  return _state.session_files
end

---@return integer?
function M.get_radar_winid()
  return _state.radar_winid
end

---@return "locks"|"recent"?
function M.get_focused_section()
  return _state.focused_section
end

---@return Radar.SectionRanges?
function M.get_section_line_ranges()
  return _state.section_line_ranges
end

---@return { row: integer, col: integer }?
function M.get_radar_origin()
  return _state.radar_origin
end

---@return integer?
function M.get_edit_winid()
  return _state.edit_winid
end

---@return integer?
function M.get_edit_bufid()
  return _state.edit_bufid
end

---@return integer?
function M.get_source_bufnr()
  return _state.source_bufnr
end

---@return string?
function M.get_source_alt_file()
  return _state.source_alt_file
end

---@return integer?
function M.get_tabs_winid()
  return _state.tabs_winid
end

---@return integer?
function M.get_tabs_bufid()
  return _state.tabs_bufid
end

---@return Radar.TabsLineMapping[]
function M.get_tabs_line_mapping()
  return _state.tabs_line_mapping
end

-- Setters
---@param locks Radar.Lock[]
function M.set_locks(locks)
  _state.locks = locks or {}
end

---@param recent_files string[]
function M.set_recent_files(recent_files)
  _state.recent_files = recent_files or {}
end

---@param session_files string[]
function M.set_session_files(session_files)
  _state.session_files = session_files or {}
end

---@param winid integer?
function M.set_radar_winid(winid)
  _state.radar_winid = winid
end

---@param section "locks"|"recent"?
function M.set_focused_section(section)
  _state.focused_section = section
end

---@param ranges Radar.SectionRanges?
function M.set_section_line_ranges(ranges)
  _state.section_line_ranges = ranges
end

---@param origin { row: integer, col: integer }?
function M.set_radar_origin(origin)
  _state.radar_origin = origin
end

---@param winid integer?
function M.set_edit_winid(winid)
  _state.edit_winid = winid
end

---@param bufid integer?
function M.set_edit_bufid(bufid)
  _state.edit_bufid = bufid
end

---@param bufnr integer?
function M.set_source_bufnr(bufnr)
  _state.source_bufnr = bufnr
end

---@param alt_file string?
function M.set_source_alt_file(alt_file)
  _state.source_alt_file = alt_file
end

---@param winid integer?
function M.set_tabs_winid(winid)
  _state.tabs_winid = winid
end

---@param bufid integer?
function M.set_tabs_bufid(bufid)
  _state.tabs_bufid = bufid
end

---@param mapping Radar.TabsLineMapping[]
function M.set_tabs_line_mapping(mapping)
  _state.tabs_line_mapping = mapping or {}
end

-- Methods

---Check if radar window is valid
---@return boolean
function M.are_radar_windows_valid()
  return _state.radar_winid ~= nil and vim.api.nvim_win_is_valid(_state.radar_winid)
end

---Close radar window
---@return nil
function M.close_all_radar_windows()
  if _state.radar_winid and vim.api.nvim_win_is_valid(_state.radar_winid) then
    vim.api.nvim_win_close(_state.radar_winid, false)
  end

  _state.radar_winid = nil
  _state.focused_section = nil
  _state.section_line_ranges = nil
  _state.radar_origin = nil
end

---Get lock by field value
---@param field "label" | "filename"
---@param value string
---@return Radar.Lock?
function M.get_lock_by_field(field, value)
  for _, lock in ipairs(_state.locks) do
    if lock[field] == value then
      return lock
    end
  end
end

---Check if tabs window is valid
---@return boolean
function M.is_tabs_window_valid()
  return _state.tabs_winid ~= nil and vim.api.nvim_win_is_valid(_state.tabs_winid)
end

---Close tabs window if valid
---@return nil
function M.close_tabs_window()
  if _state.tabs_winid and vim.api.nvim_win_is_valid(_state.tabs_winid) then
    vim.api.nvim_win_close(_state.tabs_winid, false)
  end
  _state.tabs_winid = nil
  _state.tabs_bufid = nil
  _state.tabs_line_mapping = {}
end

return M
