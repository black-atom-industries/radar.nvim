local M = {}

---Get next unused lock label
---@param config Radar.Config
---@return string
function M.get_next_unused_label(config)
  local state = require("radar.data.state")
  local used_labels = {}
  for _, lock in ipairs(state.get_locks()) do
    table.insert(used_labels, lock.label)
  end

  for _, label in ipairs(config.keys.locks) do
    if not vim.tbl_contains(used_labels, label) then
      return label
    end
  end

  error("No more lock slots available")
end

---Add a lock for the given filename
---@param filename string
---@param config Radar.Config
---@returns Radar.Lock
function M.add(filename, config)
  local next_free_lock_label = M.get_next_unused_label(config)

  ---@type Radar.Lock
  local lock = {
    label = next_free_lock_label,
    filename = filename,
  }

  local state = require("radar.data.state")
  table.insert(state.get_locks(), lock)
  return lock
end

---Remove lock by filename
---@param filename string
---@return Radar.Lock
function M.remove(filename)
  ---@type Radar.Lock
  local removed_lock

  local state = require("radar.data.state")
  for i, lock in ipairs(state.get_locks()) do
    if lock.filename == filename then
      removed_lock = lock
      table.remove(state.get_locks(), i)
      break
    end
  end

  return removed_lock
end

---Toggle lock for given filename
---@param filename string
---@param config Radar.Config
---@param persistence_module table
---@return Radar.Lock
function M.toggle(filename, config, persistence_module)
  local debug = require("radar.debug")
  local state = require("radar.data.state")
  local exists = state.get_lock_by_field("filename", filename)

  debug.log("toggle(", filename, ")")
  debug.log("  exists =", exists)
  debug.log("  locks before =", #state.get_locks(), vim.inspect(state.get_locks()))

  local lock

  if not exists then
    lock = M.add(filename, config)
    debug.log("  action = ADD, label =", lock.label)
  else
    lock = M.remove(filename)
    debug.log("  action = REMOVE, removed =", lock)
  end

  debug.log("  locks after =", #state.get_locks(), vim.inspect(state.get_locks()))
  debug.log("  section_ranges =", state.get_section_line_ranges())

  vim.defer_fn(function()
    persistence_module.persist(config)
  end, config.persist.defer_ms)

  debug.flush()
  return lock
end

---Lock current buffer
---@param buf_nr? integer
---@param config Radar.Config
---@param persistence_module table
---@param radar_module table
---@return nil
function M.lock_current_buffer(buf_nr, config, persistence_module, radar_module)
  local debug = require("radar.debug")
  local state = require("radar.data.state")

  debug.log("=== lock_current_buffer ===")
  debug.log("  source_bufnr (passed) =", buf_nr)
  debug.log("  state.get_source_bufnr() =", state.get_source_bufnr())
  debug.log("  nvim_get_current_buf() =", vim.api.nvim_get_current_buf())
  debug.log(
    "  nvim_get_current_buf name =",
    vim.api.nvim_buf_get_name(vim.api.nvim_get_current_buf())
  )
  debug.log("  state.get_recent_files() =", state.get_recent_files())

  buf_nr = buf_nr or vim.api.nvim_get_current_buf()
  debug.log("  resolved buf_nr =", buf_nr)

  -- Don't lock radar-related buffers
  local filetype = vim.api.nvim_get_option_value("filetype", { buf = buf_nr })
  debug.log("  buf filetype =", filetype)
  if filetype == "radar" or filetype == "radar-edit" then
    debug.log("  EARLY RETURN: radar buffer")
    debug.flush()
    return
  end

  -- Don't lock terminal buffers
  local buftype = vim.api.nvim_get_option_value("buftype", { buf = buf_nr })
  if buftype == "terminal" then
    debug.log("  EARLY RETURN: terminal buffer")
    debug.flush()
    return
  end

  local filename = vim.api.nvim_buf_get_name(buf_nr)
  debug.log("  raw filename =", filename)

  -- Don't lock empty or unnamed buffers
  if filename == "" then
    debug.log("  EARLY RETURN: empty buffer")
    debug.flush()
    return
  end

  -- Keep protocol URLs as-is (gh://, fugitive://, etc.), normalize regular paths
  local normalized_filename = filename
  if not filename:match("^%w+://") then
    normalized_filename = vim.fn.fnamemodify(filename, ":p:.")
  end
  debug.log("  normalized filename =", normalized_filename)

  M.toggle(normalized_filename, config, persistence_module)

  if not radar_module.exists() then
    debug.log("  radar does not exist, calling create")
    radar_module.create(config)
  else
    debug.log("  radar exists, calling update")
    radar_module.update(config)
  end
  debug.flush()
end

return M
