local path = require("radar.path")
local state = require("radar.data.state")
local locks = require("radar.data.locks")
local persistence = require("radar.persist.persistence")
local migration = require("radar.persist.migration")
local cleanup = require("radar.persist.cleanup")
local config = require("radar.config")

local function git(dir, ...)
  local cmd = {
    "git",
    "-C",
    dir,
    "-c",
    "user.name=t",
    "-c",
    "user.email=t@t",
    "-c",
    "commit.gpgsign=false",
  }
  local result = vim
    .system(vim.list_extend(cmd, { ... }), {
      env = { GIT_CONFIG_GLOBAL = "/dev/null", GIT_CONFIG_NOSYSTEM = "1" },
    })
    :wait()
  assert(result.code == 0, result.stderr)
end

local function temp_dir()
  local dir = vim.fn.tempname()
  vim.fn.mkdir(dir, "p")
  return assert(vim.uv.fs_realpath(dir))
end

---Git repo with a commit on `main`, a.lua and src/b.lua
local function make_repo()
  local root = temp_dir()
  git(root, "init", "-q", "-b", "main")
  git(root, "commit", "-q", "--allow-empty", "-m", "init")
  vim.fn.mkdir(root .. "/src", "p")
  vim.fn.writefile({}, root .. "/a.lua")
  vim.fn.writefile({}, root .. "/src/b.lua")
  return root
end

