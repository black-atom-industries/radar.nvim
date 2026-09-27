local M = {}

---Convert an Oil buffer name to its filesystem path
---@param filename string
---@return string
function M.to_filesystem_path(filename)
  if filename:match("^oil://") then
    return filename:sub(#"oil://" + 1)
  end

  return filename
end

---Check whether a buffer name is an Oil URL
---@param filename string
---@return boolean
function M.is_oil_url(filename)
  return filename:match("^oil://") ~= nil
end

return M
