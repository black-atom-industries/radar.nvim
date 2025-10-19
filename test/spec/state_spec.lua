local state = require("radar.state")

describe("state", function()
  local function setup_test_locks()
    state.locks = {
      { label = "1", filename = "file1.lua" },
      { label = "2", filename = "file2.lua" },
      { label = "3", filename = "file3.lua" },
    }
  end

  local function clear_test_state()
    state.locks = {}
    state.recent_files = {}
    state.session_files = {}
    state.mini_radar_winid = nil
    state.edit_winid = nil
    state.edit_bufid = nil
  end

  describe("get_lock_by_field", function()
    before_each(function()
      clear_test_state()
      setup_test_locks()
    end)

    it("finds lock by label", function()
      local lock = state.get_lock_by_field("label", "2")
      MiniTest.expect.equality(lock.filename, "file2.lua")
      MiniTest.expect.equality(lock.label, "2")
    end)

    it("finds lock by filename", function()
      local lock = state.get_lock_by_field("filename", "file3.lua")
      MiniTest.expect.equality(lock.label, "3")
      MiniTest.expect.equality(lock.filename, "file3.lua")
    end)

    it("returns nil when field value not found", function()
      local lock = state.get_lock_by_field("label", "99")
      MiniTest.expect.equality(lock, nil)
    end)

    it("returns nil when field doesn't exist", function()
      local lock = state.get_lock_by_field("nonexistent", "value")
      MiniTest.expect.equality(lock, nil)
    end)

    it("handles empty locks array", function()
      state.locks = {}
      local lock = state.get_lock_by_field("label", "1")
      MiniTest.expect.equality(lock, nil)
    end)
  end)

  describe("state initialization", function()
    it("has correct initial structure", function()
      -- Test that state has all expected fields with correct types
      MiniTest.expect.equality(type(state.locks), "table")
      MiniTest.expect.equality(type(state.recent_files), "table")
      MiniTest.expect.equality(type(state.session_files), "table")
      MiniTest.expect.equality(state.mini_radar_winid, nil)
      MiniTest.expect.equality(state.edit_winid, nil)
      MiniTest.expect.equality(state.edit_bufid, nil)
    end)
  end)
end)
