local M = {}

local config = nil

---Setup function called by lazy.nvim or manual setup
---@param opts? Radar.Config
---@return nil
function M.setup(opts)
    opts = opts or {}
    config = vim.tbl_deep_extend("force", require("radar.config").default, opts)

    require("radar.autocmd").setup(config)
    require("radar.keys").setup(config)
    require("radar.persistence").populate(config, require("radar.ui.radar"))

    -- Create user command
    vim.api.nvim_create_user_command("RadarCleanup", function(cmd_opts)
        local dry_run = false
        for _, arg in ipairs(cmd_opts.fargs) do
            if arg == "--dry-run" then
                dry_run = true
            end
        end

        M.cleanup({ dry_run = dry_run })
    end, {
        nargs = "*",
        desc = "Clean up stale radar persistence data. Use --dry-run to preview",
    })
end

---Clean up stale persistence data
---@param opts? { dry_run?: boolean }
---@return nil
function M.cleanup(opts)
    if not config then
        vim.notify("Radar not initialized. Call setup() first.", vim.log.levels.ERROR)
        return
    end

    opts = opts or {}
    local cleanup = require("radar.cleanup")
    local result = cleanup.cleanup(config, opts)

    if opts.dry_run then
        if result.removed == 0 then
            vim.notify("No stale entries found.", vim.log.levels.INFO)
        else
            local message = string.format("Would remove %d entries:\n%s", result.removed, table.concat(result.entries, "\n"))
            vim.notify(message, vim.log.levels.INFO)
        end
    else
        if result.removed == 0 then
            vim.notify("No stale entries found.", vim.log.levels.INFO)
        else
            local message = string.format("Removed %d stale entries.", result.removed)
            vim.notify(message, vim.log.levels.INFO)
        end
    end
end

return M
