local M = {}

---Shorten a file path to fit within a maximum width
---@param path string The full file path to shorten
---@param max_width integer Maximum display width allowed
---@param label_width integer? Width taken by label (e.g., "[1] " = 4 chars), defaults to 0
---@return string The shortened path
function M.shorten_path(path, max_width, label_width)
  label_width = label_width or 0
  local available_width = max_width - label_width

  -- Return empty if path is nil or empty
  if not path or path == "" then
    return ""
  end

  -- Replace home directory with ~
  local home = vim.fn.expand("~")
  local display_path = path:gsub("^" .. vim.pesc(home), "~")

  -- If it fits, return as is
  if vim.fn.strdisplaywidth(display_path) <= available_width then
    return display_path
  end

  -- Split path into components
  local components = vim.split(display_path, "/", { plain = true })
  local filename = components[#components]

  -- If filename alone is too long, truncate it with ellipsis
  local filename_width = vim.fn.strdisplaywidth(filename)
  if filename_width > available_width then
    local keep_chars = math.max(available_width - 3, 1) -- Reserve 3 for "..."
    return filename:sub(1, keep_chars) .. "..."
  end

  -- Start with filename and work backwards adding components
  local result = filename
  local result_width = filename_width

  -- Try to add parent directories, shortened to single letters
  for i = #components - 1, 1, -1 do
    local component = components[i]

    -- Handle special cases
    if component == "" then
      -- Root or consecutive slashes
      goto continue
    elseif component == "~" then
      -- Home directory - keep as is
      local test_result = "~/" .. result
      local test_width = vim.fn.strdisplaywidth(test_result)
      if test_width <= available_width then
        result = test_result
        result_width = test_width
      else
        -- Add ellipsis if we can't fit home
        local ellipsis_result = ".../" .. result
        if vim.fn.strdisplaywidth(ellipsis_result) <= available_width then
          result = ellipsis_result
        else
          -- Even with ellipsis we can't fit, truncate filename but preserve extension
          local max_filename_chars = available_width - 3 -- Reserve for "..."
          if max_filename_chars > 0 then
            result = "..." .. filename:sub(1, max_filename_chars)
          else
            result = filename:sub(1, available_width)
          end
        end
        break
      end
    else
      -- Regular directory - shorten to first letter
      local shortened = component:sub(1, 1)
      local test_result = shortened .. "/" .. result
      local test_width = vim.fn.strdisplaywidth(test_result)

      if test_width <= available_width then
        result = test_result
        result_width = test_width
      else
        -- Can't fit more, add ellipsis
        local ellipsis_result = ".../" .. result
        if vim.fn.strdisplaywidth(ellipsis_result) <= available_width then
          result = ellipsis_result
        else
          -- Even with ellipsis we can't fit, truncate filename but preserve extension
          local max_filename_chars = available_width - 3 -- Reserve for "..."
          if max_filename_chars > 0 then
            result = "..." .. filename:sub(1, max_filename_chars)
          else
            result = filename:sub(1, available_width)
          end
        end
        break
      end
    end

    ::continue::
  end

  -- Add leading slash if path was absolute and we didn't include home
  if
    display_path:sub(1, 1) == "/"
    and result:sub(1, 1) ~= "/"
    and result:sub(1, 1) ~= "~"
  then
    if vim.fn.strdisplaywidth("/" .. result) <= available_width then
      result = "/" .. result
    end
  end

  return result
end

---Format a file path according to vim's path modifiers, then shorten if needed
---@param path string The file path to format
---@param format string? Vim path format modifier (e.g., ":p:.", ":~"), defaults to ":p:."
---@param max_width integer? Maximum width for display
---@param label_width integer? Width taken by label
---@return string The formatted and possibly shortened path
function M.format_and_shorten(path, format, max_width, label_width)
  format = format or ":p:."

  -- Apply vim's path formatting
  local formatted = vim.fn.fnamemodify(path, format)

  -- If max_width is specified, shorten the path
  if max_width then
    formatted = M.shorten_path(formatted, max_width, label_width)
  end

  return formatted
end

return M
