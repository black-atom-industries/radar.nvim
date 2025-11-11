local M = {}

---Get list of branches for a git project
---@param project_path string
---@return string[]?
function M.get_project_branches(project_path)
    -- Expand path from ~ notation to full path
    local expanded_path = vim.fn.expand(project_path)

    -- Check if directory exists
    if vim.fn.isdirectory(expanded_path) == 0 then
        return nil
    end

    -- Check if it's a git repo
    local git_dir = expanded_path .. "/.git"
    if vim.fn.isdirectory(git_dir) == 0 then
        return nil
    end

    -- Get all local branches
    local cmd = string.format("cd %s && git branch --format='%%(refname:short)'", vim.fn.shellescape(expanded_path))
    local branches = vim.fn.systemlist(cmd)

    -- Check if command failed
    if vim.v.shell_error ~= 0 then
        return nil
    end

    return branches
end

---Check if an entry should be preserved (safety checks)
---@param project_path string
---@param branch_name string
---@param current_project string?
---@param current_branch string?
---@return boolean
function M.should_preserve_entry(project_path, branch_name, current_project, current_branch)
    -- Always preserve current working branch
    if project_path == current_project and branch_name == current_branch then
        return true
    end

    return false
end

---Check if entry is too old based on lastAccessed timestamp
---@param branch_data table
---@param older_than_days number?
---@return boolean
function M.is_too_old(branch_data, older_than_days)
    if not older_than_days then
        return false
    end

    local last_accessed = branch_data.lastAccessed
    if not last_accessed then
        return false
    end

    local current_time = os.time()
    local age_in_seconds = current_time - last_accessed
    local age_in_days = age_in_seconds / (24 * 60 * 60)

    return age_in_days > older_than_days
end

---Clean up stale persistence data
---@param config Radar.Config
---@param opts? { dry_run?: boolean, older_than_days?: number }
---@return { removed: number, entries: string[] }
function M.cleanup(config, opts)
    opts = opts or {}
    local dry_run = opts.dry_run or false
    local older_than_days = opts.older_than_days

    local persistence = require("radar.persistence")
    local data = persistence.load(config)

    if not data or not data.projects then
        return { removed = 0, entries = {} }
    end

    local current_project = persistence.get_project_path()
    local current_branch = persistence.get_git_branch()

    local new_data = {
        version = data.version or 1,
        projects = {},
    }
    local removed_count = 0
    local removed_entries = {}

    for project_path, branches in pairs(data.projects) do
        -- Check if project directory exists
        local expanded_path = vim.fn.expand(project_path)
        local project_exists = vim.fn.isdirectory(expanded_path) == 1

        if not project_exists then
            -- Project deleted - remove all branches
            for branch_name, _ in pairs(branches) do
                removed_count = removed_count + 1
                table.insert(removed_entries, string.format("%s [%s]", project_path, branch_name))
            end
        else
            -- Project exists - check branches
            local git_branches = M.get_project_branches(project_path)

            -- If we can't get branches (not a git repo or error), keep all data (fail-safe)
            if not git_branches then
                new_data.projects[project_path] = branches
            else
                -- Create a set for fast lookup
                local branch_set = {}
                for _, branch in ipairs(git_branches) do
                    branch_set[branch] = true
                end

                -- Check each stored branch
                local project_new_data = {}
                for branch_name, branch_data in pairs(branches) do
                    local should_preserve = M.should_preserve_entry(project_path, branch_name, current_project, current_branch)
                    local branch_exists = branch_set[branch_name] ~= nil
                    local too_old = M.is_too_old(branch_data, older_than_days)

                    if should_preserve then
                        -- Always preserve current branch
                        project_new_data[branch_name] = branch_data
                    elseif not branch_exists or too_old then
                        -- Remove if branch doesn't exist OR is too old
                        removed_count = removed_count + 1
                        local reason = not branch_exists and "deleted" or "too old"
                        table.insert(removed_entries, string.format("%s [%s] (%s)", project_path, branch_name, reason))
                    else
                        -- Keep it
                        project_new_data[branch_name] = branch_data
                    end
                end

                -- Only keep project if it has branches
                if vim.tbl_count(project_new_data) > 0 then
                    new_data.projects[project_path] = project_new_data
                end
            end
        end
    end

    -- Write cleaned data if not dry run
    if not dry_run then
        persistence.write(config.persist.path, new_data)
    end

    return {
        removed = removed_count,
        entries = removed_entries,
    }
end

return M
