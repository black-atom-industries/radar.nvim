local M = {}

---Setup function called by lazy.nvim or manual setup
---@param opts? Radar.Config
---@return nil
function M.setup(opts)
  opts = opts or {}
  local config = vim.tbl_deep_extend("force", require("radar.config").default, opts)

  require("radar.autocmd").setup(config)
  require("radar.keys").setup(config)
  require("radar.persistence").populate(config, require("radar.ui.mini_radar"))
end

return M
