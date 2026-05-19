---@module "radar.debug"
--
-- Debug utilities for radar.nvim
--
-- All logging is gated behind `config.debug`. When disabled, all functions
-- are no-ops so zero overhead in production use.
--
-- Uses a buffered logging pattern: log() accumulates messages, flush()
-- outputs them as a single group. This keeps related debug output cohesive.

local M = {}

local is_enabled = false
---@type string[]
local buffer = {}

---Initialize from config (called in setup chain)
---@param config Radar.Config
function M.setup(config)
  is_enabled = config and config.debug or false
end

---Buffer a debug message (no-op when debug is off).
---Messages are flushed as a group on the next flush() call.
---@param ... string  Values joined with space, similar to print()
function M.log(...)
  if not is_enabled then
    return
  end
  local parts = {}
  for _, v in ipairs({ ... }) do
    parts[#parts + 1] = tostring(v)
  end
  buffer[#buffer + 1] = "[radar] " .. table.concat(parts, " ")
end

---Log an info message (no-op when debug is off)
---@param format string
---@param ... any
function M.info(format, ...)
  if not is_enabled then
    return
  end
  vim.notify(string.format("[radar] " .. format, ...), vim.log.levels.INFO)
end

---Log a warning (no-op when debug is off)
---@param msg string
function M.warn(msg)
  if not is_enabled then
    return
  end
  vim.notify(msg, vim.log.levels.WARN)
end

---Pretty-print a Lua value (no-op when debug is off)
---@param obj any
---@param opts? { depth?: integer, label?: string }
function M.dump(obj, opts)
  if not is_enabled then
    return ""
  end

  local depth = (opts and opts.depth) or 3
  local label = opts and opts.label

  if label then
    buffer[#buffer + 1] = "[radar] " .. label
  end

  buffer[#buffer + 1] = vim.inspect(obj, { depth = depth })
end

---Return whether debug mode is active
---@return boolean
function M.is_active()
  return is_enabled
end

---Flush all buffered debug messages as a single notification.
---Does nothing when debug is disabled or buffer is empty.
---@return nil
function M.flush()
  if not is_enabled or #buffer == 0 then
    return
  end
  vim.notify(table.concat(buffer, "\n"), vim.log.levels.DEBUG)
  buffer = {}
end

return M
