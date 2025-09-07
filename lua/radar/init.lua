local M = {}

M.constants = {
  ns_mini_radar = vim.api.nvim_create_namespace("radar.win.mini"),
}

---@class Radar.Config.Keys
---@field prefix string
---@field lock string
---@field locks string[]

---@class Radar.Config.Persist
---@field folder string
---@field filename string

---@class Radar.Config
---@field keys Radar.Config.Keys
---@field path_format string
---@field win vim.api.keyset.win_config
---@field persist Radar.Config.Persist

---@class Radar.Lock
---@field label string
---@field filename string

---@class Radar.ProjectData
---@field locks Radar.Lock[]

---@class Radar.BranchData
---@field [string] Radar.ProjectData

---@class Radar.PersistenceData
---@field [string] Radar.BranchData

M.config = {
  keys = {
    prefix = "<space>",
    lock = ",<space>",
    locks = { "1", "2", "3", "4", "5", "6", "7", "8", "9" }, -- num row
    -- Future radar features:
    -- modified = { "q", "w", "e", "r", "t" }, -- upper row
    -- recent = { "a", "s", "d", "f", "g" }, -- home row
    -- pr_files = { "z", "x", "c", "v", "b" }, -- bottom row
  },

  -- See :h filename-modifiers
  path_format = ":p:.",

  -- Window transparency (0-100, where 0 is opaque and 100 is fully transparent)
  winblend = 15,

  ---@type vim.api.keyset.win_config
  win = {
    width = 50,
    relative = "editor",
    anchor = "NW",
    title = "◎ RADAR",
    title_pos = "left",
    style = "minimal",
    border = "solid",
    focusable = false,
    zindex = 100,
  },

  persist = {
    folder = vim.fs.joinpath(vim.fn.stdpath("data"), "radar"),
    filename = "data.json",
  },
}

---@class Radar.State
M.state = {
  ---@type Radar.Lock[]
  locks = {},
  ---@type integer?
  mini_radar_winid = nil,
  ---@type integer?
  edit_winid = nil,
  ---@type integer?
  edit_bufid = nil,
  ---@param field "label" | "filename"
  ---@param value string
  ---@return Radar.Lock?
  get_lock_by_field = function(field, value)
    for _, lock in ipairs(M.state.locks) do
      if lock[field] == value then
        return lock
      end
    end
  end,
  ---@param filename string
  ---@return Radar.Lock?
  get_lock_from_filename = function(filename)
    return M.state.get_lock_by_field("filename", filename)
  end,
  ---@param label string
  ---@return Radar.Lock?
  get_lock_from_label = function(label)
    return M.state.get_lock_by_field("label", label)
  end,
}

---@return string
function M:get_next_unused_lock_label()
  local used_labels = {}
  for _, lock in ipairs(self.state.locks) do
    table.insert(used_labels, lock.label)
  end

  for _, label in ipairs(self.config.keys.locks) do
    if not vim.tbl_contains(used_labels, label) then
      return label
    end
  end

  error("No more lock slots available")
end

---@param path string
---@param tbl table
---@return boolean
function M:write(path, tbl)
  local ok, _ = pcall(function()
    local fd = assert(vim.uv.fs_open(path, "w", 438)) -- 438 = 0666
    assert(vim.uv.fs_write(fd, vim.json.encode(tbl)))
    assert(vim.uv.fs_close(fd))
  end)

  -- Format with prettier if available and it's a JSON file
  if ok and vim.fn.executable("prettier") == 1 then
    vim.fn.system("prettier --write " .. vim.fn.shellescape(path))
  end

  return ok
end

---@param path string
---@return Radar.PersistenceData?
function M:read(path)
  local ok, content = pcall(function()
    local fd = assert(vim.uv.fs_open(path, "r", 438)) -- 438 = 0666
    local stat = assert(vim.uv.fs_fstat(fd))
    local data = assert(vim.uv.fs_read(fd, stat.size, 0))
    assert(vim.uv.fs_close(fd))
    return data
  end)

  return ok and vim.json.decode(content) or nil
