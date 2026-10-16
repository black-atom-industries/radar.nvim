local persistence = require("radar.persist.persistence")

describe("persistence", function()
  local test_data_path = vim.fn.tempname() .. ".json"
  local test_config = {
    keys = require("radar.config").default.keys,
    recent = require("radar.config").default.recent,
    persist = {
      path = test_data_path,
    },
  }

  local function in_dir_with_branch(fn)
    local dir = vim.fn.tempname()
    vim.fn.mkdir(dir .. "/.git", "p")
    vim.fn.writefile({ "ref: refs/heads/main" }, dir .. "/.git/HEAD")
    local cwd = vim.uv.cwd()
    vim.uv.chdir(dir)
    local ok, err = pcall(fn, dir)
    vim.uv.chdir(cwd)
    vim.fn.delete(dir, "rf")
    assert(ok, err)
  end

  after_each(function()
    vim.fn.delete(test_data_path)
    vim.fn.delete(test_data_path .. ".bad")
  end)

  describe("deterministic JSON output", function()
    it("should produce identical output for identical data", function()
      -- Create test data
      local test_data = {
        version = 1,
        projects = {
          ["~/repos/project-a"] = {
            ["branch-1"] = {
              locks = {
                { filename = "file1.lua", label = "1" },
                { filename = "file2.lua", label = "2" },
              },
              lastAccessed = 1234567890,
            },
          },
          ["~/repos/project-b"] = {
            ["main"] = {
              locks = {
                { filename = "readme.md", label = "1" },
              },
              lastAccessed = 1234567891,
            },
          },
        },
      }

      -- Write data twice
      persistence.write(test_data_path, test_data)
      local first_output = vim.fn.readfile(test_data_path)

      persistence.write(test_data_path, test_data)
      local second_output = vim.fn.readfile(test_data_path)

      -- Compare line by line
      MiniTest.expect.equality(#first_output, #second_output)
      for i = 1, #first_output do
        MiniTest.expect.equality(first_output[i], second_output[i])
      end
    end)

    it("should have consistent property order in branch data", function()
      local test_data = {
        version = 1,
        projects = {
          ["~/repos/test"] = {
            ["main"] = {
              locks = {},
              lastAccessed = 1234567890,
            },
          },
        },
      }

      persistence.write(test_data_path, test_data)
      local lines = vim.fn.readfile(test_data_path)
      local content = table.concat(lines, "\n")

      -- Check that "lastAccessed" comes after "locks"
      local locks_pos = content:find('"locks"', 1, true)
      local accessed_pos = content:find('"lastAccessed"', 1, true)

      MiniTest.expect.equality(locks_pos ~= nil and locks_pos ~= false, true)
      MiniTest.expect.equality(accessed_pos ~= nil and accessed_pos ~= false, true)
      MiniTest.expect.equality(locks_pos < accessed_pos, true)
    end)

    it("should have consistent property order in lock objects", function()
      local test_data = {
        version = 1,
        projects = {
          ["~/repos/test"] = {
            ["main"] = {
              locks = {
                { filename = "test.lua", label = "1" },
              },
              lastAccessed = 1234567890,
            },
          },
        },
      }

      persistence.write(test_data_path, test_data)
      local lines = vim.fn.readfile(test_data_path)

      -- Find the lock object and check property order
      local found_filename = false
      local found_label = false
      local filename_line = 0
      local label_line = 0

      for i, line in ipairs(lines) do
        if line:find('"filename"', 1, true) then
          found_filename = true
          filename_line = i
        end
        if line:find('"label"', 1, true) and not found_label then
          found_label = true
          label_line = i
        end
      end

      MiniTest.expect.equality(
        found_filename ~= nil and found_filename ~= false,
        true
      )
      MiniTest.expect.equality(found_label ~= nil and found_label ~= false, true)
      MiniTest.expect.equality(filename_line < label_line, true)
    end)

    it("writes recent between locks and lastAccessed as an array", function()
      persistence.write(test_data_path, {
        version = 2,
        projects = {
          ["~/a"] = {
            main = { locks = {}, recent = { "x.lua", "y.lua" }, lastAccessed = 1 },
          },
          ["~/b"] = { main = { locks = {}, lastAccessed = 1 } },
        },
      })
      local content = table.concat(vim.fn.readfile(test_data_path), "\n")

      MiniTest.expect.equality(
        content:find(
          '"locks": [],\n        "recent": [\n          "x.lua",\n          "y.lua"\n        ],\n        "lastAccessed": 1',
          1,
          true
        ) ~= nil,
        true
      )
      MiniTest.expect.equality(
        content:find(
          '"locks": [],\n        "recent": [],\n        "lastAccessed": 1',
          1,
          true
        ) ~= nil,
        true
      )
    end)

    it("should keep projects in alphabetical order", function()
      local test_data = {
        version = 1,
        projects = {
          ["~/repos/zebra"] = { main = { locks = {}, lastAccessed = 1 } },
          ["~/repos/alpha"] = { main = { locks = {}, lastAccessed = 2 } },
          ["~/repos/beta"] = { main = { locks = {}, lastAccessed = 3 } },
        },
      }

      persistence.write(test_data_path, test_data)
      local lines = vim.fn.readfile(test_data_path)
      local content = table.concat(lines, "\n")

      -- Check alphabetical order
      local alpha_pos = content:find("~/repos/alpha", 1, true)
      local beta_pos = content:find("~/repos/beta", 1, true)
      local zebra_pos = content:find("~/repos/zebra", 1, true)

      MiniTest.expect.equality(alpha_pos ~= nil and alpha_pos ~= false, true)
      MiniTest.expect.equality(beta_pos ~= nil and beta_pos ~= false, true)
      MiniTest.expect.equality(zebra_pos ~= nil and zebra_pos ~= false, true)
      MiniTest.expect.equality(alpha_pos < beta_pos, true)
      MiniTest.expect.equality(beta_pos < zebra_pos, true)
    end)
  end)

  describe("safety", function()
    local function write_raw(path, content)
      vim.fn.writefile(vim.split(content, "\n"), path, "b")
    end

    local function with_notify(fn)
      local original = vim.notify
      local messages = {}
      vim.notify = function(msg, level)
        table.insert(messages, { msg = msg, level = level })
      end
      local ok, err = pcall(fn)
      vim.notify = original
      assert(ok, err)
      return messages
    end

    it("quarantines a corrupt file and warns once", function()
      write_raw(test_data_path, '{"version": 1, "projects": {')
      local result
      local messages = with_notify(function()
        result = persistence.load(test_config)
      end)

      MiniTest.expect.equality(result, nil)
      MiniTest.expect.equality(vim.uv.fs_stat(test_data_path), nil)
      MiniTest.expect.equality(vim.uv.fs_stat(test_data_path .. ".bad") ~= nil, true)
      MiniTest.expect.equality(#messages, 1)
      MiniTest.expect.equality(messages[1].level, vim.log.levels.WARN)
    end)

    it("quarantines valid JSON of the wrong shape", function()
      for _, content in ipairs({ "[1,2]", '{"a":5}', '{"version":1,"projects":5}' }) do
        write_raw(test_data_path, content)
        local result
        with_notify(function()
          result = persistence.load(test_config)
        end)

        MiniTest.expect.equality(result, nil)
        MiniTest.expect.equality(vim.uv.fs_stat(test_data_path), nil)
        MiniTest.expect.equality(
          vim.fn.readfile(test_data_path .. ".bad")[1],
          content
        )
      end
    end)

    it("overwrites an older .bad file", function()
      write_raw(test_data_path .. ".bad", "old")
      write_raw(test_data_path, "not json")
      with_notify(function()
        persistence.load(test_config)
      end)

      MiniTest.expect.equality(
        vim.fn.readfile(test_data_path .. ".bad")[1],
        "not json"
      )
    end)

    it("treats an empty file as missing without .bad", function()
      write_raw(test_data_path, "")
      local result
      local messages = with_notify(function()
        result = persistence.load(test_config)
      end)

      MiniTest.expect.equality(result, nil)
      MiniTest.expect.equality(#messages, 0)
      MiniTest.expect.equality(vim.uv.fs_stat(test_data_path .. ".bad"), nil)
    end)

    it("treats a missing file as nil without notifying", function()
      local result
      local messages = with_notify(function()
        result = persistence.load(test_config)
      end)

      MiniTest.expect.equality(result, nil)
      MiniTest.expect.equality(#messages, 0)
    end)

    it("keeps other projects' data in .bad and starts a fresh file", function()
      local corrupt = '{"version":1,"projects":{"~/other":{"main":{"locks":[]}}},'
      write_raw(test_data_path, corrupt)
      in_dir_with_branch(function()
        local state = require("radar.data.state")
        state.set_locks({ { label = "1", filename = "a.lua" } })
        with_notify(function()
          persistence.persist(test_config)
        end)
      end)

      MiniTest.expect.equality(vim.fn.readfile(test_data_path .. ".bad")[1], corrupt)
      local fresh =
        vim.json.decode(table.concat(vim.fn.readfile(test_data_path), "\n"))
      MiniTest.expect.equality(fresh.version, 2)
    end)

    it("aborts the save when the file cannot be quarantined", function()
      write_raw(test_data_path, "not json")
      vim.fn.mkdir(test_data_path .. ".bad", "p")
      write_raw(test_data_path .. ".bad/keep", "x")
      in_dir_with_branch(function()
        with_notify(function()
          MiniTest.expect.equality(persistence.persist(test_config), nil)
        end)
      end)

      MiniTest.expect.equality(vim.fn.readfile(test_data_path)[1], "not json")
      vim.fn.delete(test_data_path .. ".bad", "rf")
    end)

    it("writes atomically without leaving tmp files", function()
      local dir = vim.fn.tempname()
      vim.fn.mkdir(dir, "p")
      local path = dir .. "/data.json"
      local data = {
        version = 1,
        projects = {
          ["~/p"] = { main = { locks = {}, recent = {}, lastAccessed = 1 } },
        },
      }

      MiniTest.expect.equality(persistence.write(path, data), true)
      MiniTest.expect.equality(persistence.write(path, data), true)

      MiniTest.expect.equality(vim.fn.glob(dir .. "/*", false, true), { path })
      MiniTest.expect.equality(
        vim.json.decode(table.concat(vim.fn.readfile(path), "\n")),
        data
      )
      vim.fn.delete(dir, "rf")
    end)

    it("keeps in-memory locks on a detached HEAD in the same checkout", function()
      local state = require("radar.data.state")
      local locks = { { label = "1", filename = "a.lua" } }
      local empty = vim.json.encode({ version = 1, projects = {} })
      in_dir_with_branch(function(dir)
        with_notify(function()
          persistence.populate(test_config)
          state.set_locks(locks)
          write_raw(test_data_path, empty)
          vim.fn.writefile({ string.rep("a", 40) }, dir .. "/.git/HEAD")
          persistence.populate(test_config)
          MiniTest.expect.equality(persistence.persist(test_config), nil)
        end)
      end)

      MiniTest.expect.equality(state.get_locks(), locks)
      MiniTest.expect.equality(vim.fn.readfile(test_data_path)[1], empty)
    end)
  end)

  describe("Oil lock persistence", function()
    it("preserves Oil URLs when locks are reloaded", function()
      local state = require("radar.data.state")
      in_dir_with_branch(function(dir)
        local oil_url = "oil://" .. dir .. "/"
        state.set_locks({ { label = "1", filename = oil_url } })
        persistence.persist(test_config)
        state.set_locks({})
        persistence.populate(test_config)

        MiniTest.expect.equality(state.get_locks()[1].filename, oil_url)
      end)
    end)
  end)

  describe("deferred saves", function()
    it("never overwrite locks saved after their snapshot", function()
      local state = require("radar.data.state")
      in_dir_with_branch(function(dir)
        vim.fn.writefile({}, dir .. "/a.lua")
        vim.fn.writefile({}, dir .. "/b.lua")
        state.set_locks({ { label = "1", filename = "a.lua" } })
        local stale = persistence.snapshot()

        state.set_locks({ { label = "1", filename = "b.lua" } })
        persistence.persist(test_config)
        persistence.persist(test_config, stale)

        state.set_locks({})
        persistence.populate(test_config)
        MiniTest.expect.equality(state.get_locks(), {
          { label = "1", filename = "b.lua" },
        })
      end)
    end)

    it("keep the latest of two quick toggles", function()
      local state = require("radar.data.state")
      in_dir_with_branch(function(dir)
        vim.fn.writefile({}, dir .. "/a.lua")
        vim.fn.writefile({}, dir .. "/b.lua")
        state.set_locks({ { label = "1", filename = "a.lua" } })
        local first = persistence.snapshot()
        state.set_locks({
          { label = "1", filename = "a.lua" },
          { label = "2", filename = "b.lua" },
        })
        local second = persistence.snapshot()

        persistence.persist(test_config, first)
        persistence.persist(test_config, second)

        state.set_locks({})
        persistence.populate(test_config)
        MiniTest.expect.equality(#state.get_locks(), 2)
      end)
    end)
  end)

  describe("missing files", function()
    it("drops locks whose file is gone on load, relabels and saves", function()
      local state = require("radar.data.state")
      in_dir_with_branch(function(dir)
        vim.fn.writefile({}, dir .. "/kept.lua")
        state.set_locks({
          { label = "1", filename = "gone.lua" },
          { label = "2", filename = "oil:///no/such/dir/" },
          { label = "3", filename = "kept.lua" },
        })
        persistence.persist(test_config)
        state.set_locks({})
        persistence.populate(test_config)

        MiniTest.expect.equality(
          state.get_locks(),
          { { label = "1", filename = "kept.lua" } }
        )
        local saved =
          vim.json.decode(table.concat(vim.fn.readfile(test_data_path), "\n"))
        local project = vim.tbl_values(saved.projects)[1]
        MiniTest.expect.equality(#vim.tbl_get(project, "main", "locks"), 1)
      end)
    end)
  end)
end)
