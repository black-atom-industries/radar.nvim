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

---Relabel locks by position from config.keys.locks
---@param locks Radar.Lock[]
---@param config Radar.Config
---@return nil
function M.relabel(locks, config)
  for i, lock in ipairs(locks) do
    lock.label = config.keys.locks[i] or tostring(i)
  end
end

---Remove lock by filename and relabel the remaining locks
---@param filename string
---@param config Radar.Config
---@return Radar.Lock
function M.remove(filename, config)
  ---@type Radar.Lock
  local removed_lock

  local state = require("radar.data.state")
  for i, lock in ipairs(state.get_locks()) do
    if lock.filename == filename then
      removed_lock = lock
      table.remove(state.get_locks(), i)
      M.relabel(state.get_locks(), config)
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
  local state = require("radar.data.state")
  local exists = state.get_lock_by_field("filename", filename)

  local lock
  if not exists then
    lock = M.add(filename, config)
  else
    lock = M.remove(filename, config)
  end

  local snapshot = require("radar.persist.persistence").snapshot()
  vim.defer_fn(function()
    persistence_module.persist(config, snapshot)
  end, config.persist.defer_ms)
  require("radar.ui.hud").refresh()

  return lock
end

---Toggle the lock of a buffer and re-render the radar, or open it when the
---HUD is disabled
---@param buf_nr? integer
---@param config Radar.Config
---@param persistence_module table
---@param radar_module table
---@return nil
function M.lock_current_buffer(buf_nr, config, persistence_module, radar_module)
  buf_nr = buf_nr or vim.api.nvim_get_current_buf()

  local filetype = vim.api.nvim_get_option_value("filetype", { buf = buf_nr })
  if filetype == "radar" or filetype == "radar-edit" then
    return
  end

  local buftype = vim.api.nvim_get_option_value("buftype", { buf = buf_nr })
  if buftype == "terminal" then
    return
  end

  local filename = vim.api.nvim_buf_get_name(buf_nr)
  if filename == "" then
    return
  end

  persistence_module.populate_if_changed(config)
  M.toggle(require("radar.path").to_lock_path(filename), config, persistence_module)

  if radar_module.exists() then
    radar_module.update(config)
  elseif not config.hud.enabled then
    radar_module.create(config)
  end
end

return M
