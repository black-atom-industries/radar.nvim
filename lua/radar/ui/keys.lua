local M = {}

---Read one key after the prefix and run its action
---@param config Radar.Config
---@return nil
local function dispatch(config)
  local ok, char = pcall(vim.fn.getcharstr)
  if not ok then
    return
  end

  local radar = require("radar.ui.radar")
  local navigation = require("radar.ui.navigation")
  local function is(key)
    return char == vim.keycode(key)
  end

  if is(config.keys.prefix) then
    radar.toggle(config)
  elseif is("<Tab>") then
    local alt_file = require("radar.data.alternative").get_alternative_file()
    navigation.open_file(alt_file, nil, config, radar)
  elseif is(config.keys.lock) then
    require("radar.data.locks").lock_current_buffer(
      nil,
      config,
      require("radar.persist.persistence"),
      radar
    )
  elseif is(config.keys.hud_toggle) then
    require("radar.ui.hud").toggle()
  else
    for _, label in ipairs(config.keys.locks) do
      if is(label) then
        return navigation.open_lock(label, nil, config, radar)
      end
    end
    for _, label in ipairs(config.keys.recent) do
      if is(label) then
        require("radar.data.recent").update_state(config)
        return navigation.open_recent(label, nil, config, radar)
      end
    end
  end
end

---Setup global keymaps
---@param config Radar.Config
---@return nil
function M.setup(config)
  vim.keymap.set("n", config.keys.prefix, function()
    dispatch(config)
  end, { desc = "Radar" })

  -- Tabs sidebar toggle
  vim.keymap.set("n", config.keys.tabs_toggle, function()
    require("radar.ui.tabs").toggle(config)
  end, { desc = "Toggle Tabs Sidebar" })
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

  vim.keymap.set("n", config.keys.prefix, function()
    radar.close()
  end, vim.tbl_extend("force", opts, { desc = "Close Radar" }))

  -- Tab cycling
  vim.keymap.set("n", "<Tab>", function()
    radar.cycle_focus_next()
  end, vim.tbl_extend("force", opts, { desc = "Cycle to next section" }))

  vim.keymap.set("n", "<S-Tab>", function()
    radar.cycle_focus_prev()
  end, vim.tbl_extend("force", opts, { desc = "Cycle to previous section" }))

  -- Lock/unlock file under cursor
  vim.keymap.set("n", config.keys.lock, function()
    local navigation = require("radar.ui.navigation")
    local locks = require("radar.data.locks")
    local persistence = require("radar.persist.persistence")

    if persistence.populate_if_changed(config) then
      return
    end

    local section = radar.get_focused_section_from_cursor()
    if not section then
      return
    end

    local filepath = navigation.get_file_from_line(section)
    if not filepath then
      return
    end

    locks.toggle(require("radar.path").to_lock_path(filepath), config, persistence)

    if not radar.exists() then
      radar.create(config)
    else
      radar.update(config)
    end
  end, vim.tbl_extend(
    "force",
    opts,
    { desc = "Toggle lock for file under cursor" }
  ))

  -- Open tabs sidebar (closes radar)
  vim.keymap.set("n", "t", function()
    radar.close()
    require("radar.ui.tabs").open(config)
  end, vim.tbl_extend("force", opts, { desc = "Open Tabs Sidebar" }))

  -- Alternative file
  register_split_variants(bufnr, config.keys.alternative, function(cmd)
    local navigation = require("radar.ui.navigation")
    navigation.open_alternative(cmd, config, radar)
  end, "Open alternative file", config)

  -- Edit locks
  vim.keymap.set("n", "e", function()
    require("radar.ui.edit").edit_locks(config, radar)
  end, vim.tbl_extend("force", opts, { desc = "Edit radar locks" }))

  -- Help
  vim.keymap.set("n", "?", function()
    radar.toggle_help(config)
  end, vim.tbl_extend("force", opts, { desc = "Toggle radar help" }))
end

---Setup all keymaps on a single buffer (unified window)
---@param bufnr integer
---@param config Radar.Config
---@return nil
function M.setup_all_keymaps(bufnr, config)
  local navigation = require("radar.ui.navigation")
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

  -- Recent file keymaps (a-g)
  for _, label in ipairs(config.keys.recent) do
    register_split_variants(bufnr, label, function(cmd)
      navigation.open_recent(label, cmd, config, radar)
    end, "Open recent file " .. label, config)
  end

  -- Line-based navigation — use cursor position to determine section
  register_split_variants(bufnr, config.keys.line.open, function(cmd)
    local section = radar.get_focused_section_from_cursor() or "locks"
    navigation.open_file_from_line(cmd, config, radar, section)
  end, "Open file from line", config)

  -- Additional line keys (V, S, T, F)
  vim.keymap.set("n", config.keys.line.vertical, function()
    local section = radar.get_focused_section_from_cursor() or "locks"
    navigation.open_file_from_line("vsplit", config, radar, section)
  end, vim.tbl_extend("force", opts, { desc = "Open file in vertical split" }))

  vim.keymap.set("n", config.keys.line.horizontal, function()
    local section = radar.get_focused_section_from_cursor() or "locks"
    navigation.open_file_from_line("split", config, radar, section)
  end, vim.tbl_extend("force", opts, { desc = "Open file in horizontal split" }))

  vim.keymap.set("n", config.keys.line.tab, function()
    local section = radar.get_focused_section_from_cursor() or "locks"
    navigation.open_file_from_line("tabedit", config, radar, section)
  end, vim.tbl_extend("force", opts, { desc = "Open file in new tab" }))

  vim.keymap.set("n", config.keys.line.float, function()
    local section = radar.get_focused_section_from_cursor() or "locks"
    navigation.open_file_from_line("float", config, radar, section)
  end, vim.tbl_extend("force", opts, { desc = "Open file in floating window" }))
end

return M
