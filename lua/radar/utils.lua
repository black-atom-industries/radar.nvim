local M = {}

---Sort projects alphabetically by key
---@param projects table
---@return table
function M.sort_projects(projects)
  if not projects then
    return {}
  end

  -- Get all project paths and sort them
  local sorted_keys = {}
  for project_path, _ in pairs(projects) do
    table.insert(sorted_keys, project_path)
  end
  table.sort(sorted_keys)

  -- Build new table with sorted keys
  local sorted_projects = {}
  for _, project_path in ipairs(sorted_keys) do
    sorted_projects[project_path] = projects[project_path]
  end

  return sorted_projects
end

return M
