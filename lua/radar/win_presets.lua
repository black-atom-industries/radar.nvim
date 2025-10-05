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
---@param overrides vim.api.keyset.win_config
---@return vim.api.keyset.win_config
function M.float_top_right(config, overrides)
  config = config or require("radar.config").default
  vim.validate("overrides", overrides, "table")
  vim.validate("overrides.height", overrides.height, "number")

  return vim.tbl_deep_extend("force", {
    relative = "editor",
    anchor = "NW",
    row = 1,
    col = math.floor((vim.o.columns - 50) - 2),

    width = 50,
    height = overrides.height, -- Gets dynamically set from outside

    border = "solid",
    style = "minimal",
    title = config.appearance.titles.main,
    title_pos = "left",

    focusable = false,
    zindex = 10,
  }, overrides)
end

return M
