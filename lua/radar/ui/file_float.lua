---File float viewer module.
---Opens a file in a floating window with save-close behavior (`q` to save and close).
---Fire-and-forget pattern — no internal state tracking.
local M = {}

---Open a file in a floating window with save-close behavior
---@param filepath string Path to the file to open
---@param config Radar.Config Plugin configuration
---@return integer winid The window ID of the created float
function M.open(filepath, config)
  -- Resolve window config from preset
  local window = require("radar.window")
  local win_opts = window.resolve_config(config, config.file_float.win_preset, {
    title = " " .. vim.fn.fnamemodify(filepath, ":.") .. " ",
  })

  -- Create scratch buffer initially
  local buf = vim.api.nvim_create_buf(false, true)
  local win = vim.api.nvim_open_win(buf, true, win_opts)

  -- Apply window-local options
  for opt, value in pairs(config.file_float.win_opts) do
    vim.api.nvim_set_option_value(opt, value, { win = win })
  end

  -- Now edit the file in the floating window (this triggers all autocmds, treesitter, etc.)
  local path = vim.fn.fnameescape(filepath)
  ---@diagnostic disable-next-line: undefined-field
  vim.cmd.edit(path)

  -- Get the actual buffer after editing
  buf = vim.api.nvim_win_get_buf(win)

  -- Add keymap to save and close the floating window
  vim.api.nvim_buf_set_keymap(buf, "n", "q", "", {
    noremap = true,
    silent = true,
    desc = "Save and close floating window",
    callback = function()
      -- Save file if modified
      local current_buf = vim.api.nvim_win_get_buf(win)
      if
        vim.api.nvim_buf_is_valid(current_buf)
        and vim.api.nvim_get_option_value("modified", { buf = current_buf })
      then
        vim.cmd("write")
      end
      -- Close the window
      if vim.api.nvim_win_is_valid(win) then
        vim.api.nvim_win_close(win, false)
      end
    end,
  })

  return win
end

return M
