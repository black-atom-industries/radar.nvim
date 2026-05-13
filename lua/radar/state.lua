---@class Radar.TabsLineMapping
---@field tabid integer
---@field winid integer?
---@field filepath string?

---@class Radar.State
local M = {
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

---Check if radar window is valid
---@return boolean
function M.are_radar_windows_valid()
  return M.radar_winid ~= nil and vim.api.nvim_win_is_valid(M.radar_winid)
end

---Close radar window
---@return nil
function M.close_all_radar_windows()
  if M.radar_winid and vim.api.nvim_win_is_valid(M.radar_winid) then
    vim.api.nvim_win_close(M.radar_winid, false)
  end

  M.radar_winid = nil
  M.focused_section = nil
  M.section_line_ranges = nil
  M.radar_origin = nil
end

---Get lock by field value
---@param field "label" | "filename"
---@param value string
---@return Radar.Lock?
function M.get_lock_by_field(field, value)
  for _, lock in ipairs(M.locks) do
    if lock[field] == value then
      return lock
    end
  end
end

---Check if tabs window is valid
---@return boolean
function M.is_tabs_window_valid()
  return M.tabs_winid ~= nil and vim.api.nvim_win_is_valid(M.tabs_winid)
end

---Close tabs window if valid
---@return nil
function M.close_tabs_window()
  if M.tabs_winid and vim.api.nvim_win_is_valid(M.tabs_winid) then
    vim.api.nvim_win_close(M.tabs_winid, false)
  end
  M.tabs_winid = nil
  M.tabs_bufid = nil
  M.tabs_line_mapping = {}
end

return M
