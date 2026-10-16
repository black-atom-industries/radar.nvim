local hud = require("radar.ui.hud")
local state = require("radar.data.state")
local radar = require("radar.ui.radar")
local config = require("radar.config")

describe("hud content", function()
  local test_config

  before_each(function()
    test_config = vim.deepcopy(config.default)
  end)

  local function lock(label, filename)
    return { label = label, filename = filename }
  end

  it("lists the alternative file, locks and recent files in order", function()
    local content = hud.build(test_config, {
      alt = "alt.lua",
      locks = { lock("1", "one.lua"), lock("2", "two.lua") },
      recent = { "/r/a.lua" },
      current = "",
      current_lock = "",
    }, 60)

    MiniTest.expect.equality(content.lines, {
      " 󰐷 [o] alt.lua ",
      "",
      " 󰋱 [1] one.lua ",
      " 󰋱 [2] two.lua ",
      "",
      " 󰽏 [a] /r/a.lua ",
    })
  end)

  it("caps locks at hud.max_locks and recent at hud.max_recent", function()
    local locks = {}
    for i = 1, 7 do
      table.insert(locks, lock(tostring(i), i .. ".lua"))
    end
    local content = hud.build(test_config, {
      locks = locks,
      recent = { "/r/a", "/r/b", "/r/c", "/r/d", "/r/e" },
      current = "",
      current_lock = "",
    }, 60)

    MiniTest.expect.equality(#content.lines, 1 + 1 + 5 + 1 + 3)
    MiniTest.expect.equality(content.lines[7], " 󰋱 [5] 5.lua ")
    MiniTest.expect.equality(content.lines[11], " 󰽏 [d] /r/c ")
  end)

  it("keeps the current file in locks and highlights it", function()
    local content = hud.build(test_config, {
      locks = { lock("1", "one.lua"), lock("2", "two.lua") },
      recent = {},
      current = "/r/two.lua",
      current_lock = "two.lua",
    }, 60)

    MiniTest.expect.equality(
      content.lines,
      { " 󰐷 [o] - ", "", " 󰋱 [1] one.lua ", " 󰋱 [2] two.lua " }
    )
    local current = vim.tbl_filter(function(hl)
      return hl.hl_group == "Title"
    end, content.highlights)
    MiniTest.expect.equality(#current, 1)
    MiniTest.expect.equality(current[1].line, 3)
  end)

  it("skips the current file in recent and keeps its labels", function()
    local content = hud.build(test_config, {
      locks = {},
      recent = { "/r/a", "/r/b", "/r/c", "/r/d", "/r/e" },
      current = "/r/b",
      current_lock = "",
    }, 60)

    MiniTest.expect.equality(
      content.lines,
      { " 󰐷 [o] - ", "", " 󰽏 [a] /r/a ", " 󰽏 [d] /r/c ", " 󰽏 [f] /r/d " }
    )
  end)

  it("shortens long paths to the width", function()
    local content = hud.build(test_config, {
      locks = { lock("1", "some/very/long/directory/path/file.lua") },
      recent = {},
      current = "",
      current_lock = "",
    }, 20)

    MiniTest.expect.equality(vim.fn.strdisplaywidth(content.lines[3]), 20)
    MiniTest.expect.equality(vim.endswith(content.lines[3], "file.lua "), true)
  end)

  it("is empty without anything to show", function()
    local content = hud.build(test_config, {
      locks = {},
      recent = {},
      current = "",
      current_lock = "",
    }, 60)

    MiniTest.expect.equality(content.lines, {})
  end)
end)

describe("hud window", function()
  local test_config, original_cwd, root, original_getcharstr

  local function file(name)
    return root .. "/" .. name
  end

  local function press(char)
    vim.fn.getcharstr = function()
      return char
    end
    vim.fn.maparg(test_config.keys.prefix, "n", false, true).callback()
  end

  before_each(function()
    state.reset()
    test_config = vim.deepcopy(config.default)
    test_config.persist.path = vim.fn.tempname() .. ".json"
    original_cwd = vim.uv.cwd()
    original_getcharstr = vim.fn.getcharstr
    root = vim.fn.tempname()
    vim.fn.mkdir(root .. "/.git", "p")
    root = assert(vim.uv.fs_realpath(root))
    vim.fn.writefile({ "ref: refs/heads/main" }, root .. "/.git/HEAD")
    for _, name in ipairs({ "a.lua", "b.lua", "c.lua" }) do
      vim.fn.writefile({}, file(name))
    end
    vim.uv.chdir(root)
    vim.cmd("new | only")
    vim.cmd.edit(file("a.lua"))
    vim.cmd.edit(file("b.lua"))
    hud.setup(test_config)
    require("radar.ui.keys").setup(test_config)
  end)

  after_each(function()
    vim.fn.getcharstr = original_getcharstr
    radar.close()
    require("radar.ui.tabs").close()
    hud.reset()
    pcall(vim.keymap.del, "n", test_config.keys.prefix)
    pcall(vim.keymap.del, "n", test_config.keys.tabs_toggle)
    vim.cmd("silent! tabonly!")
    for _, name in ipairs({ "a.lua", "b.lua", "c.lua" }) do
      vim.cmd("silent! bwipeout! " .. vim.fn.bufnr(file(name)))
    end
    vim.uv.chdir(original_cwd)
    vim.fn.delete(root, "rf")
    state.reset()
  end)

  it("opens top-right in the editor when there is content", function()
    hud.refresh()

    local winid = assert(hud.get_winid())
    local win_config = vim.api.nvim_win_get_config(winid)
    MiniTest.expect.equality(win_config.relative, "editor")
    MiniTest.expect.equality(win_config.focusable, false)
    MiniTest.expect.equality(win_config.row, 0)
    MiniTest.expect.equality(win_config.col + win_config.width, vim.o.columns)
    MiniTest.expect.equality(
      vim.api.nvim_buf_get_lines(vim.api.nvim_win_get_buf(winid), 0, 1, false),
      { " 󰐷 [o] a.lua " }
    )
  end)

  it("keeps a fixed width when the content changes", function()
    hud.refresh()
    local winid = assert(hud.get_winid())
    local expected =
      math.max(math.min(test_config.hud.width, math.floor(vim.o.columns / 2)), 20)
    MiniTest.expect.equality(vim.api.nvim_win_get_width(winid), expected)

    state.set_locks({
      { label = "1", filename = "a-much-longer-file-name-than-before.lua" },
    })
    hud.refresh()
    MiniTest.expect.equality(
      vim.api.nvim_win_get_width(assert(hud.get_winid())),
      expected
    )
  end)

  it("stays hidden when empty", function()
    vim.cmd.enew()
    vim.cmd("bwipeout! " .. vim.fn.bufnr(file("a.lua")))
    vim.cmd("bwipeout! " .. vim.fn.bufnr(file("b.lua")))
    hud.refresh()

    MiniTest.expect.equality(hud.get_winid(), nil)
  end)

  it("keeps the buffer count stable across refreshes", function()
    hud.refresh()
    local buffer_count = #vim.api.nvim_list_bufs()
    for _ = 1, 20 do
      hud.refresh()
    end
    radar.open(test_config)
    radar.close()

    MiniTest.expect.equality(#vim.api.nvim_list_bufs(), buffer_count)
  end)

  it("has one window per tabpage", function()
    hud.refresh()
    local first = hud.get_winid()

    vim.cmd("tabnew " .. vim.fn.fnameescape(file("c.lua")))
    vim.cmd.edit(file("a.lua"))
    hud.refresh()
    local second = hud.get_winid()
    MiniTest.expect.equality(second ~= nil and second ~= first, true)
    MiniTest.expect.equality(vim.api.nvim_win_get_config(second).row, 1)
    local second_buf = vim.api.nvim_win_get_buf(second)

    vim.cmd("tabclose")
    hud.refresh()
    MiniTest.expect.equality(hud.get_winid(), first)
    MiniTest.expect.equality(vim.api.nvim_buf_is_valid(second_buf), false)
  end)

  it("stays visible next to the radar and hides for the tabs sidebar", function()
    hud.refresh()

    radar.open(test_config)
    MiniTest.expect.equality(hud.get_winid() ~= nil, true)
    radar.close()
    MiniTest.expect.equality(hud.get_winid() ~= nil, true)

    require("radar.ui.tabs").open(test_config)
    MiniTest.expect.equality(hud.get_winid(), nil)
    require("radar.ui.tabs").close()
    MiniTest.expect.equality(hud.get_winid() ~= nil, true)
  end)

  it("updates while the radar is open and ignores the radar buffer", function()
    radar.open(test_config)
    local before = vim.api.nvim_buf_get_lines(
      vim.api.nvim_win_get_buf(assert(hud.get_winid())),
      0,
      -1,
      false
    )
    local radar_text = table.concat(before, "\n")
    MiniTest.expect.equality(radar_text:find("b.lua", 1, true), nil)

    require("radar.data.locks").toggle(
      "c.lua",
      test_config,
      require("radar.persist.persistence")
    )
    hud.refresh()
    local after = vim.api.nvim_buf_get_lines(
      vim.api.nvim_win_get_buf(assert(hud.get_winid())),
      0,
      -1,
      false
    )
    MiniTest.expect.equality(
      table.concat(after, "\n"):find("[1] c.lua", 1, true) ~= nil,
      true
    )
  end)

  it("toggles for the session and respects hud.enabled", function()
    hud.refresh()
    hud.toggle()
    MiniTest.expect.equality(hud.get_winid(), nil)
    hud.toggle()
    MiniTest.expect.equality(hud.get_winid() ~= nil, true)

    hud.reset()
    test_config.hud.enabled = false
    hud.setup(test_config)
    hud.refresh()
    MiniTest.expect.equality(hud.get_winid(), nil)
  end)

  it("moves to the bottom-right while the cursor is under it", function()
    local width = vim.api.nvim_win_get_width(0)
    vim.api.nvim_buf_set_lines(0, 0, -1, false, { string.rep("x", width - 1) })
    hud.refresh()
    local winid = assert(hud.get_winid())

    vim.api.nvim_win_set_cursor(0, { 1, width - 2 })
    hud.dodge()
    local win_config = vim.api.nvim_win_get_config(winid)
    MiniTest.expect.equality(
      win_config.row + win_config.height,
      vim.o.lines - vim.o.cmdheight - 1
    )
    MiniTest.expect.equality(win_config.col + win_config.width, vim.o.columns)

    vim.api.nvim_win_set_cursor(0, { 1, 0 })
    hud.dodge()
    MiniTest.expect.equality(vim.api.nvim_win_get_config(winid).row, 0)
  end)

  describe("prefix", function()
    it("jumps to a lock with its label", function()
      state.set_locks({ { label = "1", filename = "c.lua" } })
      press("1")
      MiniTest.expect.equality(vim.api.nvim_buf_get_name(0), file("c.lua"))
    end)

    it("jumps to locks past the HUD cap", function()
      local locks = {}
      for i = 1, 7 do
        local name = i == 7 and "c.lua" or "a.lua"
        table.insert(locks, { label = tostring(i), filename = name })
      end
      state.set_locks(locks)
      press("7")
      MiniTest.expect.equality(vim.api.nvim_buf_get_name(0), file("c.lua"))
    end)

    it("jumps to a recent file with its label", function()
      state.set_session_files({ file("c.lua") })
      press("a")
      MiniTest.expect.equality(vim.api.nvim_buf_get_name(0), file("c.lua"))
    end)

    it("opens the radar with the prefix again", function()
      press(" ")
      MiniTest.expect.equality(radar.exists(), true)
    end)

    it("opens the alternative file with o", function()
      press("o")
      MiniTest.expect.equality(vim.api.nvim_buf_get_name(0), file("a.lua"))
    end)

    it("locks the current buffer without opening the radar", function()
      hud.refresh()
      press("l")
      MiniTest.expect.equality(state.get_locks()[1].filename, "b.lua")
      MiniTest.expect.equality(radar.exists(), false)

      press("l")
      MiniTest.expect.equality(#state.get_locks(), 0)
      MiniTest.expect.equality(radar.exists(), false)
    end)

    it("toggles the HUD with h", function()
      hud.refresh()
      press("h")
      MiniTest.expect.equality(hud.get_winid(), nil)
    end)

    it("does nothing on <Esc>", function()
      state.set_locks({ { label = "1", filename = "c.lua" } })
      press("\27")
      MiniTest.expect.equality(vim.api.nvim_buf_get_name(0), file("b.lua"))
      MiniTest.expect.equality(radar.exists(), false)
    end)

    it("cancels when reading the key fails", function()
      vim.fn.getcharstr = function()
        error("Keyboard interrupt")
      end
      vim.fn.maparg(test_config.keys.prefix, "n", false, true).callback()
      MiniTest.expect.equality(radar.exists(), false)
    end)
  end)

  describe("inside the radar", function()
    it("opens the alternative file with o", function()
      radar.open(test_config)
      vim.api.nvim_feedkeys("o", "x", false)
      MiniTest.expect.equality(radar.exists(), false)
      MiniTest.expect.equality(vim.api.nvim_buf_get_name(0), file("a.lua"))
    end)

    it("closes with the prefix", function()
      radar.open(test_config)
      vim.api.nvim_feedkeys(vim.keycode(test_config.keys.prefix), "x", false)
      MiniTest.expect.equality(radar.exists(), false)
      MiniTest.expect.equality(vim.api.nvim_buf_get_name(0), file("b.lua"))
    end)
  end)
end)
