local M = {}

---Window presets

---@param opts? vim.api.keyset.win_config
---@return vim.api.keyset.win_config
M.cursor = function(opts)
  opts = opts or {}
  local config = require("radar.config")

  local height = opts.height or 10

  local base = {
    relative = "cursor",
    anchor = "NW",
    width = 75,
    height = height,
    row = 1,
    col = 0,
    border = "solid",
    style = "minimal",
    title = config.default.appearance.titles.main,
    title_pos = "left",
    focusable = true,
    zindex = 100,
  }

  return vim.tbl_deep_extend("force", base, opts)
end

---@param opts? vim.api.keyset.win_config
---@return vim.api.keyset.win_config
M.center = function(opts)
  opts = opts or {}
  local config = require("radar.config")

  local width = opts.width or 75
  local height = opts.height or 10

  local base = {
    relative = "editor",
    anchor = "NW",
    width = width,
    height = height,
    row = math.floor((vim.o.lines - height) / 2),
    col = math.floor((vim.o.columns - width) / 2),
    border = "solid",
    style = "minimal",
    title = config.default.appearance.titles.main,
    title_pos = "center",
    focusable = true,
    zindex = 100,
  }

  return vim.tbl_deep_extend("force", base, opts)
end

---@param opts? vim.api.keyset.win_config
---@return vim.api.keyset.win_config
M.top_right = function(opts)
  opts = opts or {}
  local config = require("radar.config")

  local height = opts.height or 10

  local base = {
    relative = "editor",
    anchor = "NE",
    width = 75,
    height = height,
    row = 0,
    col = vim.o.columns,
    border = "solid",
    style = "minimal",
    title = config.default.appearance.titles.main,
    title_pos = "left",
    focusable = true,
    zindex = 100,
  }

  return vim.tbl_deep_extend("force", base, opts)
end

---@param opts? vim.api.keyset.win_config
---@return vim.api.keyset.win_config
M.bottom_center = function(opts)
  opts = opts or {}
  local config = require("radar.config")
  local width = 75

  local height = opts.height or 10

  local base = {
    relative = "editor",
    anchor = "SW",
    width = width,
    height = height,
    row = vim.o.lines,
    col = math.floor((vim.o.columns - width) / 2),
    border = "solid",
    style = "minimal",
    title = config.default.appearance.titles.main,
    title_pos = "center",
    focusable = true,
    zindex = 100,
  }

  return vim.tbl_deep_extend("force", base, opts)
end

---@param opts? vim.api.keyset.win_config
---@return vim.api.keyset.win_config
M.full_height_sidebar = function(opts)
  opts = opts or {}
  local config = require("radar.config")

  -- Always use full height for this preset (ignore opts.height)
  local base = {
    relative = "editor",
    anchor = "NE",
    width = 75,
    height = vim.o.lines - 2,
    row = 0,
    col = vim.o.columns,
    border = "solid",
    style = "minimal",
    title = config.default.appearance.titles.main,
    title_pos = "left",
    focusable = true,
    zindex = 100,
  }

  -- Merge opts but preserve our full height
  local opts_without_height = vim.deepcopy(opts)
  opts_without_height.height = nil

  return vim.tbl_deep_extend("force", base, opts_without_height)
end

---Resolve window configuration from preset name or tuple-style config
---@param config_or_preset Radar.Config.WinPreset | { [1]: Radar.Config.WinPreset, [2]: vim.api.keyset.win_config }
---@param opts? vim.api.keyset.win_config
---@return vim.api.keyset.win_config
function M.resolve_config(config_or_preset, opts)
  opts = opts or {}

  -- If it's a string, treat it as a preset name
  if type(config_or_preset) == "string" then
    local preset_fn = M[config_or_preset]

    if not preset_fn then
      vim.notify(
        string.format(
          "[Radar] Unknown window preset '%s'. Using center.",
          config_or_preset
        ),
        vim.log.levels.WARN
      )
      preset_fn = M.center
    end

    return preset_fn(opts)
  end

  -- If it's a table, treat it as tuple-style: { "preset_name", { overrides } }
  if type(config_or_preset) == "table" and config_or_preset[1] then
    local preset_name = config_or_preset[1]
    local preset_fn = M[preset_name]

    if not preset_fn then
      vim.notify(
        string.format(
          "[Radar] Unknown window preset '%s'. Using center.",
          preset_name
        ),
        vim.log.levels.WARN
      )
      preset_fn = M.center
    end

    -- Get overrides from [2] if present
    local overrides = config_or_preset[2] or {}

    -- Merge opts and overrides
    local combined_opts = vim.tbl_deep_extend("force", opts, overrides)

    return preset_fn(combined_opts)
  end

  error(
    "[Radar] Invalid window config. Must be a preset name or tuple { preset, overrides }."
  )
end

return M
