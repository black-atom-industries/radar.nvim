local M = {}

---Safely escape a string for pattern matching with fallback
---@param str string
---@return string
local function safe_escape_pattern(str)
  if not str or str == "" then
    return ""
  end
  local success, escaped = pcall(vim.pesc, str)
  if success then
    return escaped
  else
    -- Fallback: manually escape pattern characters
    return str:gsub("[%^%$%(%)%%%.%[%]%*%+%-%?]", "%%%1")
  end
end

---Progressively shorten a file path to fit within a maximum width
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

  -- Replace home directory with ~ (with safe pattern escaping)
  local home = vim.fn.expand("~")
  local display_path = path:gsub("^" .. safe_escape_pattern(home), "~")

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

  -- Progressive shortening: try different shortening levels until it fits
  local function try_build_path(min_chars)
    local result_parts = {}

    -- Always include filename as-is
    result_parts[#components] = filename

    -- Build directory parts with minimum character count
    for i = 1, #components - 1 do
      local component = components[i]

      if component == "" then
        -- Skip empty components (root slashes, etc.)
        result_parts[i] = ""
      elseif component == "~" then
        -- Home directory - keep as is
        result_parts[i] = "~"
      else
        -- Smart shortening based on min_chars
        if min_chars >= #component then
          -- Keep full component if it's short enough
          result_parts[i] = component
        else
          -- Shorten but keep meaningful prefix
          local shortened = component:sub(1, math.max(min_chars, 1))
          -- Special handling for dot files/directories
          if component:sub(1, 1) == "." and min_chars >= 2 then
            shortened = component:sub(1, math.min(min_chars, #component))
          end
          result_parts[i] = shortened
        end
      end
    end

    -- Join and clean up the path
    local result = table.concat(result_parts, "/")
    -- Clean up multiple slashes
    result = result:gsub("//+", "/")

    return result
  end

  -- Try different levels of shortening
  local shortening_levels = { 8, 6, 4, 3, 2, 1 }

  for _, min_chars in ipairs(shortening_levels) do
    local candidate = try_build_path(min_chars)
    if vim.fn.strdisplaywidth(candidate) <= available_width then
      return candidate
    end
  end

  -- Last resort: use ellipsis if even single characters don't fit
  local single_char_path = try_build_path(1)
  if vim.fn.strdisplaywidth(single_char_path) <= available_width then
    return single_char_path
  end

  -- If still too long, use ellipsis + filename
  local ellipsis_result = ".../" .. filename
  if vim.fn.strdisplaywidth(ellipsis_result) <= available_width then
    return ellipsis_result
  end

  -- Final fallback: truncate filename with ellipsis
  local max_filename_chars = available_width - 3 -- Reserve for "..."
  if max_filename_chars > 0 then
    return filename:sub(1, max_filename_chars) .. "..."
  else
    return filename:sub(1, available_width)
  end
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