end

---@param filename string
---@returns Radar.Lock
function M:add_lock(filename)
  local next_free_lock_label = M:get_next_unused_lock_label()

  ---@type Radar.Lock
  local lock = {
    label = next_free_lock_label,
    filename = filename,
  }

  table.insert(self.state.locks, lock)
  return lock
end

---Calculate optimal window width based on longest file path
---@return integer
function M:calculate_window_width()
  if #self.state.locks == 0 then
    return self.config.win.width
  end

  local max_width = 0
  for _, lock in ipairs(self.state.locks) do
    local formatted_path = self:get_formatted_filepath(lock.filename)
    local entry_text = string.format("  [%s] %s  ", lock.label, formatted_path)
    max_width = math.max(max_width, vim.fn.strdisplaywidth(entry_text))
  end

  -- Ensure minimum width and add padding
  return math.max(max_width, self.config.win.width)
end

---@param filename string
---@return Radar.Lock
function M:remove_lock(filename)
  ---@type Radar.Lock
  local removed_lock

  for i, lock in ipairs(self.state.locks) do
    if lock.filename == filename then
      removed_lock = lock
      table.remove(self.state.locks, i)
      break
    end
  end

  return removed_lock
end

---Create editable buffer for managing locks
---@return nil
function M:edit_locks()
  if #self.state.locks == 0 then
    vim.notify("No locks to edit", vim.log.levels.WARN)
    return
  end

  -- Create editable buffer
  local edit_buf = vim.api.nvim_create_buf(false, false)
  self.state.edit_bufid = edit_buf

  -- Set buffer options
  vim.api.nvim_buf_set_option(edit_buf, "buftype", "acwrite")
  vim.api.nvim_buf_set_option(edit_buf, "filetype", "radar-edit")
  vim.api.nvim_buf_set_name(edit_buf, "radar-locks")
  vim.api.nvim_buf_set_option(edit_buf, "bufhidden", "wipe")

  -- Create buffer lines: just the filepaths (labels assigned by line order)
  local lines = {}
  for _, lock in ipairs(self.state.locks) do
    local formatted_path = self:get_formatted_filepath(lock.filename)
    table.insert(lines, formatted_path)
  end

  vim.api.nvim_buf_set_lines(edit_buf, 0, -1, false, lines)

  -- Open floating window
  local calculated_width = self:calculate_window_width()
  local win_width = math.max(60, calculated_width + 10)
  local win_height = math.min(#lines + 2, 20)
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
  self.state.edit_winid = edit_win

  -- Set up buffer autocmds for save and close
  self:setup_edit_autocmds(edit_buf)

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
      self:open_file_from_edit(edit_buf, "edit")
    end,
  })
  
  vim.api.nvim_buf_set_keymap(edit_buf, "n", "<C-v>", "", {
    noremap = true,
    silent = true,
    desc = "Open file in vertical split",
    callback = function()
      self:open_file_from_edit(edit_buf, "vsplit")
    end,
  })
  
  vim.api.nvim_buf_set_keymap(edit_buf, "n", "<C-s>", "", {
    noremap = true,
    silent = true,
    desc = "Open file in horizontal split",
    callback = function()
      self:open_file_from_edit(edit_buf, "split")
    end,
  })
  
  vim.api.nvim_buf_set_keymap(edit_buf, "n", "<C-x>", "", {
    noremap = true,
    silent = true,
    desc = "Open file in horizontal split",
    callback = function()
      self:open_file_from_edit(edit_buf, "split")
    end,
  })
  
  vim.api.nvim_buf_set_keymap(edit_buf, "n", "<C-t>", "", {
    noremap = true,
    silent = true,
    desc = "Open file in new tab",
    callback = function()
      self:open_file_from_edit(edit_buf, "tabedit")
    end,
  })
end

