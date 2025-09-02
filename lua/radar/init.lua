local M = {}

M.constants = {
  ns_mini_radar = vim.api.nvim_create_namespace("radar.win.mini"),
}

---@class Radar.Config
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

---@class Radar.Lock
---@field label string
---@field filename string

---@class Radar.State
M.state = {
  ---@type Radar.Lock[]
  locks = {},
  mini_radar_winid = nil,
  ---@param field "label" | "filename"
  ---@param value string
  get_lock_by_field = function(field, value)
    for _, lock in ipairs(M.state.locks) do
      if lock[field] == value then
        return lock
      end
    end
  end,
  ---@param filename string
  get_lock_from_filename = function(filename)
    return M.state.get_lock_by_field("filename", filename)
  end,
  get_lock_from_label = function(label)
    return M.state.get_lock_by_field("label", label)
  end,
}

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

function M:get_project_path()
  local cwd = vim.uv.cwd()

  if not cwd then
    return nil
  end

  local sanitized_path = vim.fn.fnameescape(cwd)
  return vim.fn.fnamemodify(sanitized_path, ":~")
end

-- TODO: Could not be a git project
function M:get_git_branch()
  local branch = vim.fn.systemlist("git branch --show-current")[1]
  if branch == "" then
    return nil
  end

  local sanitized_branch = vim.fn.fnameescape(branch)
  return sanitized_branch
end

function M:get_data_file_path()
  return self.config.persist.folder .. "/" .. self.config.persist.filename
end

function M:load()
  local file_path = self:get_data_file_path()
  local is_readable = vim.fn.filereadable(file_path)
  if is_readable == 1 then
    return self:read(file_path)
  else
    return nil
  end
end

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
      M:create_board()
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

function M:does_mini_radar_exist()
  return self.state.mini_radar_winid
    and vim.api.nvim_win_is_valid(self.state.mini_radar_winid)
end

---If no buf_nr is provided it uses its current buf
---@param buf_nr? integer
---@return string
function M:get_current_filename(buf_nr)
  buf_nr = buf_nr or vim.api.nvim_get_current_buf()
  return vim.api.nvim_buf_get_name(buf_nr)
end

---@param buf_nr integer
function M:lock(buf_nr)
  local filename = M:get_current_filename(buf_nr)
  M:toggle_lock(filename)

  if #M.state.locks == 0 and M:does_mini_radar_exist() then
    vim.api.nvim_win_close(M.state.mini_radar_winid, true)
    M.state.mini_radar_winid = nil
  elseif not M:does_mini_radar_exist() then
    M:create_board()
  else
    M:update_board()
  end
end


---@param label string
function M:open_lock(label)
  local lock = self.state.get_lock_from_label(tostring(label))
  local path = vim.fn.fnameescape(lock.filename)
  vim.cmd.edit(path)
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

function M:get_mini_radar_bufid()
  local win = self.state.mini_radar_winid

  if win ~= nil and vim.api.nvim_win_is_valid(win) then
    return vim.api.nvim_win_get_buf(win)
  else
    return nil
  end
end

function M:create_board()
  local entries = M:create_entries(self.state.locks)

  local new_buf_id = vim.api.nvim_create_buf(false, true)
  vim.api.nvim_buf_set_lines(new_buf_id, 0, -1, false, entries)

  local board_width = self.config.win.width
  local win_opts = vim.tbl_deep_extend("force", self.config.win, {
    width = board_width,
    height = #entries,
    -- row = math.floor((vim.o.lines - #entries) - 10),
    row = 1,
    col = math.floor((vim.o.columns - board_width) - 2),
  })

  local win = vim.api.nvim_open_win(new_buf_id, false, win_opts)
  M.state.mini_radar_winid = win
  M:highlight_active_lock()
end

function M:highlight_active_lock()
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

function M:update_board()
  -- Close window if no locks left
  if #self.state.locks == 0 and self:does_mini_radar_exist() then
    vim.api.nvim_win_close(self.state.mini_radar_winid, true)
    self.state.mini_radar_winid = nil
    return
  end

  local mini_radar_bufid = self:get_mini_radar_bufid()
  if mini_radar_bufid == nil then
    return
  end

  local entries = M:create_entries(self.state.locks)

  vim.api.nvim_buf_set_lines(mini_radar_bufid, 0, -1, false, entries)
  vim.api.nvim_win_set_config(self.state.mini_radar_winid, {
    relative = "editor",
    height = #self.state.locks,
    row = 1,
    col = math.floor((vim.o.columns - self.config.win.width) - 2),
  })
  M:highlight_active_lock()
end

---@param opts Radar.Config
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
    vim.keymap.set("n", M.config.keys.prefix .. label, function()
      M:open_lock(label)
    end, { desc = "Open " .. label .. " Lock" })
  end

  -- Temporary binding to edit the data file directly
  vim.keymap.set("n", M.config.keys.prefix .. "e", function()
    vim.cmd("vsplit " .. M:get_data_file_path())
  end, { desc = "Open radar data file" })

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
    M:update_board()
  end,
})

return M
