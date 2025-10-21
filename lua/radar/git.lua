local M = {}

---Check if we're in a git repository
---@return boolean
local function is_git_repo()
  local result = vim.fn.system("git rev-parse --is-inside-work-tree 2>/dev/null")
  return vim.v.shell_error == 0
end

---Get file modification time
---@param filepath string
---@return number mtime (unix timestamp)
local function get_mtime(filepath)
  local stat = vim.loop.fs_stat(filepath)
  if stat then
    return stat.mtime.sec
  end
  return 0
end

---Get all git status files (modified, added, deleted, untracked, etc.)
---@return table[] List of {path: string, staged: string, unstaged: string} sorted by mtime
function M.get_git_status_files()
  if not is_git_repo() then
    return {}
  end

  -- Use git status --porcelain to get ALL changes including untracked files
  local result = vim.fn.systemlist("git status --porcelain 2>/dev/null")

  if vim.v.shell_error ~= 0 then
    return {}
  end

  local cwd = vim.fn.getcwd()
  local files_with_mtime = {}

  for _, line in ipairs(result) do
    if line ~= "" then
      -- Parse porcelain format: "XY PATH" or "XY PATH -> NEW_PATH" for renames
      -- X = staged status (index), Y = unstaged status (working tree)
      local staged = line:sub(1, 1)
      local unstaged = line:sub(2, 2)
      local filepath = line:sub(4):gsub(" %-> .*$", "") -- Remove rename target if present

      if filepath ~= "" then
        local abs_path = vim.fs.joinpath(cwd, filepath)
        local mtime = get_mtime(abs_path)

        table.insert(files_with_mtime, {
          path = abs_path,
          staged = staged,
          unstaged = unstaged,
          mtime = mtime,
        })
      end
    end
  end

  -- Sort by modification time (most recent first)
  table.sort(files_with_mtime, function(a, b)
    return a.mtime > b.mtime
  end)

  return files_with_mtime
end

---Get status for a specific file
---@param filepath string Absolute file path
---@return string staged Staged status
---@return string unstaged Unstaged status
local function get_file_status(filepath)
  local cwd = vim.fn.getcwd()
  local rel_path = vim.fn.fnamemodify(filepath, ":.")

  -- Get status for this specific file
  local result = vim.fn.system("git status --porcelain " .. vim.fn.shellescape(rel_path) .. " 2>/dev/null")

  if vim.v.shell_error == 0 and result ~= "" then
    local staged = result:sub(1, 1)
    local unstaged = result:sub(2, 2)
    return staged, unstaged
  end

  return " ", " "
end

---Get PR files using gh CLI or fallback to git diff
---@return table[] List of {path: string, staged: string, unstaged: string}
---@return boolean has_pr Whether an active PR exists
function M.get_pr_files()
  if not is_git_repo() then
    return {}, false
  end

  local file_paths = {}
  local has_pr = false

  -- Try gh CLI first with timeout
  local gh_available = vim.fn.executable("gh") == 1
  if gh_available then
    -- Use timeout to prevent blocking (2 second timeout)
    -- The '|| true' ensures the command doesn't fail on timeout
    local pr_result = vim.fn.system("timeout 2s gh pr view --json files -q '.files[].path' 2>/dev/null || true")

    -- Check if we got valid output (not timeout, not error)
    if vim.v.shell_error == 0 and pr_result ~= "" and not pr_result:match("^timeout:") then
      local cwd = vim.fn.getcwd()

      for file in pr_result:gmatch("[^\r\n]+") do
        if file ~= "" then
          table.insert(file_paths, vim.fs.joinpath(cwd, file))
        end
      end

      has_pr = true
    end
  end

  -- Fallback: try to find main/master branch and diff against it
  if #file_paths == 0 then
    local main_branch = vim.fn.system("git symbolic-ref refs/remotes/origin/HEAD 2>/dev/null | sed 's@^refs/remotes/origin/@@'")
    main_branch = vim.trim(main_branch)

    if main_branch == "" then
      -- Try common branch names
      for _, branch in ipairs({ "main", "master" }) do
        local check = vim.fn.system("git rev-parse --verify origin/" .. branch .. " 2>/dev/null")
        if vim.v.shell_error == 0 then
          main_branch = branch
          break
        end
      end
    end

    if main_branch ~= "" then
      -- Get files changed in current branch vs main
      local result = vim.fn.systemlist("git diff origin/" .. main_branch .. "...HEAD --name-only 2>/dev/null")

      if vim.v.shell_error == 0 then
        local cwd = vim.fn.getcwd()
        for _, file in ipairs(result) do
          if file ~= "" then
            table.insert(file_paths, vim.fs.joinpath(cwd, file))
          end
        end
      end
    end
  end

  -- Get status for each PR file
  local files_with_status = {}
  for _, filepath in ipairs(file_paths) do
    local staged, unstaged = get_file_status(filepath)
    table.insert(files_with_status, {
      path = filepath,
      staged = staged,
      unstaged = unstaged,
    })
  end

  return files_with_status, has_pr
