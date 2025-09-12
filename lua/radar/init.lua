local config = require("radar.config")
local state = require("radar.state")
local persistence = require("radar.persistence")
local locks = require("radar.locks")
local recent = require("radar.recent")
local mini_radar = require("radar.ui.mini_radar")
local edit = require("radar.ui.edit")
local navigation = require("radar.navigation")

local M = {}

M.config = config.default

---Setup function called by lazy.nvim or manual setup
---@param opts? Radar.Config
---@return nil
function M.setup(opts)
  opts = opts or {}
  local merged_config = vim.tbl_deep_extend("force", M.config, opts)
  M.config = merged_config

  -- Lock current buffer keymap
  vim.keymap.set("n", M.config.keys.lock, function()
    locks.lock_current_buffer(nil, M.config, persistence, mini_radar)
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
    M.config.keys.locks,
    navigation.open_lock,
    "Lock",
    M.config,
    mini_radar
  )

  -- Register recent files keymaps
  navigation.register_file_keymaps(
    M.config.keys.recent,
    navigation.open_recent,
    "Recent File",
    M.config,
    mini_radar
  )

  -- Edit locks in floating window
  vim.keymap.set("n", M.config.keys.prefix .. "e", function()
    edit.edit_locks(M.config, mini_radar)
  end, { desc = "Edit radar locks" })

  -- Populate initial state
  persistence.populate(M.config, mini_radar)

  -- Make module globally available for debugging
  _G.Radar = M
end

-- Autocmds
vim.api.nvim_create_autocmd("BufEnter", {
  group = vim.api.nvim_create_augroup("radar.BufEnter", { clear = true }),
  callback = function()
    -- Track current file for session recent files
    recent.track_current_file(M.config)
    -- Update recent files to include current session files
    recent.update_state(M.config)
    -- Update radar if it exists (this rebuilds content and applies highlights)
    if mini_radar.exists() then
      mini_radar.update(M.config)
    end
  end,
})

vim.api.nvim_create_autocmd("VimResized", {
  group = vim.api.nvim_create_augroup("radar.VimResized", { clear = true }),
  callback = function()
    mini_radar.update(M.config)
  end,
})

vim.api.nvim_create_autocmd("VimEnter", {
  group = vim.api.nvim_create_augroup("radar.VimEnter", { clear = true }),
  callback = function()
    -- Update recent files now that vim.v.oldfiles is loaded
    recent.update_state(M.config)
    -- Update the radar display if it exists, or create it if we now have content
    if mini_radar.exists() or #state.recent_files > 0 then
      mini_radar.update(M.config)
    end
  end,
})

return M
