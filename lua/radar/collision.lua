local M = {}

---Helper function to handle operation failures with notification
---@param operation string Description of the operation that failed
---@param err any Error message
local function handle_operation_error(operation, err)
  vim.notify(
    "radar.nvim: " .. operation .. ": " .. tostring(err),
    vim.log.levels.WARN
  )
end

---Check if cursor position would collide with floating radar window
---@param radar_config Radar.Config
---@return boolean true if cursor is within window bounds
function M.check_collision(radar_config)
  -- Get cursor screen position (works correctly with splits)
  local cursor_col = vim.fn.screencol()

  -- Calculate where the window would be positioned (always top-right)
  local board_width = radar_config.windows.float.radar_window.config.width
  local window_col = math.floor((vim.o.columns - board_width) - 2)

  -- Add collision padding
  local collision_padding = radar_config.windows.float.collision_padding or 0
  local min_col = window_col - collision_padding
  local max_col = window_col + board_width + collision_padding

  -- Only check horizontal collision (cursor in the right area)
  local collides = cursor_col >= min_col and cursor_col <= max_col

  return collides
end

---Update window visibility based on collision state
---@param radar_config Radar.Config
function M.update_visibility(radar_config)
  -- Skip if collision detection is disabled
  if not radar_config.windows.float.hide_on_collision then
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
