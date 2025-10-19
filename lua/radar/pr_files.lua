local M = {}

---Get PR files (dummy data for UI development)
---@return string[]
function M.get_pr_files()
    -- TODO: Replace with real git integration
    -- This should eventually call: git diff --name-only main...HEAD
    return {
        "features/auth.tsx",
        "features/auth.test.tsx",
        "api/auth.routes.ts",
    }
end

return M
