local path_utils = require("radar.utils.path")

describe("path.shorten_path", function()
  local shorten_path = path_utils.shorten_path

  describe("basic functionality", function()
    it("returns empty string for nil or empty path", function()
      MiniTest.expect.equality(shorten_path(nil, 50), "")
      MiniTest.expect.equality(shorten_path("", 50), "")
    end)

    it("returns path as-is when it fits within max width", function()
      local short_path = "file.lua"
      MiniTest.expect.equality(shorten_path(short_path, 50), short_path)

      local medium_path = "lua/radar/init.lua"
      MiniTest.expect.equality(shorten_path(medium_path, 50), medium_path)
    end)

    it("replaces home directory with ~", function()
      local home = vim.fn.expand("~")
      local path = home .. "/Documents/file.txt"
      local result = shorten_path(path, 50)
      MiniTest.expect.equality(result, "~/Documents/file.txt")
    end)
  end)

  describe("path shortening", function()
    it("shortens directory names to single letters when needed", function()
      local long_path =
        "/Users/username/Documents/projects/myproject/src/components/file.lua"
      local result = shorten_path(long_path, 30)

      -- Should keep filename intact and shorten directories
      MiniTest.expect.equality(result:match("file%.lua$") ~= nil, true)
      MiniTest.expect.equality(vim.fn.strdisplaywidth(result) <= 30, true)
    end)

    it("handles home directory shortening correctly", function()
      local home = vim.fn.expand("~")
      local path = home .. "/very/long/directory/structure/file.txt"
      local result = shorten_path(path, 20)

      -- Should start with ~ and end with filename
      MiniTest.expect.equality(result:match("^~") ~= nil, true)
      MiniTest.expect.equality(result:match("file%.txt$") ~= nil, true)
      MiniTest.expect.equality(vim.fn.strdisplaywidth(result) <= 20, true)
    end)

    it("adds ellipsis when path is too long to show all components", function()
      local path =
        "/very/deeply/nested/directory/structure/with/many/levels/file.lua"
      local result = shorten_path(path, 20)

      -- Should contain ellipsis
      MiniTest.expect.equality(result:match("%.%.%.") ~= nil, true)
      MiniTest.expect.equality(result:match("file%.lua$") ~= nil, true)
      MiniTest.expect.equality(vim.fn.strdisplaywidth(result) <= 20, true)
    end)

    it("truncates filename with ellipsis when filename alone is too long", function()
      local path = "/path/to/very_long_filename_that_exceeds_maximum_width.lua"
      local result = shorten_path(path, 15)

      -- Should truncate filename with ellipsis
      MiniTest.expect.equality(result:match("%.%.%.$") ~= nil, true)
      MiniTest.expect.equality(vim.fn.strdisplaywidth(result) <= 15, true)
    end)
  end)

  describe("label width handling", function()
    it("accounts for label width when shortening", function()
      local path = "/Users/username/Documents/file.txt"
      local max_width = 25
      local label_width = 4 -- "[1] " takes 4 chars

      local result = shorten_path(path, max_width, label_width)
      -- Available width is 25 - 4 = 21
      MiniTest.expect.equality(
        vim.fn.strdisplaywidth(result) <= (max_width - label_width),
        true
      )
    end)

    it("uses full width when label_width is not provided", function()
      local path = "/Users/username/Documents/file.txt"
      local max_width = 25

      local result = shorten_path(path, max_width)
      MiniTest.expect.equality(vim.fn.strdisplaywidth(result) <= max_width, true)
    end)
  end)

  describe("edge cases", function()
    it("handles root directory", function()
      local path = "/file.txt"
      local result = shorten_path(path, 20)
      MiniTest.expect.equality(result, "/file.txt")
    end)

    it("handles relative paths", function()
      local path = "lua/radar/init.lua"
      local result = shorten_path(path, 15)
      MiniTest.expect.equality(result:match("init%.lua$") ~= nil, true)
    end)

    it("handles paths with consecutive slashes", function()
      local path = "/Users//username///file.txt"
      local result = shorten_path(path, 30)
      MiniTest.expect.equality(result:match("file%.txt$") ~= nil, true)
    end)

    it("handles hidden files and directories", function()
      local path = "/home/user/.config/.hidden/file.txt"
      local result = shorten_path(path, 20)
      MiniTest.expect.equality(result:match("file%.txt$") ~= nil, true)
    end)

    it("preserves absolute path indicator", function()
      local path = "/usr/local/bin/script.sh"
      local result = shorten_path(path, 20)
      -- Should start with / if it's an absolute path (unless it's ~)
      local starts_correctly = result:sub(1, 1) == "/"
        or result:sub(1, 1) == "~"
        or result:sub(1, 3) == "..."
      MiniTest.expect.equality(starts_correctly, true)
    end)
  end)
end)

describe("path.format_and_shorten", function()
  local format_and_shorten = path_utils.format_and_shorten

  it("applies vim path formatting", function()
    local cwd = vim.fn.getcwd()
    local path = cwd .. "/lua/radar/init.lua"
    local result = format_and_shorten(path, ":p:.")

    -- Should be relative to current directory
    MiniTest.expect.equality(result, "lua/radar/init.lua")
  end)

  it("applies shortening when max_width is provided", function()
    local path = "/very/long/path/to/some/deeply/nested/file.lua"
    local result = format_and_shorten(path, ":p", 20)

    MiniTest.expect.equality(vim.fn.strdisplaywidth(result) <= 20, true)
    MiniTest.expect.equality(result:match("file%.lua$") ~= nil, true)
  end)

  it("does not shorten when max_width is not provided", function()
    local path = "/very/long/path/to/some/deeply/nested/file.lua"
    local result = format_and_shorten(path, ":p")

    -- Should return full absolute path
    MiniTest.expect.equality(result, vim.fn.fnamemodify(path, ":p"))
  end)

  it("uses default format when not specified", function()
    local cwd = vim.fn.getcwd()
    local path = cwd .. "/test.lua"
    local result = format_and_shorten(path)

    -- Default is ":p:." (relative to cwd)
    MiniTest.expect.equality(result, "test.lua")
  end)
end)
