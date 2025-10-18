local M = {}

---Resolve window configuration from preset name or tuple-style config
---@param config_or_preset Radar.Config.WinPreset | { [1]: Radar.Config.WinPreset, [2]: vim.api.keyset.win_config }
---@param opts? vim.api.keyset.win_config
---@return vim.api.keyset.win_config
function M.resolve_config(config_or_preset, opts)
  opts = opts or {}

  -- If it's a string, treat it as a preset name
  if type(config_or_preset) == "string" then
    local presets = require("radar.win_presets")
    local preset_fn = presets[config_or_preset]

    if not preset_fn then
      vim.notify(
        string.format(
          "[Radar] Unknown window preset '%s'. Using center.",
          config_or_preset
        ),
        vim.log.levels.WARN
      )
      preset_fn = presets.center
    end

    return preset_fn(opts)
  end

  -- If it's a table, treat it as tuple-style: { "preset_name", { overrides } }
  if type(config_or_preset) == "table" and config_or_preset[1] then
    local presets = require("radar.win_presets")
    local preset_name = config_or_preset[1]
    local preset_fn = presets[preset_name]

    if not preset_fn then
      vim.notify(
        string.format(
          "[Radar] Unknown window preset '%s'. Using center.",
          preset_name
        ),
        vim.log.levels.WARN
      )
      preset_fn = presets.center
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
