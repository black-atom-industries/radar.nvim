local state = require("radar.state")

local M = {}

---Get next unused lock label
---@param radar_config table
---@return string
function M.get_next_unused_label(radar_config)
  local used_labels = {}
  for _, lock in ipairs(state.locks) do
    table.insert(used_labels, lock.label)
  end

  for _, label in ipairs(radar_config.keys.locks) do
    if not vim.tbl_contains(used_labels, label) then
      return label
    end
  end

  error("No more lock slots available")
end

---Add a lock for the given filename
---@param filename string
---@param radar_config table
---@returns Radar.Lock
function M.add(filename, radar_config)
  local next_free_lock_label = M.get_next_unused_label(radar_config)

  ---@type Radar.Lock
  local lock = {
    label = next_free_lock_label,
    filename = filename,
  }

  table.insert(state.locks, lock)
  return lock
end

---Remove lock by filename
---@param filename string
---@return Radar.Lock
function M.remove(filename)
  ---@type Radar.Lock
  local removed_lock

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
---@param radar_config table
---@param persistence_module table
---@param mini_radar_module table
---@return Radar.Lock
function M.toggle(filename, radar_config, persistence_module, mini_radar_module)
  local exists = state.get_lock_from_filename(filename)

  local lock

  if not exists then
    lock = M.add(filename, radar_config)
  else
    lock = M.remove(filename)
  end

  vim.defer_fn(function()
    persistence_module.persist(radar_config)
  end, radar_config.behavior.defer_persist_ms)

  return lock
end

---Lock current buffer
---@param buf_nr? integer
---@param radar_config table
---@param persistence_module table
---@param mini_radar_module table
---@return nil
function M.lock_current_buffer(
  buf_nr,
  radar_config,
  persistence_module,
  mini_radar_module
)
  buf_nr = buf_nr or vim.api.nvim_get_current_buf()
  local filename = vim.api.nvim_buf_get_name(buf_nr)
  M.toggle(filename, radar_config, persistence_module, mini_radar_module)

  if not mini_radar_module.exists() then
    mini_radar_module.create(radar_config)
  else
    mini_radar_module.update(radar_config)
  end
end

return M
