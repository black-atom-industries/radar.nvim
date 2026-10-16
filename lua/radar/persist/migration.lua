local M = {}

M.VERSION = 2

---Ensure branch data has lastAccessed property
---@param branch_data table
---@return table
function M.ensure_last_accessed(branch_data)
  if not branch_data.lastAccessed then
    branch_data.lastAccessed = os.time()
  end
  return branch_data
end

---Migrate v0 format to v1
---@param data table
---@return table
function M.migrate_v0_to_v1(data)
  local migrated = {
    version = 1,
    projects = {},
  }

  -- Wrap existing data under "projects" key
  for project_path, branches in pairs(data) do
    migrated.projects[project_path] = {}
    for branch_name, branch_data in pairs(branches) do
      -- Ensure lastAccessed is present
      migrated.projects[project_path][branch_name] =
        M.ensure_last_accessed(branch_data)
    end
  end

  return migrated
end

---Undo vim.fn.fnameescape
---@param key any
---@return any
local function unescape(key)
  if type(key) ~= "string" then
    return key
  end
  return (key:gsub("\\(.)", "%1"))
end

---Append locks to `target`, skipping filenames it already has
---@param target table branch data
---@param source table branch data
local function merge_branch(target, source)
  target.locks = target.locks or {}
  local seen = {}
  for _, lock in ipairs(target.locks) do
    seen[lock.filename] = true
  end
  for _, lock in ipairs(source.locks or {}) do
    if not seen[lock.filename] then
      seen[lock.filename] = true
      table.insert(target.locks, lock)
    end
  end
  target.lastAccessed = math.max(target.lastAccessed or 0, source.lastAccessed or 0)
end

---Rebase a lock filename stored relative to `dir` onto `root`
---@param filename string
---@param dir string
---@param root string
---@return string
local function rebase(filename, dir, root)
  local path = require("radar.path")
  if path.is_url(filename) then
    return filename
  end
  local abs = vim.startswith(filename, "/") and filename
    or vim.fs.normalize(dir .. "/" .. filename)
  return path.relative_to(abs, root) or abs
end

---Migrate v1 to v2: keys are unescaped raw strings, and projects keyed by a
---subdirectory of a git checkout are merged into the checkout root with lock
---filenames relative to the root.
---@param data table
---@return table
function M.migrate_v1_to_v2(data)
  local projects = {}
  for project_key, branches in pairs(data.projects or {}) do
    local project = unescape(project_key)
    projects[project] = projects[project] or {}
    for branch, branch_data in pairs(branches) do
      local target = projects[project][unescape(branch)]
      if target then
        merge_branch(target, branch_data)
      else
        projects[project][unescape(branch)] = branch_data
      end
    end
  end

  local keys = vim.tbl_keys(projects)
  table.sort(keys)
  for _, project in ipairs(keys) do
    local dir = vim.fs.normalize(project)
    local info = vim.fn.isdirectory(dir) == 1 and require("radar.path").git_info(dir)
    if info and info.root ~= dir then
      local root_key = vim.fn.fnamemodify(info.root, ":~")
      projects[root_key] = projects[root_key] or {}
      for branch, branch_data in pairs(projects[project]) do
        for _, lock in ipairs(branch_data.locks or {}) do
          lock.filename = rebase(lock.filename, dir, info.root)
        end
        local target = projects[root_key][branch]
        if target then
          merge_branch(target, branch_data)
        else
          projects[root_key][branch] = branch_data
        end
      end
      projects[project] = nil
    end
  end

  return { version = 2, projects = projects }
end

---Migrate data to current version
---@param data table?
---@return table
function M.migrate(data)
  -- Handle nil or empty data
  if not data or vim.tbl_isempty(data) then
    return {
      version = M.VERSION,
      projects = {},
    }
  end

  -- v0 format (no version property)
  if not data.version then
    data = M.migrate_v0_to_v1(data)
  end

  if data.version == 1 then
    -- Ensure all branch entries have lastAccessed
    for _, branches in pairs(data.projects or {}) do
      for _, branch_data in pairs(branches) do
        M.ensure_last_accessed(branch_data)
      end
    end
    data = M.migrate_v1_to_v2(data)
  end

  if data.version == M.VERSION then
    return data
  end

  -- Unknown version - return as-is with warning
  vim.notify(
    string.format(
      "Unknown radar data version: %s. Using data as-is.",
      tostring(data.version)
    ),
    vim.log.levels.WARN
  )
  return data
end

return M