---Setup autocmds for edit buffer save and close handling
---@param edit_buf integer
---@return nil
function M:setup_edit_autocmds(edit_buf)
  local augroup = vim.api.nvim_create_augroup("radar.EditLocks", { clear = true })

  -- Handle buffer save (:w)
  vim.api.nvim_create_autocmd("BufWriteCmd", {
    group = augroup,
    buffer = edit_buf,
    callback = function()
      self:save_edit_buffer(edit_buf)
    end,
  })

  -- Handle buffer close/unload
  vim.api.nvim_create_autocmd("BufUnload", {
    group = augroup,
    buffer = edit_buf,
    callback = function()
      self:cleanup_edit_mode()
    end,
  })
end

---Parse and save changes from edit buffer
---@param edit_buf integer
---@return nil
function M:save_edit_buffer(edit_buf)
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
      label = self.config.keys.locks[i] or tostring(i),
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
  self.state.locks = new_locks
  self:persist()
  self:update_mini_radar()

  -- Mark buffer as saved
  vim.api.nvim_buf_set_option(edit_buf, "modified", false)
  vim.notify("Locks saved successfully", vim.log.levels.INFO)
end

---Open file from edit window line and cleanup
---@param edit_buf integer
---@param open_cmd string Command to open file (edit, vsplit, split, tabedit)
---@return nil
function M:open_file_from_edit(edit_buf, open_cmd)
  local cursor = vim.api.nvim_win_get_cursor(self.state.edit_winid)
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
  self:save_edit_buffer(edit_buf)
  
  -- Extract and expand filepath
  local filepath = line:match("^%s*(.-)%s*$")
  local full_path = vim.fn.expand(filepath)
  
  if not vim.fn.filereadable(full_path) then
    vim.notify(string.format("File not found: %s", filepath), vim.log.levels.ERROR)
    return
  end
  
  -- Clean up edit window
  self:cleanup_edit_mode()
  
  -- Open the file
  local escaped_path = vim.fn.fnameescape(full_path)
  vim.cmd(open_cmd .. " " .. escaped_path)
end

---Cleanup edit mode state
---@return nil
function M:cleanup_edit_mode()
  if self.state.edit_winid and vim.api.nvim_win_is_valid(self.state.edit_winid) then
    vim.api.nvim_win_close(self.state.edit_winid, true)
  end

  self.state.edit_winid = nil
  self.state.edit_bufid = nil
end

---@return string?
function M:get_project_path()
  local cwd = vim.uv.cwd()

  if not cwd then
    return nil
  end

  local sanitized_path = vim.fn.fnameescape(cwd)
  return vim.fn.fnamemodify(sanitized_path, ":~")
end

-- TODO: Could not be a git project
---@return string?
function M:get_git_branch()
  local branch = vim.fn.systemlist("git branch --show-current")[1]
  if branch == "" then
    return nil
  end

  local sanitized_branch = vim.fn.fnameescape(branch)
  return sanitized_branch
end

---@return string
function M:get_data_file_path()
  return self.config.persist.folder .. "/" .. self.config.persist.filename
end

---@return Radar.PersistenceData?
function M:load()
  local file_path = self:get_data_file_path()
  local is_readable = vim.fn.filereadable(file_path)
  if is_readable == 1 then
    return self:read(file_path)
  else
    return nil
  end
end

---@return Radar.PersistenceData
function M:persist()
  local project_path = M:get_project_path()
  local git_branch = M:get_git_branch()

  local persisted_data = M:load()
  local data

  if persisted_data == nil then
    data = {
      [project_path] = {
        [git_branch] = {
          locks = self.state.locks,
        },
      },
    }
  else
    data = vim.tbl_deep_extend("force", persisted_data, {
      [project_path] = {
        [git_branch] = {
          locks = self.state.locks,
        },
      },
    })
  end

  vim.fn.mkdir(self.config.persist.folder, "p")
  self:write(self:get_data_file_path(), data)
  return data
end

