local M = {}

---Calculate optimal window width based on longest file path
---@param config Radar.Config
---@param mini_radar_module table
---@return integer
local function calculate_window_width(config, mini_radar_module)
  local max_width = 0

  local state = require("radar.state")
  -- Check locked files
  for _, lock in ipairs(state.locks) do
    local formatted_path =
      mini_radar_module.get_formatted_filepath(lock.filename, config)
    local entry_text = string.format("   [%s] %s  ", lock.label, formatted_path)
    max_width = math.max(max_width, vim.fn.strdisplaywidth(entry_text))
  end

  -- Ensure minimum width and add padding
  return math.max(max_width, config.windows.float.radar_window.config.width)
end

---Setup autocmds for edit buffer save and close handling
---@param edit_buf integer
---@param config Radar.Config
---@param mini_radar_module table
---@return nil
local function setup_edit_autocmds(edit_buf, config, mini_radar_module)
  local augroup = vim.api.nvim_create_augroup("radar.EditLocks", { clear = true })

  -- Handle buffer save (:w)
  vim.api.nvim_create_autocmd("BufWriteCmd", {
    group = augroup,
    buffer = edit_buf,
    callback = function()
      M.save_buffer(edit_buf, config, mini_radar_module)
    end,
  })

  -- Handle buffer close/unload
  vim.api.nvim_create_autocmd("BufUnload", {
    group = augroup,
    buffer = edit_buf,
    callback = function()
      M.cleanup()
    end,
  })
end

---Parse and save changes from edit buffer
---@param edit_buf integer
---@param config Radar.Config
---@param mini_radar_module table
---@return nil
function M.save_buffer(edit_buf, config, mini_radar_module)
  local lines = vim.api.nvim_buf_get_lines(edit_buf, 0, -1, false)
  local new_locks = {}
  local errors = {}

  for i, line in ipairs(lines) do
    -- Skip empty lines
    if line:match("^%s*$") then
      goto continue
    end

    -- Trim whitespace from filepath
    local filepath = line:match("^%s*(.-)%s*$")

    -- Validate filepath exists (expand to full path)
    local full_path = vim.fn.expand(filepath)
    if not vim.fn.filereadable(full_path) then
      table.insert(errors, string.format("Line %d: File not found: %s", i, filepath))
      goto continue
    end

    -- Create lock with label based on line position
    local new_lock = {
      label = config.keys.locks[i] or tostring(i),
      filename = full_path,
    }

    table.insert(new_locks, new_lock)

    ::continue::
  end

  -- Show errors if any
  if #errors > 0 then
    vim.notify("Edit errors:\n" .. table.concat(errors, "\n"), vim.log.levels.ERROR)
    return
  end

  -- Update locks and persist
  local state = require("radar.state")
  local persistence = require("radar.persistence")
  state.locks = new_locks
  persistence.persist(config)
  mini_radar_module.update(config)

  -- Mark buffer as saved
  vim.api.nvim_set_option_value("modified", false, { buf = edit_buf })
  vim.notify("Locks saved successfully", vim.log.levels.INFO)
end

---Open file from edit window line and cleanup
---@param edit_buf integer
---@param open_cmd string Command to open file (edit, vsplit, split, tabedit, float)
---@param config Radar.Config
---@param mini_radar_module table
---@return nil
function M.open_file_from_edit(edit_buf, open_cmd, config, mini_radar_module)
  local state = require("radar.state")
  local cursor = vim.api.nvim_win_get_cursor(state.edit_winid)
  local line_nr = cursor[1]
  local lines = vim.api.nvim_buf_get_lines(edit_buf, 0, -1, false)

  if line_nr > #lines then
    vim.notify("Invalid line", vim.log.levels.WARN)
    return
  end

  local line = lines[line_nr]

  -- Skip empty lines
  if line:match("^%s*$") then
    vim.notify("Empty line - no file to open", vim.log.levels.WARN)
    return
  end

  -- Save current state first
  M.save_buffer(edit_buf, config, mini_radar_module)

  -- Extract and expand filepath
  local filepath = line:match("^%s*(.-)%s*$")
  local full_path = vim.fn.expand(filepath)

  if not vim.fn.filereadable(full_path) then
    vim.notify(string.format("File not found: %s", filepath), vim.log.levels.ERROR)
    return
  end

  -- Clean up edit window
  M.cleanup()

  -- Open the file using navigation module
  local navigation = require("radar.navigation")
  navigation.open_file(full_path, open_cmd, config, mini_radar_module)
