---@class Radar.TabsLineMapping
---@field tabid integer
---@field winid integer?
---@field filepath string?

---@class Radar.State
local M = {}

---@return table
local function defaults()
  return {
    ---@type Radar.Lock[]
    locks = {},
    ---@type string[]
    recent_files = {},
    ---@type string[]
    session_files = {},
    -- Persisted recent files of the current project and branch, absolute
    ---@type string[]
    history = {},
    ---@type integer?
    edit_winid = nil,
    ---@type integer?
    edit_bufid = nil,
    ---@type integer?
    tabs_winid = nil,
    ---@type integer?
    tabs_bufid = nil,
    ---@type Radar.TabsLineMapping[]
    tabs_line_mapping = {},
  }
end

-- Internal state (not directly accessible from outside)
local _state = defaults()

---Reset all state to defaults (for testing)
function M.reset()
  _state = defaults()
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

---@return string[]
function M.get_history()
  return _state.history
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

---@param history string[]
function M.set_history(history)
  _state.history = history or {}
end

---@param winid integer?
function M.set_edit_winid(winid)
  _state.edit_winid = winid
end

---@param bufid integer?
function M.set_edit_bufid(bufid)
  _state.edit_bufid = bufid
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