---@return nil
function M:populate()
  local data = self:load()

  if data ~= nil then
    local project_path = M:get_project_path()
    local git_branch = M:get_git_branch()
    local locks = vim.tbl_get(data, project_path, git_branch, "locks")

    if locks == nil then
      return
    end

    self.state.locks = locks

    if #locks > 0 then
      M:create_mini_radar()
    end
  end
end

---@param filename string
---@return Radar.Lock
function M:toggle_lock(filename)
  local exists = self.state.get_lock_from_filename(filename)

  local lock

  if not exists then
    lock = M:add_lock(filename)
  else
    lock = M:remove_lock(filename)
  end

  vim.defer_fn(function()
    self:persist()
  end, 500)

  return lock
end

---@return boolean
function M:does_mini_radar_exist()
  return self.state.mini_radar_winid
      and vim.api.nvim_win_is_valid(self.state.mini_radar_winid)
    or false
end

---Ensure mini radar exists, create if needed and locks exist
---@return nil
function M:ensure_mini_radar_exists()
  if #self.state.locks > 0 and not self:does_mini_radar_exist() then
    self:create_mini_radar()
  end
end

---If no buf_nr is provided it uses its current buf
---@param buf_nr? integer
---@return string
function M:get_current_filename(buf_nr)
  buf_nr = buf_nr or vim.api.nvim_get_current_buf()
  return vim.api.nvim_buf_get_name(buf_nr)
end

---@param buf_nr? integer
---@return nil
function M:lock(buf_nr)
  local filename = M:get_current_filename(buf_nr)
  M:toggle_lock(filename)

  if #M.state.locks == 0 and M:does_mini_radar_exist() then
    vim.api.nvim_win_close(M.state.mini_radar_winid, true)
    M.state.mini_radar_winid = nil
  elseif not M:does_mini_radar_exist() then
    M:create_mini_radar()
  else
    M:update_mini_radar()
  end
end

---@param label string
---@param open_cmd? string Command to open file (edit, vsplit, split, tabedit)
---@return nil
function M:open_lock(label, open_cmd)
  local lock = self.state.get_lock_from_label(tostring(label))

  if lock == nil then
    return
  end

  M:ensure_mini_radar_exists()

  local path = vim.fn.fnameescape(lock.filename)
  open_cmd = open_cmd or "edit"

  vim.cmd(open_cmd .. " " .. path)
end

---@param path string
---@return string
function M:get_formatted_filepath(path)
  return vim.fn.fnamemodify(path, self.config.path_format)
end

---Create formatted entries
---@param locks Radar.Lock[]
---@return string[] -- ATTENTION: This does NOT generate a new array of objects, but just an array of strings
function M:create_entries(locks)
  local entries = {}

  for _, lock in ipairs(locks) do
    local path = self:get_formatted_filepath(lock.filename)
    local entry = string.format("  [%s] %s  ", lock.label, path)
    table.insert(entries, entry)
  end

  return entries
end

---@return integer?
function M:get_mini_radar_bufid()
  local win = self.state.mini_radar_winid

  if win ~= nil and vim.api.nvim_win_is_valid(win) then
    return vim.api.nvim_win_get_buf(win)
  else
    return nil
  end
end

