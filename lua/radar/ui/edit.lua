local M = {}
local path = require("radar.path")

---Setup autocmds for edit buffer save and close handling
---@param edit_buf integer
---@param radar_config Radar.Config
---@param radar_module table?
---@return nil
local function setup_edit_autocmds(edit_buf, radar_config, radar_module)
  local augroup = vim.api.nvim_create_augroup("radar.EditLocks", { clear = true })

  -- Handle buffer save (:w)
  vim.api.nvim_create_autocmd("BufWriteCmd", {
    group = augroup,
    buffer = edit_buf,
    callback = function()
      M.save_buffer(edit_buf, radar_config, radar_module)
    end,
  })

  -- Handle buffer close/unload; deferred because floats (the HUD) cannot
  -- open while a buffer is closing
  vim.api.nvim_create_autocmd("BufUnload", {
    group = augroup,
    buffer = edit_buf,
    callback = function()
      vim.schedule(M.cleanup)
    end,
  })
end

---Parse and save changes from edit buffer
---@param edit_buf integer
---@param radar_config Radar.Config
---@param radar_module table? radar to re-render after saving
---@return nil
function M.save_buffer(edit_buf, radar_config, radar_module)
  local lines = vim.api.nvim_buf_get_lines(edit_buf, 0, -1, false)
  local new_locks = {}
  local errors = {}

  for i, line in ipairs(lines) do
    -- Skip empty lines
    if not line:match("^%s*$") then
      -- Trim whitespace from filepath
      local filepath = line:match("^%s*(.-)%s*$")

      local full_path = path.is_url(filepath) and filepath
        or path.to_absolute(filepath)

      -- Protocol URLs (gh://, fugitive://, etc.) are valid without file check
      if not path.is_url(filepath) and vim.fn.filereadable(full_path) ~= 1 then
        table.insert(
          errors,
          string.format("Line %d: File not found: %s", i, filepath)
        )
      else
        table.insert(new_locks, { filename = path.to_lock_path(full_path) })
      end
    end
  end

  -- Show errors if any
  if #errors > 0 then
    vim.notify("Edit errors:\n" .. table.concat(errors, "\n"), vim.log.levels.ERROR)
    return
  end

  -- Update locks and persist
  local state = require("radar.data.state")
  local persistence = require("radar.persist.persistence")
  require("radar.data.locks").relabel(new_locks, radar_config)
  state.set_locks(new_locks)
  persistence.persist(radar_config)
  if radar_module then
    radar_module.update(radar_config)
  end
  require("radar.ui.hud").refresh()

  -- Mark buffer as saved
  vim.api.nvim_set_option_value("modified", false, { buf = edit_buf })
  vim.notify("Locks saved successfully", vim.log.levels.INFO)
end

---Open file from edit window line and cleanup
---@param edit_buf integer
---@param open_cmd string Command to open file (edit, vsplit, split, tabedit, float)
---@param radar_config Radar.Config
---@param radar_module table?
---@return nil
function M.open_file_from_edit(edit_buf, open_cmd, radar_config, radar_module)
  local state = require("radar.data.state")
  local cursor = vim.api.nvim_win_get_cursor(state.get_edit_winid())
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
  M.save_buffer(edit_buf, radar_config, radar_module)

  -- Extract and expand filepath
  local filepath = line:match("^%s*(.-)%s*$")
  local full_path = path.is_url(filepath) and filepath or path.to_absolute(filepath)

  -- Only validate regular filepaths
  if not path.is_url(filepath) and vim.fn.filereadable(full_path) ~= 1 then
    vim.notify(string.format("File not found: %s", filepath), vim.log.levels.ERROR)
    return
  end

  -- Clean up edit window
  M.cleanup()

  -- Open the file using navigation module
  local navigation = require("radar.ui.navigation")
  navigation.open_file(
    full_path,
    open_cmd,
    radar_config,
    radar_module or require("radar.ui.radar")
  )
end

---Cleanup edit mode state
---@return nil
function M.cleanup()
  local state = require("radar.data.state")
  if
    state.get_edit_winid() and vim.api.nvim_win_is_valid(state.get_edit_winid())
  then
    vim.api.nvim_win_close(state.get_edit_winid(), true)
  end

  state.set_edit_winid(nil)
  state.set_edit_bufid(nil)

  require("radar.ui.radar").close()
end

---Pane the editor sits in: the current window, or the previous one while a
---float has focus
---@return integer
local function anchor_window()
  local current = vim.api.nvim_get_current_win()
  if vim.api.nvim_win_get_config(current).relative == "" then
    return current
  end
  return vim.fn.win_getid(vim.fn.winnr("#"))
end

---Create editable buffer for managing locks, at the bottom of the active pane
---@param radar_config Radar.Config
---@param radar_module table? radar to close now and re-render after saving
---@return nil
function M.edit_locks(radar_config, radar_module)
  local state = require("radar.data.state")

  -- Close radar window before opening edit window, keeping its source so
  -- saving recreates the same radar
  if radar_module then
    local source_bufnr, source_alt_file =
      state.get_source_bufnr(), state.get_source_alt_file()
    radar_module.close()
    state.set_source_bufnr(source_bufnr)
    state.set_source_alt_file(source_alt_file)
  end

  -- Clean up ALL existing buffers with this name (handles orphaned buffers)
  -- Loop because BufUnload callbacks during deletion can cause re-entrancy
  for _ = 1, 10 do
    local existing_buf = vim.fn.bufnr("radar-locks")
    if existing_buf == -1 then
      break
    end
    pcall(vim.api.nvim_buf_delete, existing_buf, { force = true })
  end

  -- Create editable buffer
  local edit_buf = vim.api.nvim_create_buf(false, false)
  state.set_edit_bufid(edit_buf)

  -- Set buffer options — set name before other options to catch E95 early
  -- Use pcall because a race with BufUnload/wipe can leave a ghost name
  local ok = pcall(vim.api.nvim_buf_set_name, edit_buf, "radar-locks")
  if not ok then
    -- Force-remove any lingering buffer with that name and retry
    local ghost = vim.fn.bufnr("radar-locks")
    if ghost ~= -1 and ghost ~= edit_buf then
      pcall(vim.api.nvim_buf_delete, ghost, { force = true })
    end
    -- Retry once — if it still fails, use a unique fallback name
    local ok2 = pcall(vim.api.nvim_buf_set_name, edit_buf, "radar-locks")
    if not ok2 then
      vim.api.nvim_buf_set_name(edit_buf, "radar-locks-" .. edit_buf)
    end
  end
  vim.api.nvim_set_option_value("buftype", "acwrite", { buf = edit_buf })
  vim.api.nvim_set_option_value("filetype", "radar-edit", { buf = edit_buf })
  vim.api.nvim_set_option_value("bufhidden", "wipe", { buf = edit_buf })

  -- Create buffer lines: just the filepaths (labels assigned by line order)
  local lines = {}
  for _, lock in ipairs(state.get_locks()) do
    local formatted_path = lock.filename
    if not path.is_oil_url(lock.filename) then
      formatted_path = path.display(lock.filename)
    end
    table.insert(lines, formatted_path)
  end

  vim.api.nvim_buf_set_lines(edit_buf, 0, -1, false, lines)

  local anchor = anchor_window()
  local pane_height = vim.api.nvim_win_get_height(anchor)
  local win_height = math.min(math.max(#lines, 3), pane_height)
  local edit_win = vim.api.nvim_open_win(edit_buf, true, {
    relative = "win",
    win = anchor,
    row = pane_height - win_height,
    col = 0,
    width = vim.api.nvim_win_get_width(anchor),
    height = win_height,
    border = "none",
    focusable = true,
    zindex = 20,
  })
  state.set_edit_winid(edit_win)
  vim.api.nvim_set_option_value("winblend", 0, { win = edit_win })

  -- Apply window-local options
  for opt, value in pairs(radar_config.radar_edit.win_opts) do
    vim.api.nvim_set_option_value(opt, value, { win = edit_win })
  end

  require("radar.ui.hud").refresh()

  -- Set up buffer autocmds for save and close
  setup_edit_autocmds(edit_buf, radar_config, radar_module)

  -- Set up buffer-local keymaps
  vim.api.nvim_buf_set_keymap(edit_buf, "n", "q", "", {
    noremap = true,
    silent = true,
    desc = "Save and quit radar edit buffer",
    callback = function()
      -- Save changes first (this also updates radar via radar_module.update())
      M.save_buffer(edit_buf, radar_config, radar_module)
      -- Close the edit window (BufUnload calls M.cleanup())
      if vim.api.nvim_win_is_valid(edit_win) then
        vim.api.nvim_win_close(edit_win, true)
      end
    end,
  })

  -- Navigation keymaps
  vim.api.nvim_buf_set_keymap(edit_buf, "n", "<CR>", "", {
    noremap = true,
    silent = true,
    desc = "Open file under cursor",
    callback = function()
      M.open_file_from_edit(edit_buf, "edit", radar_config, radar_module)
    end,
  })

  vim.api.nvim_buf_set_keymap(edit_buf, "n", "<C-v>", "", {
    noremap = true,
    silent = true,
    desc = "Open file in vertical split",
    callback = function()
      M.open_file_from_edit(edit_buf, "vsplit", radar_config, radar_module)
    end,
  })

  vim.api.nvim_buf_set_keymap(edit_buf, "n", "<C-s>", "", {
    noremap = true,
    silent = true,
    desc = "Open file in horizontal split",
    callback = function()
      M.open_file_from_edit(edit_buf, "split", radar_config, radar_module)
    end,
  })

  vim.api.nvim_buf_set_keymap(edit_buf, "n", "<C-t>", "", {
    noremap = true,
    silent = true,
    desc = "Open file in new tab",
    callback = function()
      M.open_file_from_edit(edit_buf, "tabedit", radar_config, radar_module)
    end,
  })

  vim.api.nvim_buf_set_keymap(edit_buf, "n", "<C-f>", "", {
    noremap = true,
    silent = true,
    desc = "Open file in floating window",
    callback = function()
      M.open_file_from_edit(edit_buf, "float", radar_config, radar_module)
    end,
  })
end

return M
