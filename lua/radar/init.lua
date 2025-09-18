local M = {}

M.config = require("radar.config").default

---Setup function called by lazy.nvim or manual setup
---@param opts? Radar.Config
---@return nil
function M.setup(opts)
  opts = opts or {}
  M.config = vim.tbl_deep_extend("force", M.config, opts)

  require("radar.autocmd").setup(M.config)
  require("radar.keys").setup(M.config)
  require("radar.persistence").populate(M.config, require("radar.ui.mini_radar"))
end

return M
