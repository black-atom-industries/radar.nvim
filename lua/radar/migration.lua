local M = {}

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

---Migrate data to current version
---@param data table?
---@return table
function M.migrate(data)
  -- Handle nil or empty data
  if not data or vim.tbl_isempty(data) then
    return {
      version = 1,
      projects = {},
    }
  end

  -- Check version
  local version = data.version

  -- v0 format (no version property)
  if not version then
    return M.migrate_v0_to_v1(data)
  end

  -- v1 format (current)
  if version == 1 then
    -- Ensure all branch entries have lastAccessed
    for project_path, branches in pairs(data.projects or {}) do
      for branch_name, branch_data in pairs(branches) do
        M.ensure_last_accessed(branch_data)
      end
    end
    return data
  end

  -- Unknown version - return as-is with warning
  vim.notify(
    string.format(
      "Unknown radar data version: %s. Using data as-is.",
      tostring(version)
    ),
    vim.log.levels.WARN
  )
  return data
end

return M
