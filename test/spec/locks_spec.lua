local locks = require("radar.data.locks")
local state = require("radar.data.state")
local config = require("radar.config")

describe("locks", function()
  local test_config

  local function setup_test_state()
    test_config = vim.deepcopy(config.default)
    state.set_locks({})
  end

  describe("get_next_unused_label", function()
    before_each(setup_test_state)

    it("returns first label when no locks exist", function()
      local label = locks.get_next_unused_label(test_config)
      MiniTest.expect.equality(label, "a")
    end)

    it("skips used labels and returns next available", function()
      -- Add some locks
      state.set_locks({
        { label = "a", filename = "file1.lua" },
        { label = "d", filename = "file3.lua" },
      })

      local label = locks.get_next_unused_label(test_config)
      MiniTest.expect.equality(label, "s")
    end)

    it("returns labels in order defined in config", function()
      -- Fill up first few slots
      for i = 1, 3 do
        table.insert(
          state.get_locks(),
          { label = test_config.keys.locks[i], filename = "file" .. i .. ".lua" }
        )
      end

      local label = locks.get_next_unused_label(test_config)
      MiniTest.expect.equality(label, "f")
    end)

    it("throws error when all slots are used", function()
      -- Fill up all lock slots
      for _, label in ipairs(test_config.keys.locks) do
        table.insert(
          state.get_locks(),
          { label = label, filename = "file_" .. label .. ".lua" }
        )
      end

      MiniTest.expect.error(function()
        locks.get_next_unused_label(test_config)
      end, "No more lock slots available")
    end)
  end)

  describe("add", function()
    before_each(setup_test_state)

    it("creates lock with correct structure", function()
      local lock = locks.add("test.lua", test_config)

      MiniTest.expect.equality(type(lock), "table")
      MiniTest.expect.equality(lock.label, "a")
      MiniTest.expect.equality(lock.filename, "test.lua")
    end)

    it("adds lock to state.get_locks()", function()
      MiniTest.expect.equality(#state.get_locks(), 0)

      locks.add("test.lua", test_config)

      MiniTest.expect.equality(#state.get_locks(), 1)
      MiniTest.expect.equality(state.get_locks()[1].filename, "test.lua")
    end)

    it("assigns unique labels for multiple locks", function()
      local lock1 = locks.add("file1.lua", test_config)
      local lock2 = locks.add("file2.lua", test_config)

      MiniTest.expect.equality(lock1.label, "a")
      MiniTest.expect.equality(lock2.label, "s")
      MiniTest.expect.equality(#state.get_locks(), 2)
    end)
  end)

  describe("remove", function()
    before_each(setup_test_state)

    it("removes lock by filename", function()
      locks.add("file1.lua", test_config)
      locks.add("file2.lua", test_config)
      MiniTest.expect.equality(#state.get_locks(), 2)

      local removed = locks.remove("file1.lua", test_config)

      MiniTest.expect.equality(#state.get_locks(), 1)
      MiniTest.expect.equality(removed.filename, "file1.lua")
      MiniTest.expect.equality(state.get_locks()[1].filename, "file2.lua")
    end)

    it("relabels remaining locks by position", function()
      locks.add("a.lua", test_config)
      locks.add("b.lua", test_config)
      locks.add("c.lua", test_config)

      locks.remove("a.lua", test_config)

      local labels = vim.tbl_map(function(lock)
        return lock.label .. ":" .. lock.filename
      end, state.get_locks())
      MiniTest.expect.equality(labels, { "a:b.lua", "s:c.lua" })
    end)

    it("relabels from configured keys", function()
      test_config.keys.locks = { "x", "y", "z" }
      locks.add("a.lua", test_config)
      locks.add("b.lua", test_config)
      locks.add("c.lua", test_config)

      locks.remove("b.lua", test_config)

      MiniTest.expect.equality(state.get_locks()[1].label, "x")
      MiniTest.expect.equality(state.get_locks()[2].label, "y")
    end)

    it("returns nil when file not found", function()
      locks.add("existing.lua", test_config)

      local removed = locks.remove("nonexistent.lua", test_config)

      MiniTest.expect.equality(removed, nil)
      MiniTest.expect.equality(#state.get_locks(), 1)
    end)

    it("handles empty state gracefully", function()
      local removed = locks.remove("nonexistent.lua", test_config)
      MiniTest.expect.equality(removed, nil)
    end)
  end)

  describe("relabel", function()
    it("labels by position and falls back to the index past the keys", function()
      test_config = vim.deepcopy(config.default)
      test_config.keys.locks = { "a", "b" }
      local list = {
        { label = "9", filename = "1.lua" },
        { label = "9", filename = "2.lua" },
        { label = "9", filename = "3.lua" },
      }

      locks.relabel(list, test_config)

      MiniTest.expect.equality(
        { list[1].label, list[2].label, list[3].label },
        { "a", "b", "3" }
      )
    end)
  end)

  describe("toggle", function()
    local mock_persistence

    before_each(function()
      setup_test_state()
      mock_persistence = { persist = function() end }
    end)

    it("adds lock when file not locked", function()
      local lock = locks.toggle("new.lua", test_config, mock_persistence)

      MiniTest.expect.equality(#state.get_locks(), 1)
      MiniTest.expect.equality(lock.filename, "new.lua")
      MiniTest.expect.equality(lock.label, "a")
    end)

    it("removes lock when file is locked", function()
      -- Add a lock first
      locks.add("existing.lua", test_config)
      MiniTest.expect.equality(#state.get_locks(), 1)

      local removed_lock =
        locks.toggle("existing.lua", test_config, mock_persistence)

      MiniTest.expect.equality(#state.get_locks(), 0)
      MiniTest.expect.equality(removed_lock.filename, "existing.lua")
    end)

    it("warns instead of locking when all slots are used", function()
      for _, label in ipairs(test_config.keys.locks) do
        locks.add("file_" .. label .. ".lua", test_config)
      end
      local original_notify = vim.notify
      local level
      vim.notify = function(_, lvl)
        level = lvl
      end

      local lock = locks.toggle("new.lua", test_config, mock_persistence)
      vim.notify = original_notify

      MiniTest.expect.equality(lock, nil)
      MiniTest.expect.equality(level, vim.log.levels.WARN)
      MiniTest.expect.equality(#state.get_locks(), #test_config.keys.locks)
    end)

    it("still unlocks when all slots are used", function()
      for _, label in ipairs(test_config.keys.locks) do
        locks.add("file_" .. label .. ".lua", test_config)
      end

      locks.toggle("file_a.lua", test_config, mock_persistence)

      MiniTest.expect.equality(#state.get_locks(), #test_config.keys.locks - 1)
    end)
  end)

  describe("lock_current_buffer", function()
    local mock_persistence
    local original_api

    before_each(function()
      setup_test_state()
      mock_persistence = {
        persist = function() end,
        populate_if_changed = function() end,
      }
      -- Mock vim.api functions
      original_api = {
        nvim_get_current_buf = vim.api.nvim_get_current_buf,
        nvim_buf_get_name = vim.api.nvim_buf_get_name,
      }
      vim.api.nvim_get_current_buf = function()
        return 1
      end
      vim.api.nvim_buf_get_name = function()
        return "/test/path/file.lua"
      end
    end)

    after_each(function()
      vim.api.nvim_get_current_buf = original_api.nvim_get_current_buf
      vim.api.nvim_buf_get_name = original_api.nvim_buf_get_name
    end)

    it("uses current buffer when buf_nr is nil", function()
      locks.lock_current_buffer(nil, test_config, mock_persistence)

      MiniTest.expect.equality(#state.get_locks(), 1)
      -- Should use normalized filename (relative to cwd)
      MiniTest.expect.equality(
        state.get_locks()[1].filename,
        vim.fn.fnamemodify("/test/path/file.lua", ":p:.")
      )
    end)

    it("preserves Oil and other protocol URLs as lock names", function()
      for _, filename in ipairs({
        "oil:///test/project/",
        "gh://owner/repo/blob/main/file.lua",
        "fugitive:///test/project/.git/index",
      }) do
        state.set_locks({})
        vim.api.nvim_buf_get_name = function()
          return filename
        end

        locks.lock_current_buffer(1, test_config, mock_persistence)

        MiniTest.expect.equality(state.get_locks()[1].filename, filename)
      end
    end)
  end)
end)
