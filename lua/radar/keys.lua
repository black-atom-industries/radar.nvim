local M = {}

---Setup global keymaps (only toggle)
---@param config Radar.Config
---@return nil
function M.setup(config)
  local radar = require("radar.ui.radar")

  -- Global toggle keymap (prefix becomes toggle)
  vim.keymap.set("n", config.keys.prefix, function()
    radar.toggle(config)
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

---Setup common keymaps shared by all sections
---@param bufnr integer
---@param config Radar.Config
---@param radar table
---@param opts table
---@return nil
function M.setup_common_keymaps(bufnr, config, radar, opts)
  -- Close radar
  vim.keymap.set("n", "q", function()
    radar.close()
  end, vim.tbl_extend("force", opts, { desc = "Close Radar" }))

  vim.keymap.set("n", "<Esc>", function()
    radar.close()
  end, vim.tbl_extend("force", opts, { desc = "Close Radar" }))

  -- Tab cycling
  vim.keymap.set("n", "<Tab>", function()
    radar.cycle_focus_next()
  end, vim.tbl_extend("force", opts, { desc = "Cycle to next section" }))

  vim.keymap.set("n", "<S-Tab>", function()
    radar.cycle_focus_prev()
  end, vim.tbl_extend("force", opts, { desc = "Cycle to previous section" }))

  -- Lock current buffer
  vim.keymap.set("n", config.keys.lock, function()
    local locks = require("radar.locks")
    local persistence = require("radar.persistence")
    local state = require("radar.state")
    locks.lock_current_buffer(state.source_bufnr, config, persistence, radar)
  end, vim.tbl_extend("force", opts, { desc = "Lock source buffer" }))

  -- Alternative file
  register_split_variants(bufnr, config.keys.alternative, function(cmd)
    local navigation = require("radar.navigation")
    navigation.open_alternative(cmd, config, radar)
  end, "Open alternative file", config)

  -- Edit locks
  vim.keymap.set("n", "e", function()
    require("radar.ui.edit").edit_locks(config, radar)
  end, vim.tbl_extend("force", opts, { desc = "Edit radar locks" }))
end

---Setup keymaps for locks section
---@param bufnr integer
---@param config Radar.Config
---@return nil
function M.setup_locks_keymaps(bufnr, config)
  local navigation = require("radar.navigation")
  local radar = require("radar.ui.radar")
  local opts = { buffer = bufnr, silent = true, noremap = true, nowait = true }

  -- Common keymaps
  M.setup_common_keymaps(bufnr, config, radar, opts)

  -- Lock-specific keymaps (1-9)
  for _, label in ipairs(config.keys.locks) do
    register_split_variants(bufnr, label, function(cmd)
      navigation.open_lock(label, cmd, config, radar)
    end, "Open lock " .. label, config)
  end

  -- Recent file keymaps (a-g) - cross-section access
  for _, label in ipairs(config.keys.recent) do
    register_split_variants(bufnr, label, function(cmd)
      navigation.open_recent(label, cmd, config, radar)
    end, "Open recent file " .. label, config)
  end

  -- Line-based navigation
  register_split_variants(bufnr, config.keys.line.open, function(cmd)
    navigation.open_file_from_line(cmd, config, radar, "locks")
  end, "Open file from line", config)

  -- Additional line keys (V, S, T, F)
  vim.keymap.set("n", config.keys.line.vertical, function()
    navigation.open_file_from_line("vsplit", config, radar, "locks")
  end, vim.tbl_extend("force", opts, { desc = "Open file in vertical split" }))

  vim.keymap.set("n", config.keys.line.horizontal, function()
    navigation.open_file_from_line("split", config, radar, "locks")
  end, vim.tbl_extend("force", opts, { desc = "Open file in horizontal split" }))

  vim.keymap.set("n", config.keys.line.tab, function()
    navigation.open_file_from_line("tabedit", config, radar, "locks")
  end, vim.tbl_extend("force", opts, { desc = "Open file in new tab" }))

  vim.keymap.set("n", config.keys.line.float, function()
    navigation.open_file_from_line("float", config, radar, "locks")
  end, vim.tbl_extend("force", opts, { desc = "Open file in floating window" }))
end

---Setup keymaps for recent section
---@param bufnr integer
---@param config Radar.Config
---@return nil
function M.setup_recent_keymaps(bufnr, config)
  local navigation = require("radar.navigation")
  local radar = require("radar.ui.radar")
  local opts = { buffer = bufnr, silent = true, noremap = true, nowait = true }

  -- Common keymaps
  M.setup_common_keymaps(bufnr, config, radar, opts)

  -- Lock keymaps (1-9) - cross-section access
  for _, label in ipairs(config.keys.locks) do
    register_split_variants(bufnr, label, function(cmd)
      navigation.open_lock(label, cmd, config, radar)
    end, "Open lock " .. label, config)
  end

  -- Recent-specific keymaps (a-g)
  for _, label in ipairs(config.keys.recent) do
    register_split_variants(bufnr, label, function(cmd)
      navigation.open_recent(label, cmd, config, radar)
    end, "Open recent file " .. label, config)
  end

  -- Line-based navigation
  register_split_variants(bufnr, config.keys.line.open, function(cmd)
    navigation.open_file_from_line(cmd, config, radar, "recent")
  end, "Open file from line", config)

  -- Additional line keys (V, S, T, F)
  vim.keymap.set("n", config.keys.line.vertical, function()
    navigation.open_file_from_line("vsplit", config, radar, "recent")
  end, vim.tbl_extend("force", opts, { desc = "Open file in vertical split" }))

  vim.keymap.set("n", config.keys.line.horizontal, function()
    navigation.open_file_from_line("split", config, radar, "recent")
  end, vim.tbl_extend("force", opts, { desc = "Open file in horizontal split" }))

  vim.keymap.set("n", config.keys.line.tab, function()
    navigation.open_file_from_line("tabedit", config, radar, "recent")
  end, vim.tbl_extend("force", opts, { desc = "Open file in new tab" }))

  vim.keymap.set("n", config.keys.line.float, function()
    navigation.open_file_from_line("float", config, radar, "recent")
  end, vim.tbl_extend("force", opts, { desc = "Open file in floating window" }))
end

return M
