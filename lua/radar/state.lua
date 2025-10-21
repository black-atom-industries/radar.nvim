---@class Radar.State
local M = {
  ---@type Radar.Lock[]
  locks = {},
  ---@type string[]
  recent_files = {},
  ---@type string[]
  session_files = {},
  ---@type { path: string, staged: string, unstaged: string }[]
  modified_files = {},
  ---@type { path: string, staged: string, unstaged: string }[]
  pr_files = {},
  ---@type boolean
  has_pr = false,
  ---@type { files: { path: string, staged: string, unstaged: string }[], has_pr: boolean, commit_hash: string?, is_loading: boolean }
  pr_cache = {
    files = {},
    has_pr = false,
    commit_hash = nil,
    is_loading = false,
  },
  ---@type { alternative: integer?, locks: integer?, recent: integer?, modified: integer?, pull_request: integer? }?
  radar_windows = nil,
  ---@type "locks" | "recent" | "modified" | "pull_request"?
  focused_section = nil,
  ---@type integer?
  edit_winid = nil,
  ---@type integer?
  edit_bufid = nil,
  ---@type integer?
  source_bufnr = nil,
  ---@type string?
  source_alt_file = nil,
  ---@type boolean
  switching_focus = false,
}

---Check if all radar windows are valid
---@return boolean
function M.are_radar_windows_valid()
  if not M.radar_windows then
    return false
  end

  for section, winid in pairs(M.radar_windows) do
    if not winid or not vim.api.nvim_win_is_valid(winid) then
      return false
    end
  end

  return true
end

---Close all radar windows
---@return nil
function M.close_all_radar_windows()
  if not M.radar_windows then
    return
  end

  for section, winid in pairs(M.radar_windows) do
    if winid and vim.api.nvim_win_is_valid(winid) then
      vim.api.nvim_win_close(winid, false)
    end
  end

  M.radar_windows = nil
  M.focused_section = nil
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

return M
