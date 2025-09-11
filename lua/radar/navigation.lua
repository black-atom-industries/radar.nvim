local state = require("radar.state")

local M = {}

---Open a file with the given command, ensuring radar exists
---@param filepath string? File path to open
---@param open_cmd? string Command to open file (edit, vsplit, split, tabedit)
---@param radar_config table
---@param mini_radar_module table
---@return nil
function M.open_file(filepath, open_cmd, radar_config, mini_radar_module)
  if not filepath then
    return
  end

  mini_radar_module.ensure_exists(radar_config)

  local path = vim.fn.fnameescape(filepath)
  open_cmd = open_cmd or "edit"

  vim.cmd(open_cmd .. " " .. path)
end

---Open lock by label
---@param label string
---@param open_cmd? string Command to open file (edit, vsplit, split, tabedit)
---@param radar_config table
---@param mini_radar_module table
---@return nil
function M.open_lock(label, open_cmd, radar_config, mini_radar_module)
  local lock = state.get_lock_from_label(tostring(label))
  if lock then
    M.open_file(lock.filename, open_cmd, radar_config, mini_radar_module)
  end
end

---Open recent file by label
---@param label string
---@param open_cmd? string Command to open file (edit, vsplit, split, tabedit)
---@param radar_config table
---@param mini_radar_module table
---@return nil
function M.open_recent(label, open_cmd, radar_config, mini_radar_module)
  -- Find the recent file by label
  for i, recent_label in ipairs(radar_config.keys.recent) do
    if recent_label == label and state.recent_files[i] then
      M.open_file(state.recent_files[i], open_cmd, radar_config, mini_radar_module)
      return
    end
  end
end

---Register keymaps for a collection of file labels
---@param labels string[] Array of labels
---@param open_fn function Function to open files by label
---@param desc_prefix string Description prefix for keymap descriptions
---@param radar_config table
---@param mini_radar_module table
---@return nil
function M.register_file_keymaps(
  labels,
  open_fn,
  desc_prefix,
  radar_config,
  mini_radar_module
)
  for _, label in ipairs(labels) do
    local prefix = radar_config.keys.prefix

    -- Regular open
    vim.keymap.set("n", prefix .. label, function()
      open_fn(label, nil, radar_config, mini_radar_module)
    end, { desc = "Open " .. label .. " " .. desc_prefix })

    -- Vertical split
    vim.keymap.set("n", prefix .. radar_config.keys.vertical .. label, function()
      open_fn(label, "vsplit", radar_config, mini_radar_module)
    end, { desc = "Open " .. label .. " " .. desc_prefix .. " in vertical split" })

    -- Horizontal split
    vim.keymap.set("n", prefix .. radar_config.keys.horizontal .. label, function()
      open_fn(label, "split", radar_config, mini_radar_module)
    end, {
      desc = "Open " .. label .. " " .. desc_prefix .. " in horizontal split",
    })

    -- New tab
    vim.keymap.set("n", prefix .. radar_config.keys.tab .. label, function()
      open_fn(label, "tabedit", radar_config, mini_radar_module)
    end, { desc = "Open " .. label .. " " .. desc_prefix .. " in new tab" })
  end
end

return M
