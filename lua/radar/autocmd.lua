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
      local mini_radar = require("radar.ui.mini_radar")
      recent.update_state(config)
      -- Only update if radar is open
      if mini_radar.exists() then
        mini_radar.update(config)
      end
    end,
  })

  autocmd("VimResized", {
    group = autogrp("radar.VimResized", { clear = true }),
    callback = function()
      local mini_radar = require("radar.ui.mini_radar")
      -- Only update if radar is open
      if mini_radar.exists() then
        mini_radar.update(config)
      end
    end,
  })

  autocmd("BufEnter", {
    group = autogrp("radar.BufEnter", { clear = true }),
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
end

return M
