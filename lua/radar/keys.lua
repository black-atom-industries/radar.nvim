local M = {}

---Setup global keymaps (only toggle)
---@param config Radar.Config
---@return nil
function M.setup(config)
  local mini_radar = require("radar.ui.mini_radar")

  -- Global toggle keymap (prefix becomes toggle)
  vim.keymap.set("n", config.keys.prefix, function()
    mini_radar.toggle(config)
  end, { desc = "Toggle Radar" })
end

---Helper to register all split mode keymaps for a single action
---@param bufnr integer
---@param key string Base key for the action
---@param action function Function to call with open_cmd
---@param desc string Description for keymaps
---@param config Radar.Config
local function register_split_variants(bufnr, key, action, desc, config)
  local opts = { buffer = bufnr, silent = true, noremap = true, nowait = true }
  local modes = {
    { key = key, cmd = nil, desc = desc },
    {
      key = config.keys.vertical .. key,
      cmd = "vsplit",
      desc = desc .. " in vertical split",
    },
    {
      key = config.keys.horizontal .. key,
      cmd = "split",
      desc = desc .. " in horizontal split",
    },
    { key = config.keys.tab .. key, cmd = "tabedit", desc = desc .. " in new tab" },
    {
      key = config.keys.float .. key,
      cmd = "float",
      desc = desc .. " in floating window",
    },
  }

  for _, mode in ipairs(modes) do
    vim.keymap.set("n", mode.key, function()
      action(mode.cmd)
    end, vim.tbl_extend("force", opts, { desc = mode.desc }))
  end
end

---Setup buffer-local keymaps for radar window
---@param bufnr integer
---@param config Radar.Config
---@return nil
function M.setup_buffer_local_keymaps(bufnr, config)
  local navigation = require("radar.navigation")
  local mini_radar = require("radar.ui.mini_radar")
  local opts = { buffer = bufnr, silent = true, noremap = true, nowait = true }

  -- Close radar
  vim.keymap.set("n", "q", function()
    mini_radar.close()
  end, vim.tbl_extend("force", opts, { desc = "Close Radar" }))

  vim.keymap.set("n", "<Esc>", function()
    mini_radar.close()
  end, vim.tbl_extend("force", opts, { desc = "Close Radar" }))

  -- Line-based navigation - all split variants
  register_split_variants(bufnr, config.keys.line.open, function(cmd)
    navigation.open_file_from_line(cmd, config, mini_radar)
  end, "Open file from line", config)

  -- Use separate keys for line-based splits (V, S, T, F)
  vim.keymap.set("n", config.keys.line.vertical, function()
    navigation.open_file_from_line("vsplit", config, mini_radar)
  end, vim.tbl_extend("force", opts, { desc = "Open file in vertical split" }))

  vim.keymap.set("n", config.keys.line.horizontal, function()
    navigation.open_file_from_line("split", config, mini_radar)
  end, vim.tbl_extend("force", opts, { desc = "Open file in horizontal split" }))

  vim.keymap.set("n", config.keys.line.tab, function()
    navigation.open_file_from_line("tabedit", config, mini_radar)
  end, vim.tbl_extend("force", opts, { desc = "Open file in new tab" }))

  vim.keymap.set("n", config.keys.line.float, function()
    navigation.open_file_from_line("float", config, mini_radar)
  end, vim.tbl_extend("force", opts, { desc = "Open file in floating window" }))

  -- Lock current buffer
  vim.keymap.set("n", config.keys.lock, function()
    local locks = require("radar.locks")
    local persistence = require("radar.persistence")
    local state = require("radar.state")
    locks.lock_current_buffer(state.source_bufnr, config, persistence, mini_radar)
  end, vim.tbl_extend("force", opts, { desc = "Lock source buffer" }))

  -- Lock keymaps (1-9) - all split variants
  for _, label in ipairs(config.keys.locks) do
    register_split_variants(bufnr, label, function(cmd)
      navigation.open_lock(label, cmd, config, mini_radar)
    end, "Open lock " .. label, config)
  end

  -- Alternative file - all split variants
  register_split_variants(bufnr, config.keys.alternative, function(cmd)
    navigation.open_alternative(cmd, config, mini_radar)
  end, "Open alternative file", config)

  -- Recent file keymaps (a-g) - all split variants
  for _, label in ipairs(config.keys.recent) do
    register_split_variants(bufnr, label, function(cmd)
      navigation.open_recent(label, cmd, config, mini_radar)
    end, "Open recent file " .. label, config)
  end

  -- Edit locks
  vim.keymap.set("n", "e", function()
    require("radar.ui.edit").edit_locks(config, mini_radar)
  end, vim.tbl_extend("force", opts, { desc = "Edit radar locks" }))
end

return M
