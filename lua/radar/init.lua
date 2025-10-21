local M = {}

---Setup function called by lazy.nvim or manual setup
---@param opts? Radar.Config
---@return nil
function M.setup(opts)
  opts = opts or {}
  local config = vim.tbl_deep_extend("force", require("radar.config").default, opts)

  -- Setup git status highlights
  require("radar.git_status").setup_highlights()

  require("radar.autocmd").setup(config)
  require("radar.keys").setup(config)
  require("radar.persistence").populate(config, require("radar.ui.radar"))
end

return M
