local M = {}

---Base window presets (not user-configurable)
---@type table<string, fun(config: Radar.Config): vim.api.keyset.win_config>
local BASE_PRESETS = {
  cursor = function(config)
    return {
      relative = "cursor",
      anchor = "NW",
      width = 75,
      height = 10,
      row = 1,
      col = 0,
      border = "single",
      style = "minimal",
      title = config.radar.titles.main,
      title_pos = "left",
      focusable = true,
      zindex = 100,
    }
  end,

  center = function(config)
    local width = 75
    local height = 10

    return {
      relative = "editor",
      anchor = "NW",
      width = width,
      height = height,
      row = math.floor((vim.o.lines - height) / 2),
      col = math.floor((vim.o.columns - width) / 2),
      border = "single",
      style = "minimal",
      title = config.radar.titles.main,
      title_pos = "center",
      focusable = true,
      zindex = 100,
    }
  end,

  center_large = function(config)
    local width = math.floor(vim.o.columns * 0.9)
    local height = math.floor(vim.o.lines * 0.8)

    return {
      relative = "editor",
      anchor = "NW",
      width = width,
      height = height,
      row = math.floor((vim.o.lines - height) / 2),
      col = math.floor((vim.o.columns - width) / 2),
      border = "single",
      style = "minimal",
      title = config.radar.titles.main,
      title_pos = "center",
      focusable = true,
      zindex = 50,
    }
  end,

  top_right = function(config)
    return {
      relative = "editor",
      anchor = "NE",
      width = 75,
      height = 10,
      row = 0,
      col = vim.o.columns,
      border = "single",
      style = "minimal",
      title = config.radar.titles.main,
      title_pos = "left",
      focusable = true,
      zindex = 100,
    }
  end,

  bottom_center = function(config)
    local width = 75
    local height = 10

    return {
      relative = "editor",
      anchor = "SW",
      width = width,
      height = height,
      row = vim.o.lines,
      col = math.floor((vim.o.columns - width) / 2),
      border = "single",
      style = "minimal",
      title = config.radar.titles.main,
      title_pos = "center",
      focusable = true,
      zindex = 100,
    }
  end,

  full_height_sidebar = function(config)
    return {
      relative = "editor",
      anchor = "NE",
      width = 75,
      height = vim.o.lines - 2,
      row = 0,
      col = vim.o.columns,
      border = "single",
      style = "minimal",
      title = config.radar.titles.main,
      title_pos = "left",
      focusable = true,
      zindex = 100,
    }
  end,
}

---Resolve window configuration from preset name
---@param config Radar.Config
---@param preset_name string
---@param runtime_opts? vim.api.keyset.win_config
---@return vim.api.keyset.win_config
function M.resolve_config(config, preset_name, runtime_opts)
  runtime_opts = runtime_opts or {}

  -- Check user presets first, then base presets
  local user_preset = config.win_presets[preset_name]
  local base_preset_fn = BASE_PRESETS[preset_name]

  -- If preset doesn't exist anywhere, fallback to center
  if not user_preset and not base_preset_fn then
    vim.notify(
      string.format("[Radar] Unknown window preset '%s'. Using center.", preset_name),
      vim.log.levels.WARN
    )
    base_preset_fn = BASE_PRESETS.center
  end

  -- If user provided a table override, merge with base
  if type(user_preset) == "table" then
    local base_config = base_preset_fn(config)
    return vim.tbl_deep_extend("force", base_config, user_preset, runtime_opts)
  end

  -- If user provided a function, they have full responsibility
  if type(user_preset) == "function" then
    local user_config = user_preset(config)
    return vim.tbl_deep_extend("force", user_config, runtime_opts)
  end

  -- No user override, use base preset
  local base_config = base_preset_fn(config)
  return vim.tbl_deep_extend("force", base_config, runtime_opts)
end

return M
