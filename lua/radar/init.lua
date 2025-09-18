local config = require("radar.config")
local keys = require("radar.keys")
local autocmd = require("radar.autocmd")
local persistence = require("radar.persistence")
local mini_radar = require("radar.ui.mini_radar")

local M = {}

M.config = config.default

---Setup function called by lazy.nvim or manual setup
---@param opts? Radar.Config
---@return nil
function M.setup(opts)
  opts = opts or {}
  M.config = vim.tbl_deep_extend("force", M.config, opts)

  autocmd.setup(M.config)
  keys.setup(M.config)
  persistence.populate(M.config, mini_radar)
end

return M
