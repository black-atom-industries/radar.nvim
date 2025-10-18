local M = {}

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

return M
