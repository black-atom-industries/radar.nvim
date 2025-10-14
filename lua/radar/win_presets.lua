local M = {}

---Get preset function by mode name
---@param mode Radar.Config.Mode
---@return fun(config: Radar.Config, overrides: vim.api.keyset.win_config): vim.api.keyset.win_config
function M.get(mode)
  if not M[mode] then
    vim.notify(
      string.format(
        "radar.nvim: Invalid mode '%s', falling back to default: 'float_top_right'",
        mode
      ),
      vim.log.levels.ERROR
    )

    return M.float_top_right
  end

  return M[mode]
end

-- The height property of `overrides` must always be set!
---@param config Radar.Config
---@param overrides {height: integer}
---@return vim.api.keyset.win_config
function M.float_top_right(config, overrides)
  config = config or require("radar.config").default
  vim.validate("overrides", overrides, "table")
  ---@diagnostic disable-next-line: undefined-field
  vim.validate("overrides.height", overrides.height, "number")

  -- Use config as source of truth, only override title and height dynamically
  local win_config = vim.tbl_deep_extend("force", config.windows.float.radar.config, {
    title = config.appearance.titles.main,
    height = overrides.height,
  })

  return win_config
end

return M
