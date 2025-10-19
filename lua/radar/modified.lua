local M = {}

---Get modified files (dummy data for UI development)
---@return string[]
function M.get_modified_files()
    -- TODO: Replace with real git integration
    -- This should eventually call: git status --porcelain
    return {
        "components/Header.tsx",
        "lib/utils.ts",
        "styles/globals.css",
    }
end

return M
