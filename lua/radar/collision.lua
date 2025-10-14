local M = {}

---Helper function to handle operation failures with notification
---@param operation string Description of the operation that failed
---@param err string Error message
local function handle_operation_error(operation, err)
  vim.notify(
    "radar.nvim: " .. operation .. ": " .. tostring(err),
    vim.log.levels.WARN
  )
end

---Check if cursor position would collide with floating radar window
---@param radar_config table
---@return boolean true if cursor is on same line as radar window
function M.check_collision(radar_config)
  local cursor_row = vim.fn.screenrow()

  -- Use stored window position (available even when window is hidden)
  local state = require("radar.state")
  local win_row = state.mini_radar_row or 1
  local content_height = state.mini_radar_height or 1

  -- Account for border (top border + title = 1 row, bottom border = 1 row)
  -- Actual window height on screen = content_height + 2
  local actual_height = content_height + 2

  -- Check if cursor is within window's vertical range
  return cursor_row >= win_row and cursor_row < win_row + actual_height
end

---Update window visibility based on collision state
---@param radar_config table
function M.update_visibility(radar_config)
  -- Skip if collision detection is disabled
  if not radar_config.hide_on_collision then
    return
  end

  local has_collision = M.check_collision(radar_config)

  -- If collision state changed, update visibility
  local state = require("radar.state")
  if has_collision and not state.hidden_for_collision then
    -- Hide window due to collision
    if
      state.mini_radar_winid and vim.api.nvim_win_is_valid(state.mini_radar_winid)
    then
      local success, err =
        pcall(vim.api.nvim_win_close, state.mini_radar_winid, true)
      if not success then
        handle_operation_error("Failed to close window during collision", err)
      end
      state.mini_radar_winid = nil
      state.hidden_for_collision = true
    end
  elseif not has_collision and state.hidden_for_collision then
    -- Show window again (collision resolved)
    local mini_radar = require("radar.ui.mini_radar")
    state.hidden_for_collision = false
    local success, err = pcall(mini_radar.update, radar_config)
    if not success then
      handle_operation_error("Failed to show window after collision resolved", err)
    end
  end
end

---Check if window is currently hidden due to collision
---@return boolean
function M.is_hidden_for_collision()
  local state = require("radar.state")
  return state.hidden_for_collision or false
end

return M