end

---Get current HEAD commit hash
---@return string? commit_hash
function M.get_head_hash()
  if not is_git_repo() then
    return nil
  end

  local result = vim.fn.system("git rev-parse HEAD 2>/dev/null")
  if vim.v.shell_error == 0 and result ~= "" then
    return vim.trim(result)
  end

  return nil
end

---Fetch PR files asynchronously
---@param callback function Function to call with (files, has_pr) when done
function M.fetch_pr_async(callback)
  local state = require("radar.state")

  -- Mark as loading
  state.pr_cache.is_loading = true

  -- Use vim.system for async execution (Neovim 0.10+)
  -- Falls back to synchronous if vim.system is not available
  if vim.system then
    local cmd = { "timeout", "2s", "gh", "pr", "view", "--json", "files", "-q", ".files[].path" }

    vim.system(cmd, { text = true }, function(result)
      vim.schedule(function()
        local file_paths = {}
        local has_pr = false

        if result.code == 0 and result.stdout and result.stdout ~= "" then
          -- Parse gh output
          local cwd = vim.fn.getcwd()
          for file in result.stdout:gmatch("[^\r\n]+") do
            if file ~= "" then
              table.insert(file_paths, vim.fs.joinpath(cwd, file))
            end
          end
          has_pr = true
        else
          -- Fallback to git diff
          local fallback_files, fallback_has_pr = M.get_pr_files()
          callback(fallback_files, fallback_has_pr)
          return
        end

        -- Get status for each file
        local files_with_status = {}
        for _, filepath in ipairs(file_paths) do
          local staged, unstaged = get_file_status(filepath)
          table.insert(files_with_status, {
            path = filepath,
            staged = staged,
            unstaged = unstaged,
          })
        end

        callback(files_with_status, has_pr)
      end)
    end)
  else
    -- Fallback to synchronous for older Neovim versions
    local files, has_pr = M.get_pr_files()
    callback(files, has_pr)
  end
end

---Initialize PR cache on VimEnter
function M.init_pr_cache()
  local state = require("radar.state")

  if not is_git_repo() then
    state.pr_cache.is_loading = false
    return
  end

  -- Prevent double initialization (VimEnter + SessionLoadPost)
  if state.pr_cache.is_loading or state.pr_cache.commit_hash then
    return
  end

  M.fetch_pr_async(function(files, has_pr)
    state.pr_cache.files = files
    state.pr_cache.has_pr = has_pr
    state.pr_cache.commit_hash = M.get_head_hash()
    state.pr_cache.is_loading = false

    -- Notify user that PR data is ready
    if has_pr then
      vim.notify(string.format("PR data cached (%d files)", #files), vim.log.levels.INFO)
    else
      vim.notify("PR data cached (no active PR)", vim.log.levels.INFO)
    end

    -- Don't auto-update radar to avoid flicker
    -- User will see updated data on next natural update:
    -- - Navigating to another file (BufEnter)
    -- - Manually pressing 'r' to refresh
    -- - Closing and reopening radar
  end)
end

---Refresh PR cache (invalidate and refetch)
function M.refresh_pr_cache()
  local state = require("radar.state")

  -- Invalidate cache
  state.pr_cache.files = {}
  state.pr_cache.has_pr = false
  state.pr_cache.commit_hash = nil

  -- Refetch async
  M.init_pr_cache()
end

---Check if PR cache is valid (commit hash matches)
---@return boolean
function M.is_pr_cache_valid()
  local state = require("radar.state")

  if not state.pr_cache.commit_hash then
    return false
  end

  local current_hash = M.get_head_hash()
  return current_hash == state.pr_cache.commit_hash
end

---Update state with git file information
---@param config Radar.Config
function M.update_state(config)
  local state = require("radar.state")

  -- Modified files: always fetch fresh (it's fast)
  state.modified_files = M.get_git_status_files()

  -- PR files: use cache
  state.pr_files = state.pr_cache.files
  state.has_pr = state.pr_cache.has_pr
end

return M