---@return nil
function M:create_mini_radar()
  local entries = M:create_entries(self.state.locks)

  local new_buf_id = vim.api.nvim_create_buf(false, true)
  vim.api.nvim_buf_set_lines(new_buf_id, 0, -1, false, entries)

  local board_width = self:calculate_window_width()
  local win_opts = vim.tbl_deep_extend("force", self.config.win, {
    width = board_width,
    height = #entries,
    -- row = math.floor((vim.o.lines - #entries) - 10),
    row = 1,
    col = math.floor((vim.o.columns - board_width) - 2),
  })

  local win = vim.api.nvim_open_win(new_buf_id, false, win_opts)
  M.state.mini_radar_winid = win
  
  -- Set window transparency
  vim.api.nvim_set_option_value("winblend", self.config.winblend, { win = win })
  
  M:highlight_active_lock()
end

---@return nil
function M:highlight_active_lock()
  self:ensure_mini_radar_exists()
  local lock_board_bufid = self:get_mini_radar_bufid()

  if lock_board_bufid == nil then
    return
  end

  local lines = vim.api.nvim_buf_get_lines(lock_board_bufid, 0, -1, false)

  local curr_filepath = self:get_current_filename()
  local curr_formatted_filepath = self:get_formatted_filepath(curr_filepath)

  -- Abort on empty files
  if curr_formatted_filepath == "" then
    return
  end

  vim.api.nvim_buf_clear_namespace(
    lock_board_bufid,
    self.constants.ns_mini_radar,
    0,
    -1
  )

  for i, line in ipairs(lines) do
    if line:find(curr_formatted_filepath, 1, true) then
      vim.api.nvim_buf_set_extmark(
        lock_board_bufid,
        self.constants.ns_mini_radar,
        i - 1,
        0,
        {
          end_col = #line,
          hl_group = "@function",
        }
      )
      break
    end
  end
end

---@return nil
function M:update_mini_radar()
  -- Close window if no locks left
  if #self.state.locks == 0 and self:does_mini_radar_exist() then
    vim.api.nvim_win_close(self.state.mini_radar_winid, true)
    self.state.mini_radar_winid = nil
    return
  end

  self:ensure_mini_radar_exists()
  local mini_radar_bufid = self:get_mini_radar_bufid()
  if mini_radar_bufid == nil then
    return
  end

  local entries = M:create_entries(self.state.locks)

  vim.api.nvim_buf_set_lines(mini_radar_bufid, 0, -1, false, entries)
  
  local board_width = self:calculate_window_width()
  vim.api.nvim_win_set_config(self.state.mini_radar_winid, {
    relative = "editor",
    width = board_width,
    height = #self.state.locks,
    row = 1,
    col = math.floor((vim.o.columns - board_width) - 2),
  })
  M:highlight_active_lock()
end

---@param opts? Radar.Config
---@return nil
function M.setup(opts)
  opts = opts or {}
  local merged_config = vim.tbl_deep_extend("force", M.config, opts)
  M.config = merged_config

  vim.keymap.set(
    "n",
    M.config.keys.lock,
    M.lock,
    { desc = "Lock the current buffer" }
  )

  vim.keymap.set("n", ";q", function()
    vim.api.nvim_win_close(M.state.mini_radar_winid, true)
  end, { desc = "Close Mini Radar" })

  for _, label in ipairs(M.config.keys.locks) do
    -- Regular open
    vim.keymap.set("n", M.config.keys.prefix .. label, function()
      M:open_lock(label)
    end, { desc = "Open " .. label .. " Lock" })
    
    -- Vertical split
    vim.keymap.set("n", M.config.keys.prefix .. "v" .. label, function()
      M:open_lock(label, "vsplit")
    end, { desc = "Open " .. label .. " Lock in vertical split" })
    
    -- Horizontal split
    vim.keymap.set("n", M.config.keys.prefix .. "s" .. label, function()
      M:open_lock(label, "split")
    end, { desc = "Open " .. label .. " Lock in horizontal split" })
    
    -- New tab
    vim.keymap.set("n", M.config.keys.prefix .. "t" .. label, function()
      M:open_lock(label, "tabedit")
    end, { desc = "Open " .. label .. " Lock in new tab" })
  end

  -- Edit locks in floating window
  vim.keymap.set("n", M.config.keys.prefix .. "e", function()
    M:edit_locks()
  end, { desc = "Edit radar locks" })

  M:populate()

  _G.Radar = M
end

vim.api.nvim_create_autocmd("BufEnter", {
  group = vim.api.nvim_create_augroup("radar.BufEnter", { clear = true }),
  callback = function()
    M:highlight_active_lock()
  end,
})

vim.api.nvim_create_autocmd("VimResized", {
  group = vim.api.nvim_create_augroup("radar.VimResized", { clear = true }),
  callback = function()
    M:update_mini_radar()
  end,
})

return M
