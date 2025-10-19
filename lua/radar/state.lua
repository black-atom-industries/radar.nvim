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
  ---@type integer?
  edit_winid = nil,
  ---@type integer?
  edit_bufid = nil,
  ---@type integer?
  source_bufnr = nil,
  ---@type string?
  source_alt_file = nil,
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

return M
