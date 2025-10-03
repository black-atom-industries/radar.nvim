local config = require("radar.config")

describe("config", function()
  describe("default configuration", function()
    it("has all required keys", function()
      MiniTest.expect.equality(type(config.default.keys), "table")
      MiniTest.expect.equality(
        type(config.default.windows.float.radar_window.config.width),
        "number"
      )
      MiniTest.expect.equality(
        type(config.default.behavior.max_recent_files),
        "number"
      )
      MiniTest.expect.equality(type(config.default.persist.path), "string")
    end)

    it("has valid key bindings", function()
      local keys = config.default.keys

      MiniTest.expect.equality(type(keys.prefix), "string")
      MiniTest.expect.equality(type(keys.lock), "string")
      MiniTest.expect.equality(type(keys.locks), "table")
      MiniTest.expect.equality(type(keys.recent), "table")
      MiniTest.expect.equality(type(keys.vertical), "string")
      MiniTest.expect.equality(type(keys.horizontal), "string")
      MiniTest.expect.equality(type(keys.tab), "string")

      -- Check that locks and recent arrays are populated
      MiniTest.expect.equality(#keys.locks > 0, true)
      MiniTest.expect.equality(#keys.recent > 0, true)
    end)

    it("has valid UI configuration", function()
      local cfg = config.default

      -- Check UI settings
      MiniTest.expect.equality(
        type(cfg.windows.float.radar_window.config.width),
        "number"
      )
      MiniTest.expect.equality(
        type(cfg.windows.float.radar_window.winblend),
        "number"
      )
      MiniTest.expect.equality(type(cfg.appearance.path_format), "string")
      MiniTest.expect.equality(type(cfg.behavior.show_empty_message), "boolean")

      -- Check headers
      MiniTest.expect.equality(type(cfg.appearance.headers.locks), "string")
      MiniTest.expect.equality(type(cfg.appearance.headers.recent), "string")
      MiniTest.expect.equality(
        type(cfg.windows.float.radar_window.config.title),
        "string"
      )

      -- Check edit config
      MiniTest.expect.equality(
        type(cfg.windows.float.edit_window.width_padding),
        "number"
      )
      MiniTest.expect.equality(
        type(cfg.windows.float.edit_window.max_height),
        "number"
      )
      MiniTest.expect.equality(
        type(cfg.windows.float.edit_window.min_width),
        "number"
      )
    end)

    it("has valid behavior configuration", function()
      local cfg = config.default

      MiniTest.expect.equality(type(cfg.behavior.max_recent_files), "number")
      MiniTest.expect.equality(type(cfg.persist.defer_ms), "number")
      MiniTest.expect.equality(type(cfg.windows.float.hide_on_collision), "boolean")
      MiniTest.expect.equality(type(cfg.windows.float.collision_padding), "number")
    end)

    it("has valid persistence configuration", function()
      local cfg = config.default

      MiniTest.expect.equality(type(cfg.persist.path), "string")

      -- Check that path is reasonable
      MiniTest.expect.equality(vim.startswith(cfg.persist.path, "/"), true)
      MiniTest.expect.equality(cfg.persist.path:match("%.json$") ~= nil, true)
    end)

    it("has consistent lock labels", function()
      local locks = config.default.keys.locks

      -- Should be number keys in order
      MiniTest.expect.equality(locks[1], "1")
      MiniTest.expect.equality(locks[2], "2")
      MiniTest.expect.equality(locks[9], "9")
      MiniTest.expect.equality(#locks, 9)
    end)

    it("has consistent recent file labels", function()
      local recent = config.default.keys.recent

      -- Should be home row keys
      MiniTest.expect.equality(recent[1], "a")
      MiniTest.expect.equality(recent[2], "s")
      MiniTest.expect.equality(recent[3], "d")
      MiniTest.expect.equality(recent[4], "f")
      MiniTest.expect.equality(recent[5], "g")
      MiniTest.expect.equality(#recent, 5)
    end)
  end)

  describe("constants", function()
    it("has mini radar namespace", function()
      MiniTest.expect.equality(type(config.constants), "table")
      MiniTest.expect.equality(type(config.constants.ns_mini_radar), "number")
      MiniTest.expect.equality(config.constants.ns_mini_radar >= 0, true)
    end)
  end)

  describe("type definitions", function()
    it("validates config structure matches types", function()
      -- This is mainly a documentation test - ensure our default config
      -- matches the structure implied by the type annotations

      local cfg = config.default

      -- Test structure matches Radar.Config type
      MiniTest.expect.equality(type(cfg.keys.prefix), "string")
      MiniTest.expect.equality(type(cfg.keys.lock), "string")
      MiniTest.expect.equality(type(cfg.keys.locks), "table")
      MiniTest.expect.equality(type(cfg.keys.recent), "table")

      -- Test persist structure
      MiniTest.expect.equality(type(cfg.persist.path), "string")
    end)
  end)
end)
