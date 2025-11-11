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

---Clean up stale persistence data
---@param config Radar.Config
---@param opts? { dry_run?: boolean }
---@return { removed: number, entries: string[] }
function M.cleanup(config, opts)
    opts = opts or {}
    local dry_run = opts.dry_run or false

    local persistence = require("radar.persistence")
    local data = persistence.load(config)

    if not data then
        return { removed = 0, entries = {} }
    end

    local current_project = persistence.get_project_path()
    local current_branch = persistence.get_git_branch()

    local new_data = {}
    local removed_count = 0
    local removed_entries = {}

    for project_path, branches in pairs(data) do
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
                new_data[project_path] = branches
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

                    if should_preserve or branch_exists then
                        project_new_data[branch_name] = branch_data
                    else
                        removed_count = removed_count + 1
                        table.insert(removed_entries, string.format("%s [%s]", project_path, branch_name))
                    end
                end

                -- Only keep project if it has branches
                if vim.tbl_count(project_new_data) > 0 then
                    new_data[project_path] = project_new_data
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
