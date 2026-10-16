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
      local recent = require("radar.data.recent")
      local radar = require("radar.ui.radar")
      recent.update_state(config)
      -- Only update if radar is open
      if radar.exists() then
        radar.update(config)
      end
      require("radar.ui.hud").refresh()
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
      require("radar.ui.hud").refresh()
    end,
  })

  autocmd("BufEnter", {
    group = autogrp("radar.BufEnter", { clear = true }),
    callback = function()
      local recent = require("radar.data.recent")
      local radar = require("radar.ui.radar")

      if recent.track_current_file(config) then
        local persistence = require("radar.persist.persistence")
        local snapshot = persistence.recent_snapshot()
        if snapshot.project and snapshot.branch then
          vim.defer_fn(function()
            persistence.persist(config, snapshot)
          end, config.persist.defer_ms)
        end
      end
      -- Update recent files to include current session files
      recent.update_state(config)
      -- Update radar if it exists (this rebuilds content and applies highlights)
      if radar.exists() then
        radar.update(config)
      end
      require("radar.ui.hud").refresh()
    end,
  })

  -- Reload state when directory changes (e.g., worktree switches, :cd)
  autocmd("DirChanged", {
    group = autogrp("radar.DirChanged", { clear = true }),
    callback = function()
      local persistence = require("radar.persist.persistence")
      local recent = require("radar.data.recent")
      local radar = require("radar.ui.radar")

      persistence.populate_if_changed(config)
      recent.update_state(config)
      -- Refresh radar if open
      if radar.exists() then
        radar.update(config)
      end
      require("radar.ui.hud").refresh()
    end,
  })

  -- Reload state after a branch switch outside Neovim
  autocmd("FocusGained", {
    group = autogrp("radar.FocusGained", { clear = true }),
    callback = function()
      require("radar.persist.persistence").populate_if_changed(config)
      require("radar.ui.hud").refresh()
    end,
  })

  autocmd({ "TabEnter", "WinEnter", "WinResized" }, {
    group = autogrp("radar.HudTabEnter", { clear = true }),
    callback = function()
      require("radar.ui.hud").refresh()
    end,
  })

  autocmd({ "CursorMoved", "CursorMovedI", "WinScrolled" }, {
    group = autogrp("radar.HudDodge", { clear = true }),
    callback = function()
      require("radar.ui.hud").dodge()
    end,
  })

  -- Tabs sidebar updates
  autocmd({ "BufEnter", "TabEnter", "TabClosed", "WinEnter" }, {
    group = autogrp("radar.TabsUpdate", { clear = true }),
    callback = function()
      local tabs_ui = require("radar.ui.tabs")
      if tabs_ui.exists() then
        tabs_ui.update(config)
      end
    end,
  })
end

return M
