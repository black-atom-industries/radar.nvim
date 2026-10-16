local M = {}

---Label range like "1-9"
---@param labels string[]
---@return string
function M.range(labels)
  return #labels > 1 and (labels[1] .. "-" .. labels[#labels]) or labels[1] or ""
end

---Help section for the keys read after the prefix
---@param config Radar.Config
---@return Radar.HelpSection
function M.prefix_help_section(config)
  local keys = config.keys
  return {
    title = "After " .. keys.prefix,
    rows = {
      { M.range(keys.locks), "Jump to lock" },
      { M.range(keys.recent), "Jump to recent" },
      { keys.alternative, "Alternative file" },
      { keys.lock, "Lock/unlock buffer" },
      { keys.edit, "Edit locks" },
      { keys.hud_toggle, "Toggle Lock HUD" },
      { keys.tabs, "Tab HUD" },
      { keys.help, "Show help" },
      { "<Esc>", "Cancel" },
    },
  }
end

---Read one key after the prefix and run its action
---@param config Radar.Config
---@return nil
local function dispatch(config)
  local ok, char = pcall(vim.fn.getcharstr)
  if not ok then
    return
  end

  local navigation = require("radar.ui.navigation")
  local function is(key)
    return char == vim.keycode(key)
  end

  if is(config.keys.alternative) then
    local alt_file = require("radar.data.alternative").get_alternative_file()
    navigation.open_file(alt_file, nil, config)
  elseif is(config.keys.lock) then
    require("radar.data.locks").lock_current_buffer(
      nil,
      config,
      require("radar.persist.persistence")
    )
  elseif is(config.keys.edit) then
    require("radar.ui.edit").edit_locks(config)
  elseif is(config.keys.hud_toggle) then
    require("radar.ui.hud").toggle()
  elseif is(config.keys.tabs) then
    require("radar.ui.tabs").toggle(config)
  elseif is(config.keys.help) then
    local help = require("radar.ui.help")
    help.show({
      parent_winid = vim.api.nvim_get_current_win(),
      title = "  RADAR HELP  ",
      lines = help.format({ M.prefix_help_section(config) }),
    })
  else
    for _, label in ipairs(config.keys.locks) do
      if is(label) then
        return navigation.open_lock(label, config)
      end
    end
    for _, label in ipairs(config.keys.recent) do
      if is(label) then
        require("radar.data.recent").update_state(config)
        return navigation.open_recent(label, config)
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

  -- Tab HUD toggle
  vim.keymap.set("n", config.keys.tabs_toggle, function()
    require("radar.ui.tabs").toggle(config)
  end, { desc = "Toggle Tab HUD" })
end

return M
