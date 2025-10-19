local M = {}

---@param config Radar.Config
function M.setup(config)
  local autocmd = vim.api.nvim_create_autocmd
  local autogrp = vim.api.nvim_create_augroup

  autocmd({ "VimEnter", "SessionLoadPost" }, {
    nested = true,
    group = autogrp("radar.VimEnter", { clear = true }),
    callback = function()
      -- Update recent files now that vim.v.oldfiles is loaded
      local recent = require("radar.recent")
      local radar = require("radar.ui.radar")
      recent.update_state(config)
      -- Only update if radar is open
      if radar.exists() then
        radar.update(config)
      end
    end,
  })

  autocmd("VimResized", {
    group = autogrp("radar.VimResized", { clear = true }),
    callback = function()
      local radar = require("radar.ui.radar")
      -- Only update if radar is open
      if radar.exists() then
        radar.update(config)
      end
    end,
  })

  autocmd("BufEnter", {
    group = autogrp("radar.BufEnter", { clear = true }),
    callback = function()
      local state = require("radar.state")
      local recent = require("radar.recent")
      local radar = require("radar.ui.radar")

      -- Skip update if we're switching focus between radar windows
      if state.switching_focus then
        return
      end

      -- Track current file for session recent files
      recent.track_current_file(config)
      -- Update recent files to include current session files
      recent.update_state(config)
      -- Update radar if it exists (this rebuilds content and applies highlights)
      if radar.exists() then
        radar.update(config)
      end
    end,
  })
end

return M