end

---Cleanup edit mode state
---@return nil
function M.cleanup()
  local state = require("radar.state")
  if state.edit_winid and vim.api.nvim_win_is_valid(state.edit_winid) then
    vim.api.nvim_win_close(state.edit_winid, true)
  end

  state.edit_winid = nil
  state.edit_bufid = nil
end

---Create editable buffer for managing locks
---@param config Radar.Config
---@param mini_radar_module table
---@return nil
function M.edit_locks(config, mini_radar_module)
  local state = require("radar.state")
  if #state.locks == 0 then
    vim.notify("No locks to edit", vim.log.levels.WARN)
    return
  end

  -- Create editable buffer
  local edit_buf = vim.api.nvim_create_buf(false, false)
  state.edit_bufid = edit_buf

  -- Set buffer options
  vim.api.nvim_set_option_value("buftype", "acwrite", { buf = edit_buf })
  vim.api.nvim_set_option_value("filetype", "radar-edit", { buf = edit_buf })
  vim.api.nvim_buf_set_name(edit_buf, "radar-locks")
  vim.api.nvim_set_option_value("bufhidden", "wipe", { buf = edit_buf })

  -- Create buffer lines: just the filepaths (labels assigned by line order)
  local lines = {}
  for _, lock in ipairs(state.locks) do
    local formatted_path =
      mini_radar_module.get_formatted_filepath(lock.filename, config)
    table.insert(lines, formatted_path)
  end

  vim.api.nvim_buf_set_lines(edit_buf, 0, -1, false, lines)

  -- Open floating window
  local calculated_width = calculate_window_width(config, mini_radar_module)
  local win_width = math.max(
    config.windows.float.edit_window.min_width,
    calculated_width + config.windows.float.edit_window.width_padding
  )
  local win_height =
    math.min(#lines + 2, config.windows.float.edit_window.max_height)
  local win_opts = {
    relative = "editor",
    width = win_width,
    height = win_height,
    row = math.floor((vim.o.lines - win_height) / 2),
    col = math.floor((vim.o.columns - win_width) / 2),
    style = "minimal",
    border = "solid",
    title = " Edit Locks ",
    title_pos = "center",
  }

  local edit_win = vim.api.nvim_open_win(edit_buf, true, win_opts)
  state.edit_winid = edit_win

  -- Set up buffer autocmds for save and close
  setup_edit_autocmds(edit_buf, config, mini_radar_module)

  -- Set up buffer-local keymaps
  vim.api.nvim_buf_set_keymap(edit_buf, "n", "q", "<cmd>w<bar>q<CR>", {
    noremap = true,
    silent = true,
    desc = "Save and quit radar edit buffer",
  })

  -- Navigation keymaps
  vim.api.nvim_buf_set_keymap(edit_buf, "n", "<CR>", "", {
    noremap = true,
    silent = true,
    desc = "Open file under cursor",
    callback = function()
      M.open_file_from_edit(edit_buf, "edit", config, mini_radar_module)
    end,
  })

  vim.api.nvim_buf_set_keymap(edit_buf, "n", "<C-v>", "", {
    noremap = true,
    silent = true,
    desc = "Open file in vertical split",
    callback = function()
      M.open_file_from_edit(edit_buf, "vsplit", config, mini_radar_module)
    end,
  })

  vim.api.nvim_buf_set_keymap(edit_buf, "n", "<C-s>", "", {
    noremap = true,
    silent = true,
    desc = "Open file in horizontal split",
    callback = function()
      M.open_file_from_edit(edit_buf, "split", config, mini_radar_module)
    end,
  })

  vim.api.nvim_buf_set_keymap(edit_buf, "n", "<C-t>", "", {
    noremap = true,
    silent = true,
    desc = "Open file in new tab",
    callback = function()
      M.open_file_from_edit(edit_buf, "tabedit", config, mini_radar_module)
    end,
  })

  vim.api.nvim_buf_set_keymap(edit_buf, "n", "<C-f>", "", {
    noremap = true,
    silent = true,
    desc = "Open file in floating window",
    callback = function()
      M.open_file_from_edit(edit_buf, "float", config, mini_radar_module)
    end,
  })
end

return M