describe("project identity", function()
  local test_config, original_cwd, dirs

  before_each(function()
    test_config = vim.deepcopy(config.default)
    test_config.persist.path = vim.fn.tempname() .. ".json"
    original_cwd = vim.uv.cwd()
    dirs = {}
    state.set_locks({})
  end)

  after_each(function()
    vim.uv.chdir(original_cwd)
    for _, dir in ipairs(dirs) do
      vim.fn.delete(dir, "rf")
    end
    vim.fn.delete(test_config.persist.path)
  end)

  local function repo()
    local root = make_repo()
    table.insert(dirs, root)
    return root
  end

  describe("path helpers", function()
    it("detects protocol URLs", function()
      MiniTest.expect.equality(path.is_url("oil:///tmp/"), true)
      MiniTest.expect.equality(path.is_url("gh://owner/repo"), true)
      MiniTest.expect.equality(path.is_url("/tmp/a.lua"), false)
      MiniTest.expect.equality(path.is_url("src/a.lua"), false)
    end)

    it("finds the git root and branch from a subdirectory", function()
      local root = repo()
      vim.uv.chdir(root .. "/src")

      MiniTest.expect.equality(path.project_root(), root)
      MiniTest.expect.equality(path.git_info().head, root .. "/.git/HEAD")
      MiniTest.expect.equality(path.git_branch(path.git_info()), "main")
    end)

    it("follows a .git file and keeps the raw branch name", function()
      local root = temp_dir()
      local gitdir = temp_dir()
      table.insert(dirs, root)
      table.insert(dirs, gitdir)
      vim.fn.writefile({ "gitdir: " .. gitdir }, root .. "/.git")
      vim.fn.writefile({ "ref: refs/heads/feat#1" }, gitdir .. "/HEAD")
      vim.fn.mkdir(root .. "/deep/er", "p")
      vim.uv.chdir(root .. "/deep/er")

      MiniTest.expect.equality(path.project_root(), root)
      MiniTest.expect.equality(persistence.get_git_branch(), "feat#1")
      MiniTest.expect.equality(persistence.get_project_path(), root)
    end)

    it("falls back to the cwd outside git", function()
      local dir = temp_dir()
      table.insert(dirs, dir)
      vim.uv.chdir(dir)

      MiniTest.expect.equality(path.project_root(), dir)
      MiniTest.expect.equality(persistence.get_git_branch(), nil)
    end)

    it("converts between lock paths and absolute paths from any cwd", function()
      local root = repo()
      vim.uv.chdir(root .. "/src")

      MiniTest.expect.equality(path.to_lock_path(root .. "/src/b.lua"), "src/b.lua")
      MiniTest.expect.equality(path.to_lock_path("src/b.lua"), "src/b.lua")
      MiniTest.expect.equality(path.to_absolute("src/b.lua"), root .. "/src/b.lua")
      MiniTest.expect.equality(
        path.to_lock_path("/elsewhere/x.lua"),
        "/elsewhere/x.lua"
      )
      MiniTest.expect.equality(path.to_lock_path("gh://o/r/a.lua"), "gh://o/r/a.lua")
      MiniTest.expect.equality(path.to_absolute("oil:///x/"), "oil:///x/")
    end)

    it("displays paths relative to the project root", function()
      local root = repo()
      vim.uv.chdir(root .. "/src")

      MiniTest.expect.equality(path.display("a.lua"), "a.lua")
      MiniTest.expect.equality(path.to_lock_path(root), ".")
      MiniTest.expect.equality(path.display(root), "./")
      MiniTest.expect.equality(path.display(root .. "/src/b.lua"), "src/b.lua")
      MiniTest.expect.equality(path.display("oil://" .. root .. "/"), "./")
      MiniTest.expect.equality(path.display("oil://" .. root .. "/src/"), "src/")
    end)
  end)

  describe("locks", function()
    local radar_mock = {
      exists = function()
        return true
      end,
      update = function() end,
    }
    local persistence_mock = {
      persist = function() end,
      populate_if_changed = function() end,
    }

    it(
      "stores locks root-relative and toggles the same lock from any cwd",
      function()
        local root = repo()
        vim.cmd.edit(vim.fn.fnameescape(root .. "/src/b.lua"))
        local buf = vim.api.nvim_get_current_buf()

        vim.uv.chdir(root .. "/src")
        locks.lock_current_buffer(buf, test_config, persistence_mock, radar_mock)
        MiniTest.expect.equality(state.get_locks()[1].filename, "src/b.lua")

        vim.uv.chdir(root)
        locks.lock_current_buffer(buf, test_config, persistence_mock, radar_mock)
        MiniTest.expect.equality(#state.get_locks(), 0)

        vim.cmd("bwipeout! " .. buf)
      end
    )

    it("persists under the git root key from a subdirectory", function()
      local root = repo()
      vim.uv.chdir(root .. "/src")
      state.set_locks({ { label = "1", filename = "src/b.lua" } })

      local data = persistence.persist(test_config)

      MiniTest.expect.equality(vim.tbl_keys(data.projects), { root })
      MiniTest.expect.equality(
        data.projects[root].main.locks[1].filename,
        "src/b.lua"
      )
    end)
  end)

  describe("deferred persist", function()
    it("saves a toggle under the project it was made in", function()
      local root = repo()
      local other = repo()
      test_config.persist.defer_ms = 1
      vim.uv.chdir(root)
      persistence.populate(test_config)

      locks.toggle("a.lua", test_config, persistence)
      vim.uv.chdir(other)
      persistence.populate(test_config)
      vim.wait(500, function()
        return persistence.read(test_config.persist.path) ~= nil
      end)

      local data = persistence.read(test_config.persist.path)
      MiniTest.expect.equality(
        data.projects[root].main.locks,
        { { label = "1", filename = "a.lua" } }
      )
      MiniTest.expect.equality(data.projects[other], nil)
    end)

    it("toggles against the branch checked out outside Neovim", function()
      local root = repo()
      test_config.persist.defer_ms = 1
      persistence.write(test_config.persist.path, {
        version = 2,
        projects = {
          [root] = {
            main = {
              locks = { { label = "1", filename = "a.lua" } },
              lastAccessed = 1,
            },
            feat = {
              locks = { { label = "1", filename = "src/b.lua" } },
              lastAccessed = 1,
            },
          },
        },
      })
      vim.uv.chdir(root)
      persistence.populate(test_config)
      git(root, "switch", "-q", "-c", "feat")
      vim.cmd.edit(vim.fn.fnameescape(root .. "/a.lua"))
      local buf = vim.api.nvim_get_current_buf()

      locks.lock_current_buffer(buf, test_config, persistence, {
        exists = function()
          return true
        end,
        update = function() end,
      })
      vim.wait(500, function()
        return #persistence.read(test_config.persist.path).projects[root].feat.locks
          == 2
      end)

      local data = persistence.read(test_config.persist.path)
      local function filenames(branch)
        return vim.tbl_map(function(lock)
          return lock.filename
        end, data.projects[root][branch].locks)
      end
      MiniTest.expect.equality(filenames("feat"), { "src/b.lua", "a.lua" })
      MiniTest.expect.equality(filenames("main"), { "a.lua" })
      vim.cmd("bwipeout! " .. buf)
    end)
  end)

  describe("edit", function()
    it("saves typed paths containing $ literally", function()
      local root = repo()
      vim.fn.mkdir(root .. "/lua", "p")
      vim.fn.writefile({}, root .. "/lua/posts.$postId.tsx")
      vim.uv.chdir(root)
      local buf = vim.api.nvim_create_buf(false, true)
      vim.api.nvim_buf_set_lines(buf, 0, -1, false, { "lua/posts.$postId.tsx" })

      require("radar.ui.edit").save_buffer(buf, test_config, {
        update = function() end,
      })

      MiniTest.expect.equality(
        state.get_locks(),
        { { label = "1", filename = "lua/posts.$postId.tsx" } }
      )
      vim.api.nvim_buf_delete(buf, { force = true })
    end)
  end)

  describe("populate", function()
    it("clears locks when leaving a repo for a non-git directory", function()
      local root = repo()
      local plain = temp_dir()
      table.insert(dirs, plain)
      persistence.write(test_config.persist.path, {
        version = 2,
        projects = {
          [root] = {
            main = {
              locks = { { label = "1", filename = "a.lua" } },
              lastAccessed = 1,
            },
          },
        },
      })

      vim.uv.chdir(root)
      persistence.populate(test_config)
      MiniTest.expect.equality(#state.get_locks(), 1)

      vim.uv.chdir(plain)
      persistence.populate(test_config)
      MiniTest.expect.equality(state.get_locks(), {})
    end)

    it("clears locks on a project switch without a data file", function()
      local root = repo()
      local other = repo()
      vim.uv.chdir(root)
      state.set_locks({ { label = "1", filename = "a.lua" } })
      persistence.persist(test_config)
      vim.fn.delete(test_config.persist.path)

      vim.uv.chdir(other)
      persistence.populate(test_config)

      MiniTest.expect.equality(state.get_locks(), {})
    end)
  end)

  describe("DirChanged", function()
    after_each(function()
      for _, group in ipairs({
        "radar.VimEnter",
        "radar.VimResized",
        "radar.BufEnter",
        "radar.DirChanged",
        "radar.FocusGained",
        "radar.TabsUpdate",
      }) do
        pcall(vim.api.nvim_del_augroup_by_name, group)
      end
    end)

    it("keeps locks within the repo and reloads in another repo", function()
      local root = repo()
      local other = repo()
      persistence.write(test_config.persist.path, {
        version = 2,
        projects = {
          [root] = {
            main = {
              locks = { { label = "1", filename = "a.lua" } },
              lastAccessed = 1,
            },
          },
        },
      })
      require("radar.autocmd").setup(test_config)

      vim.cmd.cd(vim.fn.fnameescape(root))
      persistence.populate(test_config)
      MiniTest.expect.equality(#state.get_locks(), 1)

      locks.add("src/b.lua", test_config)
      vim.cmd.cd("src")
      MiniTest.expect.equality(#state.get_locks(), 2)

      vim.cmd.cd(vim.fn.fnameescape(other))
      MiniTest.expect.equality(state.get_locks(), {})
    end)
  end)

  describe("recent history", function()
    local recent = require("radar.data.recent")
    local original_oldfiles

    before_each(function()
      state.set_session_files({})
      state.set_history({})
      original_oldfiles = vim.v.oldfiles
      vim.v.oldfiles = {}
    end)

    after_each(function()
      state.set_session_files({})
      state.set_history({})
      vim.v.oldfiles = original_oldfiles
    end)

    local function write_data(root, branch_data)
      persistence.write(test_config.persist.path, {
        version = 2,
        projects = { [root] = { main = branch_data } },
      })
    end

    it("saves session files root-relative and reloads them as history", function()
      local root = repo()
      vim.uv.chdir(root)
      state.set_session_files({
        root .. "/a.lua",
        "/elsewhere/x.lua",
        root .. "/src/b.lua",
      })

      persistence.persist(test_config, persistence.snapshot())
      state.set_session_files({})
      persistence.populate(test_config)

      MiniTest.expect.equality(
        persistence.read(test_config.persist.path).projects[root].main.recent,
        { "src/b.lua", "a.lua" }
      )
      MiniTest.expect.equality(
        state.get_history(),
        { root .. "/src/b.lua", root .. "/a.lua" }
      )
    end)

    it("keeps Oil URLs unchanged", function()
      local root = repo()
      vim.uv.chdir(root)
      local oil_url = "oil://" .. root .. "/src/"
      state.set_session_files({ oil_url })

      persistence.persist(test_config, persistence.snapshot())
      persistence.populate(test_config)

      MiniTest.expect.equality(state.get_history(), { oil_url })
    end)

    it("lists session files, then history, then oldfiles", function()
      local root = repo()
      vim.fn.writefile({}, root .. "/c.lua")
      vim.fn.writefile({}, root .. "/d.lua")
      write_data(
        root,
        { locks = {}, recent = { "src/b.lua", "a.lua" }, lastAccessed = 1 }
      )
      vim.uv.chdir(root)
      persistence.populate(test_config)
      state.set_session_files({ root .. "/c.lua" })
      vim.v.oldfiles = { root .. "/a.lua", root .. "/d.lua" }

      MiniTest.expect.equality(recent.get_files(test_config), {
        root .. "/c.lua",
        root .. "/src/b.lua",
        root .. "/a.lua",
        root .. "/d.lua",
      })
    end)

    it("merges session files in front of the saved history, capped", function()
      local root = repo()
      vim.fn.writefile({}, root .. "/c.lua")
      write_data(
        root,
        { locks = {}, recent = { "src/b.lua", "a.lua" }, lastAccessed = 1 }
      )
      vim.uv.chdir(root)
      test_config.recent.max_files = 2

      persistence.persist(test_config)
      MiniTest.expect.equality(
        persistence.read(test_config.persist.path).projects[root].main.recent,
        { "src/b.lua", "a.lua" }
      )

      state.set_session_files({ root .. "/c.lua" })
      persistence.persist(test_config, persistence.snapshot())
      MiniTest.expect.equality(
        persistence.read(test_config.persist.path).projects[root].main.recent,
        { "c.lua", "src/b.lua" }
      )
    end)

    it("keeps the saved locks when saving the history", function()
      local root = repo()
      write_data(root, {
        locks = { { label = "1", filename = "a.lua" } },
        recent = { "src/b.lua" },
        lastAccessed = 1,
      })
      vim.uv.chdir(root)
      state.set_session_files({ root .. "/a.lua" })

      persistence.persist(test_config, persistence.recent_snapshot())

      local main = persistence.read(test_config.persist.path).projects[root].main
      MiniTest.expect.equality(main.locks, { { label = "1", filename = "a.lua" } })
      MiniTest.expect.equality(main.recent, { "a.lua", "src/b.lua" })
    end)

    it("drops missing files on load and saves", function()
      local root = repo()
      write_data(
        root,
        { locks = {}, recent = { "gone.lua", "a.lua" }, lastAccessed = 1 }
      )
      vim.uv.chdir(root)

      persistence.populate(test_config)

      MiniTest.expect.equality(state.get_history(), { root .. "/a.lua" })
      MiniTest.expect.equality(
        persistence.read(test_config.persist.path).projects[root].main.recent,
        { "a.lua" }
      )
    end)

    it("loads data without a recent list", function()
      local root = repo()
      vim.fn.writefile({
        vim.json.encode({
          version = 2,
          projects = {
            [root] = {
              main = {
                locks = { { label = "1", filename = "a.lua" } },
                lastAccessed = 1,
              },
            },
          },
        }),
      }, test_config.persist.path)
      vim.uv.chdir(root)

      persistence.populate(test_config)

      MiniTest.expect.equality(#state.get_locks(), 1)
      MiniTest.expect.equality(state.get_history(), {})
      local main = persistence.read(test_config.persist.path).projects[root].main
      MiniTest.expect.equality(main.recent, {})
      MiniTest.expect.equality(#main.locks, 1)
    end)

    it("saves an opened file under the project it was opened in", function()
      local root = repo()
      local other = repo()
      test_config.persist.defer_ms = 50
      require("radar.autocmd").setup(test_config)
      vim.cmd.cd(vim.fn.fnameescape(root))
      persistence.populate(test_config)

      vim.cmd.edit(vim.fn.fnameescape(root .. "/a.lua"))
      local buf = vim.api.nvim_get_current_buf()
      vim.cmd.cd(vim.fn.fnameescape(other))
      vim.wait(1000, function()
        local data = persistence.read(test_config.persist.path)
        return data ~= nil and data.projects[root] ~= nil
      end)

      local data = persistence.read(test_config.persist.path)
      MiniTest.expect.equality(data.projects[root].main.recent, { "a.lua" })
      MiniTest.expect.equality(data.projects[other], nil)
      vim.cmd("bwipeout! " .. buf)
      for _, group in ipairs({
        "radar.VimEnter",
        "radar.VimResized",
        "radar.BufEnter",
        "radar.DirChanged",
        "radar.FocusGained",
        "radar.TabsUpdate",
      }) do
        pcall(vim.api.nvim_del_augroup_by_name, group)
      end
    end)
  end)

  describe("migration v1 to v2", function()
    it("unescapes project and branch keys", function()
      local key = vim.fn.fnameescape("/missing dir/x#1")
      local result = migration.migrate({
        version = 1,
        projects = {
          [key] = {
            [vim.fn.fnameescape("feat#1")] = { locks = {}, lastAccessed = 1 },
          },
        },
      })

      MiniTest.expect.equality(result, {
        version = 2,
        projects = {
          ["/missing dir/x#1"] = { ["feat#1"] = { locks = {}, lastAccessed = 1 } },
        },
      })
    end)

    it("merges subdirectory projects into the git root", function()
      local root = repo()
      local result = migration.migrate({
        version = 1,
        projects = {
          [vim.fn.fnameescape(root)] = {
            main = {
              locks = {
                { label = "1", filename = "a.lua" },
                { label = "2", filename = "src/b.lua" },
              },
              lastAccessed = 1,
            },
          },
          [vim.fn.fnameescape(root .. "/src")] = {
            main = {
              locks = {
                { label = "1", filename = "b.lua" },
                { label = "2", filename = "c.lua" },
                { label = "3", filename = root .. "/a.lua" },
                { label = "4", filename = "oil:///x/" },
              },
              lastAccessed = 5,
            },
            feat = {
              locks = { { label = "1", filename = "d.lua" } },
              lastAccessed = 3,
            },
          },
        },
      })

      MiniTest.expect.equality(vim.tbl_keys(result.projects), { root })
      local filenames = vim.tbl_map(function(lock)
        return lock.filename
      end, result.projects[root].main.locks)
      MiniTest.expect.equality(
        filenames,
        { "a.lua", "src/b.lua", "src/c.lua", "oil:///x/" }
      )
      MiniTest.expect.equality(result.projects[root].main.lastAccessed, 5)
      MiniTest.expect.equality(
        result.projects[root].feat.locks[1].filename,
        "src/d.lua"
      )

      MiniTest.expect.equality(migration.migrate(vim.deepcopy(result)), result)
    end)

    it("leaves projects whose directory no longer exists untouched", function()
      local data = {
        ["/missing/repo/sub"] = {
          main = {
            locks = { { label = "1", filename = "x.lua" } },
            lastAccessed = 2,
          },
        },
      }
      local result =
        migration.migrate({ version = 1, projects = vim.deepcopy(data) })

      MiniTest.expect.equality(result.projects, data)
    end)
  end)

  describe("cleanup", function()
    it("keeps branches and projects whose names contain #", function()
      local root = repo() .. "/repo#1"
      vim.fn.mkdir(root, "p")
      git(root, "init", "-q", "-b", "main")
      git(root, "commit", "-q", "--allow-empty", "-m", "init")
      git(root, "checkout", "-q", "-b", "feat#1")
      vim.uv.chdir(root)
      state.set_locks({ { label = "1", filename = "a.lua" } })
      persistence.persist(test_config)
      git(root, "checkout", "-q", "main")
      persistence.persist(test_config)
      local data = persistence.read(test_config.persist.path)
      data.projects[root].gone = data.projects[root].main
      persistence.write(test_config.persist.path, data)

      local elsewhere = temp_dir()
      table.insert(dirs, elsewhere)
      vim.uv.chdir(elsewhere)

      local result = cleanup.cleanup(test_config)

      MiniTest.expect.equality(result.removed, 1)
      data = persistence.read(test_config.persist.path)
      local branches = vim.tbl_keys(data.projects[root])
      table.sort(branches)
      MiniTest.expect.equality(branches, { "feat#1", "main" })
    end)
  end)
end)
