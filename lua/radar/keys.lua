local locks = require("radar.locks")
local mini_radar = require("radar.ui.mini_radar")
local edit = require("radar.ui.edit")
local navigation = require("radar.navigation")
local state = require("radar.state")
local persistence = require("radar.persistence")

local M = {}

---Setup all radar keymaps
---@param radar_config table
---@return nil
function M.setup(radar_config)
  -- Lock current buffer keymap
  vim.keymap.set("n", radar_config.keys.lock, function()
    locks.lock_current_buffer(nil, radar_config, persistence, mini_radar)
  end, { desc = "Lock the current buffer" })

  -- Close mini radar keymap
  vim.keymap.set("n", ";q", function()
    if
      state.mini_radar_winid
      and vim.api.nvim_win_is_valid(state.mini_radar_winid)
    then
      vim.api.nvim_win_close(state.mini_radar_winid, true)
      state.mini_radar_winid = nil
    end
  end, { desc = "Close Mini Radar" })

  -- Register lock keymaps
  navigation.register_file_keymaps(
    radar_config.keys.locks,
    navigation.open_lock,
    "Lock",
    radar_config,
    mini_radar
  )

  -- Register recent files keymaps
  navigation.register_file_keymaps(
    radar_config.keys.recent,
    navigation.open_recent,
    "Recent File",
    radar_config,
    mini_radar
  )

  -- Edit locks in floating window
  vim.keymap.set("n", radar_config.keys.prefix .. "e", function()
    edit.edit_locks(radar_config, mini_radar)
  end, { desc = "Edit radar locks" })
end

return M