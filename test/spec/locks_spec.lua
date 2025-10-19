local locks = require("radar.locks")
local state = require("radar.state")
local config = require("radar.config")

describe("locks", function()
  local test_config

  local function setup_test_state()
    test_config = vim.deepcopy(config.default)
    state.locks = {}
  end

  describe("get_next_unused_label", function()
    before_each(setup_test_state)

    it("returns first label when no locks exist", function()
      local label = locks.get_next_unused_label(test_config)
      MiniTest.expect.equality(label, "1")
    end)

    it("skips used labels and returns next available", function()
      -- Add some locks
      state.locks = {
        { label = "1", filename = "file1.lua" },
        { label = "3", filename = "file3.lua" },
      }

      local label = locks.get_next_unused_label(test_config)
      MiniTest.expect.equality(label, "2")
    end)

    it("returns labels in order defined in config", function()
      -- Fill up first few slots
      for i = 1, 5 do
        table.insert(
          state.locks,
          { label = tostring(i), filename = "file" .. i .. ".lua" }
        )
      end

      local label = locks.get_next_unused_label(test_config)
      MiniTest.expect.equality(label, "6")
    end)

    it("throws error when all slots are used", function()
      -- Fill up all lock slots
      for _, label in ipairs(test_config.keys.locks) do
        table.insert(
          state.locks,
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
      MiniTest.expect.equality(lock.label, "1")
      MiniTest.expect.equality(lock.filename, "test.lua")
    end)

    it("adds lock to state.locks", function()
      MiniTest.expect.equality(#state.locks, 0)

      locks.add("test.lua", test_config)

      MiniTest.expect.equality(#state.locks, 1)
      MiniTest.expect.equality(state.locks[1].filename, "test.lua")
    end)

    it("assigns unique labels for multiple locks", function()
      local lock1 = locks.add("file1.lua", test_config)
      local lock2 = locks.add("file2.lua", test_config)

      MiniTest.expect.equality(lock1.label, "1")
      MiniTest.expect.equality(lock2.label, "2")
      MiniTest.expect.equality(#state.locks, 2)
    end)
  end)

  describe("remove", function()
    before_each(setup_test_state)

    it("removes lock by filename", function()
      locks.add("file1.lua", test_config)
      locks.add("file2.lua", test_config)
      MiniTest.expect.equality(#state.locks, 2)

      local removed = locks.remove("file1.lua")

      MiniTest.expect.equality(#state.locks, 1)
      MiniTest.expect.equality(removed.filename, "file1.lua")
      MiniTest.expect.equality(state.locks[1].filename, "file2.lua")
    end)

    it("returns nil when file not found", function()
      locks.add("existing.lua", test_config)

      local removed = locks.remove("nonexistent.lua")

      MiniTest.expect.equality(removed, nil)
      MiniTest.expect.equality(#state.locks, 1)
    end)

    it("handles empty state gracefully", function()
      local removed = locks.remove("nonexistent.lua")
      MiniTest.expect.equality(removed, nil)
    end)
  end)

  describe("toggle", function()
    local mock_persistence, mock_mini_radar

    before_each(function()
      setup_test_state()
      mock_persistence = { persist = function() end }
      mock_mini_radar = {}
    end)

    it("adds lock when file not locked", function()
      local lock = locks.toggle("new.lua", test_config, mock_persistence)

      MiniTest.expect.equality(#state.locks, 1)
      MiniTest.expect.equality(lock.filename, "new.lua")
      MiniTest.expect.equality(lock.label, "1")
    end)

    it("removes lock when file is locked", function()
      -- Add a lock first
      locks.add("existing.lua", test_config)
      MiniTest.expect.equality(#state.locks, 1)

      local removed_lock =
        locks.toggle("existing.lua", test_config, mock_persistence)

      MiniTest.expect.equality(#state.locks, 0)
      MiniTest.expect.equality(removed_lock.filename, "existing.lua")
    end)
  end)

  describe("lock_current_buffer", function()
    local mock_persistence, mock_mini_radar
    local original_api

    before_each(function()
      setup_test_state()
      mock_persistence = { persist = function() end }
      mock_mini_radar = {
        exists = function()
          return false
        end,
        create = function() end,
        update = function() end,
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
      locks.lock_current_buffer(nil, test_config, mock_persistence, mock_mini_radar)

      MiniTest.expect.equality(#state.locks, 1)
      -- Should use normalized filename (relative to cwd)
      MiniTest.expect.equality(
        state.locks[1].filename,
        vim.fn.fnamemodify("/test/path/file.lua", ":p:.")
      )
    end)

    it("creates mini radar when it doesn't exist", function()
      local create_called = false
      mock_mini_radar.create = function()
        create_called = true
      end

      locks.lock_current_buffer(nil, test_config, mock_persistence, mock_mini_radar)

      MiniTest.expect.equality(create_called, true)
    end)

    it("updates mini radar when it exists", function()
      local update_called = false
      mock_mini_radar.exists = function()
        return true
      end
      mock_mini_radar.update = function()
        update_called = true
      end

      locks.lock_current_buffer(nil, test_config, mock_persistence, mock_mini_radar)

      MiniTest.expect.equality(update_called, true)
    end)
  end)
end)
