local M = {}

---@param config Radar.Config
function M.setup(config)
  vim.api.nvim_create_autocmd("VimEnter", {
    group = vim.api.nvim_create_augroup("radar.VimEnter", { clear = true }),
    callback = function()
      -- Update recent files now that vim.v.oldfiles is loaded
      local recent = require("radar.recent")
      local mini_radar = require("radar.ui.mini_radar")
      local state = require("radar.state")
      recent.update_state(config)
      -- Update the radar display if it exists, or create it if we now have content
      if mini_radar.exists() or #state.recent_files > 0 then
        mini_radar.update(config)
      end
    end,
  })

  vim.api.nvim_create_autocmd("VimResized", {
    group = vim.api.nvim_create_augroup("radar.VimResized", { clear = true }),
    callback = function()
      local mini_radar = require("radar.ui.mini_radar")
      mini_radar.update(config)
    end,
  })

  -- Autocmds
  vim.api.nvim_create_autocmd("BufEnter", {
    group = vim.api.nvim_create_augroup("radar.BufEnter", { clear = true }),
    callback = function()
      local recent = require("radar.recent")
      local mini_radar = require("radar.ui.mini_radar")
      -- Track current file for session recent files
      recent.track_current_file(config)
      -- Update recent files to include current session files
      recent.update_state(config)
      -- Update radar if it exists (this rebuilds content and applies highlights)
      if mini_radar.exists() then
        mini_radar.update(config)
      end
    end,
  })

  -- Collision detection on cursor movement (throttled for performance)
  local last_collision_check = 0
  local COLLISION_THROTTLE_MS = 50 -- Only check collision every 50ms

  vim.api.nvim_create_autocmd({ "CursorMoved", "CursorMovedI" }, {
    group = vim.api.nvim_create_augroup("radar.CursorMoved", { clear = true }),
    callback = function()
      local now = vim.uv.hrtime() / 1000000 -- Convert nanoseconds to milliseconds
      if now - last_collision_check >= COLLISION_THROTTLE_MS then
        local collision = require("radar.collision")
        collision.update_visibility(config)
        last_collision_check = now
      end
    end,
  })
end

return M
