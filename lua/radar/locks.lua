local M = {}

---Get next unused lock label
---@param config Radar.Config
---@return string
function M.get_next_unused_label(config)
  local state = require("radar.state")
  local used_labels = {}
  for _, lock in ipairs(state.locks) do
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

  local state = require("radar.state")
  table.insert(state.locks, lock)
  return lock
end

---Remove lock by filename
---@param filename string
---@return Radar.Lock
function M.remove(filename)
  ---@type Radar.Lock
  local removed_lock

  local state = require("radar.state")
  for i, lock in ipairs(state.locks) do
    if lock.filename == filename then
      removed_lock = lock
      table.remove(state.locks, i)
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
  local state = require("radar.state")
  local exists = state.get_lock_by_field("filename", filename)

  local lock

  if not exists then
    lock = M.add(filename, config)
  else
    lock = M.remove(filename)
  end

  vim.defer_fn(function()
    persistence_module.persist(config)
  end, config.persist.defer_ms)

  return lock
end

---Lock current buffer
---@param buf_nr? integer
---@param config Radar.Config
---@param persistence_module table
---@param mini_radar_module table
---@return nil
function M.lock_current_buffer(buf_nr, config, persistence_module, mini_radar_module)
  buf_nr = buf_nr or vim.api.nvim_get_current_buf()

  -- Don't lock non-file buffers (like the radar window itself)
  local buftype = vim.api.nvim_get_option_value("buftype", { buf = buf_nr })
  if buftype ~= "" then
    return
  end

  local filename = vim.api.nvim_buf_get_name(buf_nr)

  -- Don't lock empty or unnamed buffers
  if filename == "" then
    return
  end

  -- Normalize filename to match the format used in UI (relative to cwd)
  local normalized_filename =
    vim.fn.fnamemodify(filename, config.appearance.path_format)

  M.toggle(normalized_filename, config, persistence_module)

  if not mini_radar_module.exists() then
    mini_radar_module.create(config)
  else
    mini_radar_module.update(config)
  end
end

return M
