local M = {}

---Convert an Oil buffer name to its filesystem path
---@param filename string
---@return string
function M.to_filesystem_path(filename)
  if filename:match("^oil://") then
    return filename:sub(#"oil://" + 1)
  end

  return filename
end

---Check whether a buffer name is an Oil URL
---@param filename string
---@return boolean
function M.is_oil_url(filename)
  return filename:match("^oil://") ~= nil
end

---Check whether a name is a protocol URL (oil://, gh://, fugitive://, ...)
---@param name string
---@return boolean
function M.is_url(name)
  return name:match("^%w+://") ~= nil
end

---@param file string
---@return string?
local function read_file(file)
  local fd = vim.uv.fs_open(file, "r", 438)
  if not fd then
    return nil
  end
  local stat = vim.uv.fs_fstat(fd)
  local data = stat and vim.uv.fs_read(fd, stat.size, 0)
  vim.uv.fs_close(fd)
  return data or nil
end

---Find the git checkout containing `dir`: walk up to the first `.git`
---(directory, or file pointing to the gitdir in worktrees and submodules).
---@param dir? string defaults to the cwd
---@return { root: string, head: string? }?
function M.git_info(dir)
  dir = dir or vim.uv.cwd()
  if not dir then
    return nil
  end
  dir = dir:gsub("(.)/+$", "%1")

  while true do
    local dot_git = dir .. "/.git"
    local stat = vim.uv.fs_stat(dot_git)
    if stat and stat.type == "directory" then
      return { root = dir, head = dot_git .. "/HEAD" }
    elseif stat and stat.type == "file" then
      local gitdir = (read_file(dot_git) or ""):match("^gitdir:%s*(.-)%s*$")
      if gitdir and not vim.startswith(gitdir, "/") then
        gitdir = vim.fs.normalize(vim.fs.joinpath(dir, gitdir))
      end
      return { root = dir, head = gitdir and gitdir .. "/HEAD" }
    end
    local parent = vim.fn.fnamemodify(dir, ":h")
    if parent == dir then
      return nil
    end
    dir = parent
  end
end

---Read the branch checked out in a git checkout
---@param info? { root: string, head: string? }
---@return string? nil for detached HEAD or missing info
function M.git_branch(info)
  local data = info and info.head and read_file(info.head)
  return data and data:match("ref: refs/heads/([^\n]+)") or nil
end

---Project root: the git root containing the cwd, or the cwd outside git
---@return string?
function M.project_root()
  local info = M.git_info()
  if info then
    return info.root
  end
  local cwd = vim.uv.cwd()
  return cwd and (cwd:gsub("(.)/+$", "%1"))
end

---Resolve a lock path (relative to the project root) or any path to an
---absolute path. URLs are returned unchanged.
---@param name string
---@return string
function M.to_absolute(name)
  if M.is_url(name) then
    return name
  end
  if not vim.startswith(name, "/") and not vim.startswith(name, "~") then
    name = (M.project_root() or ".") .. "/" .. name
  end
  return vim.fn.fnamemodify(name, ":p")
end

---Return `abs` relative to `root`, or nil when it lies outside
---@param abs string
---@param root string
---@return string?
function M.relative_to(abs, root)
  local relative
  if root == "/" then
    relative = abs:sub(2)
  elseif vim.startswith(abs, root .. "/") then
    relative = abs:sub(#root + 2)
  elseif abs == root then
    relative = ""
  end
  return relative == "" and "." or relative
end

---Canonical lock filename: relative to the project root when inside it,
---absolute otherwise. URLs are returned unchanged.
---@param name string
---@return string
function M.to_lock_path(name)
  if M.is_url(name) then
    return name
  end
  local abs = M.to_absolute(name)
  local root = M.project_root()
  return root and M.relative_to(abs, root) or abs
end

---Format a lock filename, path or URL for display: relative to the project
---root when inside it. Oil directories end with a slash, `./` for the root.
---@param name string
---@return string
function M.display(name)
  if M.is_oil_url(name) then
    local relative = M.to_lock_path(M.to_filesystem_path(name)):gsub("/+$", "")
    if relative == "" or relative == "." then
      return "./"
    end
    return relative .. "/"
  end
  if M.is_url(name) then
    return name
  end
  local relative = M.to_lock_path(name)
  return relative == "." and "./" or relative
end

return M
