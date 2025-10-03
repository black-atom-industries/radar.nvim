local M = {}

---Setup all radar keymaps
---@param config Radar.Config
---@return nil
function M.setup(config)
  -- Lock current buffer keymap
  vim.keymap.set("n", config.keys.lock, function()
    local locks = require("radar.locks")
    local mini_radar = require("radar.ui.mini_radar")
    local persistence = require("radar.persistence")
    locks.lock_current_buffer(nil, config, persistence, mini_radar)
  end, { desc = "Lock the current buffer" })

  -- Close mini radar keymap
  vim.keymap.set("n", ";q", function()
    local state = require("radar.state")
    if
      state.mini_radar_winid
      and vim.api.nvim_win_is_valid(state.mini_radar_winid)
    then
      vim.api.nvim_win_close(state.mini_radar_winid, true)
      state.mini_radar_winid = nil
    end
  end, { desc = "Close Mini Radar" })

  -- Register lock keymaps
  local navigation = require("radar.navigation")
  local mini_radar = require("radar.ui.mini_radar")
  navigation.register_file_keymaps(
    config.keys.locks,
    navigation.open_lock,
    "Lock",
    config,
    mini_radar
  )

  -- Register recent files keymaps
  navigation.register_file_keymaps(
    config.keys.recent,
    navigation.open_recent,
    "Recent File",
    config,
    mini_radar
  )

  -- Edit locks in floating window
  vim.keymap.set("n", config.keys.prefix .. "e", function()
    require("radar.ui.edit").edit_locks(config, mini_radar)
  end, { desc = "Edit radar locks" })
end

return M
