---@class Radar.State
local M = {
  ---@type Radar.Lock[]
  locks = {},
  ---@type string[]
  recent_files = {},
  ---@type string[]
  session_files = {},
  ---@type integer?
  mini_radar_winid = nil,
  ---@type integer?
  edit_winid = nil,
  ---@type integer?
  edit_bufid = nil,
  ---@type boolean
  hidden_for_collision = false,
  ---@type integer
  mini_radar_row = 1,
  ---@type integer
  mini_radar_height = 1,
}

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

---Get lock by filename
---@param filename string
---@return Radar.Lock?
function M.get_lock_from_filename(filename)
  return M.get_lock_by_field("filename", filename)
end

---Get lock by label
---@param label string
---@return Radar.Lock?
function M.get_lock_from_label(label)
  return M.get_lock_by_field("label", label)
end

return M
