local radar = require("radar.ui.radar")
local original_filereadable = vim.fn.filereadable

describe("radar path formatting", function()
  it("shows the current Oil directory as ./", function()
    local oil_url = "oil://" .. vim.uv.cwd() .. "/"

    MiniTest.expect.equality(radar.get_formatted_filepath(oil_url), "./")
  end)

  it("shows Oil subdirectories relative to cwd with a trailing slash", function()
    local oil_url = "oil://" .. vim.uv.cwd() .. "/lua/radar/"

    MiniTest.expect.equality(radar.get_formatted_filepath(oil_url), "lua/radar/")
  end)

  it("leaves other protocol URLs on the existing formatting path", function()
    local filename = "gh://owner/repo/blob/main/file.lua"

    MiniTest.expect.equality(
      radar.get_formatted_filepath(filename),
      vim.fn.fnamemodify(filename, ":p:.")
    )
  end)
end)

describe("radar rendering", function()
  local state = require("radar.data.state")
  local navigation = require("radar.ui.navigation")
  local config = require("radar.config")
  local test_config, original_cwd, current_filereadable, root

  local function line_of(text)
    local lines = vim.api.nvim_buf_get_lines(state.get_radar_bufid(), 0, -1, false)
    for i, line in ipairs(lines) do
      if line:find(text, 1, true) then
        return i
      end
    end
  end

  local function highlighted_lines(ns_name)
    local marks = vim.api.nvim_buf_get_extmarks(
      state.get_radar_bufid(),
      vim.api.nvim_create_namespace(ns_name),
      0,
      -1,
      {}
    )
    return vim.tbl_map(function(mark)
      return mark[2] + 1
    end, marks)
  end

  before_each(function()
    current_filereadable = vim.fn.filereadable
    vim.fn.filereadable = original_filereadable
    state.reset()
    test_config = vim.deepcopy(config.default)
    test_config.persist.path = vim.fn.tempname() .. ".json"
    original_cwd = vim.uv.cwd()
    root = vim.fn.tempname()
    vim.fn.mkdir(root .. "/.git", "p")
    root = assert(vim.uv.fs_realpath(root))
    vim.fn.writefile({ "ref: refs/heads/main" }, root .. "/.git/HEAD")
    for _, name in ipairs({ "a.lua", "b.lua", "c.lua" }) do
      vim.fn.writefile({}, root .. "/" .. name)
    end
    vim.uv.chdir(root)
    vim.cmd.edit(root .. "/a.lua")
  end)

  after_each(function()
    radar.close()
    vim.cmd("silent! %bwipeout!")
    vim.uv.chdir(original_cwd)
    vim.fn.delete(root, "rf")
    state.reset()
    vim.fn.filereadable = current_filereadable
  end)

  it("maps lines past a stale lock to the right targets", function()
    state.set_locks({
      { label = "1", filename = "gone.lua" },
      { label = "2", filename = "b.lua" },
      { label = "3", filename = "a.lua" },
    })

    radar.open(test_config)

    local current_line = line_of("[3] a.lua")
    MiniTest.expect.equality(vim.api.nvim_win_get_cursor(0)[1], current_line)
    MiniTest.expect.equality(highlighted_lines("radar.locks"), { current_line })
    MiniTest.expect.equality(
      navigation.get_file_from_line(test_config, "locks"),
      "a.lua"
    )

    vim.api.nvim_win_set_cursor(0, { line_of("[2] b.lua"), 0 })
    MiniTest.expect.equality(
      navigation.get_file_from_line(test_config, "locks"),
      "b.lua"
    )
  end)

  it("updates in place and keeps the buffer count stable", function()
    radar.open(test_config)
    local winid = state.get_radar_winid()
    radar.update(test_config)
    MiniTest.expect.equality(state.get_radar_winid(), winid)
    radar.close()

    local buffer_count = #vim.api.nvim_list_bufs()
    for _ = 1, 20 do
      radar.open(test_config)
      radar.update(test_config)
      radar.update(test_config)
      radar.close()
    end

    MiniTest.expect.equality(#vim.api.nvim_list_bufs(), buffer_count)
  end)

  it("clears the source buffer and alternate file on close", function()
    radar.open(test_config)
    radar.close()

    MiniTest.expect.equality(state.get_source_bufnr(), nil)
    MiniTest.expect.equality(state.get_source_alt_file(), nil)
    MiniTest.expect.equality(state.get_radar_line_mapping(), {})
  end)

  it("clears state when the window is closed without radar.close", function()
    radar.open(test_config)
    vim.cmd.close()

    MiniTest.expect.equality(state.get_radar_winid(), nil)
    MiniTest.expect.equality(state.get_radar_bufid(), nil)
    MiniTest.expect.equality(state.get_source_bufnr(), nil)
    MiniTest.expect.equality(state.get_source_alt_file(), nil)
    MiniTest.expect.equality(state.get_radar_line_mapping(), {})
  end)

  it("recreates the radar with its source after saving the editor", function()
    vim.cmd.edit(root .. "/b.lua")
    vim.cmd.edit(root .. "/a.lua")
    state.set_locks({ { label = "1", filename = "a.lua" } })

    radar.open(test_config)
    vim.api.nvim_feedkeys("e", "x", false)
    local original_notify = vim.notify
    vim.notify = function() end
    vim.cmd("silent write")
    vim.notify = original_notify

    MiniTest.expect.equality(radar.exists(), true)
    MiniTest.expect.equality(line_of("b.lua"), 2)
    MiniTest.expect.equality(
      highlighted_lines("radar.locks"),
      { line_of("[1] a.lua") }
    )
  end)

  it("locks the current file from recent when it has no alternate", function()
    state.set_session_files({ root .. "/a.lua" })

    radar.open(test_config)
    MiniTest.expect.equality(vim.api.nvim_win_get_cursor(0)[1], line_of("a.lua"))
    vim.api.nvim_feedkeys(test_config.keys.lock, "x", false)

    MiniTest.expect.equality(state.get_locks(), {
      { label = "1", filename = "a.lua" },
    })
  end)
end)
