---Debug logging for radar.nvim
---Logs to radar-debug.log in the project root (gitignored)
local M = {}

local log_file = vim.fn.getcwd() .. "/radar-debug.log"

local function format_value(v)
  local t = type(v)
  if t == "table" then
    return vim.inspect(v, { newline = "", indent = "" })
  elseif t == "string" then
    return v
  end
  return tostring(v)
end

-- Check if there's a pending flush
local pending = {}

---Queue a log message (batched to reduce file I/O)
---@param ... any
function M.log(...)
  local info = debug.getinfo(2, "Sl")
  local args = { ... }
  local parts = {}
  for _, v in ipairs(args) do
    table.insert(parts, format_value(v))
  end
  local msg = string.format(
    "[%s] %s:%d | %s",
    os.date("%H:%M:%S"),
    vim.fn.fnamemodify(info.short_src, ":t"),
    info.currentline,
    table.concat(parts, " ")
  )
  table.insert(pending, msg)
end

---Flush all queued messages to disk
function M.flush()
  if #pending == 0 then
    return
  end
  local file = io.open(log_file, "a")
  if not file then
    pending = {}
    return
  end
  for _, msg in ipairs(pending) do
    file:write(msg .. "\n")
  end
  file:close()
  pending = {}
end

---Clear the log file
function M.clear()
  vim.fn.writefile({}, log_file)
  pending = {}
end

return M
