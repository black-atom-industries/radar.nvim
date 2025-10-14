local M = {}

---Get the alternative file if it exists and is valid
---@return string|nil absolute path to alternative file, or nil if not valid
function M.get_alternative_file()
  local alt_file = vim.fn.expand("#")

  -- Check if alternate file exists and is valid
  if alt_file == "" or alt_file == vim.fn.expand("%") then
    return nil
  end

  -- Check if file is readable
  if vim.fn.filereadable(alt_file) == 0 then
    return nil
  end

  return alt_file
end

return M
