local hud = require("radar.ui.hud")
local state = require("radar.data.state")
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
      " %  - ",
      " o  alt.lua ",
      "",
      " 1  one.lua ",
      " 2  two.lua ",
      "",
      " a  /r/a.lua ",
      "    - ",
      "    - ",
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

    MiniTest.expect.equality(#content.lines, 2 + 1 + 5 + 1 + 3)
    MiniTest.expect.equality(content.lines[8], " 5  5.lua ")
    MiniTest.expect.equality(content.lines[12], " d  /r/c ")
  end)

  it("keeps the current file in locks and highlights it", function()
    local content = hud.build(test_config, {
      locks = { lock("1", "one.lua"), lock("2", "two.lua") },
      recent = {},
      current = "/r/two.lua",
      current_lock = "two.lua",
    }, 60)

    MiniTest.expect.equality(content.lines, {
      " %  /r/two.lua ",
      " o  - ",
      "",
      " 1  one.lua ",
      " 2  two.lua ",
      "",
      "    - ",
      "    - ",
      "    - ",
    })
    local current = vim.tbl_filter(function(hl)
      return hl.hl_group == "Title"
    end, content.highlights)
    MiniTest.expect.equality(
      vim.tbl_map(function(hl)
        return hl.line
      end, current),
      { 0, 4 }
    )
  end)

  it("skips the current file in recent and keeps its labels", function()
    local content = hud.build(test_config, {
      locks = {},
      recent = { "/r/a", "/r/b", "/r/c", "/r/d", "/r/e" },
      current = "/r/b",
      current_lock = "",
    }, 60)

    MiniTest.expect.equality(content.lines, {
      " %  /r/b ",
      " o  - ",
      "",
      " a  /r/a ",
      " d  /r/c ",
      " f  /r/d ",
    })
  end)

  it("shortens long paths to the width", function()
    local content = hud.build(test_config, {
      locks = { lock("1", "some/very/long/directory/path/file.lua") },
      recent = {},
      current = "",
      current_lock = "",
    }, 20)

    MiniTest.expect.equality(vim.fn.strdisplaywidth(content.lines[4]), 20)
    MiniTest.expect.equality(vim.endswith(content.lines[4], "file.lua "), true)
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
    require("radar.ui.edit").cleanup()
    require("radar.ui.help").close()
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

  local function bottom_of(win_config, pane)
    return win_config.row + win_config.height == vim.api.nvim_win_get_height(pane)
  end

  it("opens at the bottom of the current pane, as wide as the pane", function()
    hud.refresh()

    local winid = assert(hud.get_winid())
    local win_config = vim.api.nvim_win_get_config(winid)
    MiniTest.expect.equality(win_config.relative, "win")
    MiniTest.expect.equality(win_config.win, vim.api.nvim_get_current_win())
    MiniTest.expect.equality(win_config.focusable, false)
    MiniTest.expect.equality(win_config.border, "none")
    MiniTest.expect.equality(vim.wo[winid].winblend, 0)
    MiniTest.expect.equality(win_config.col, 0)
    MiniTest.expect.equality(bottom_of(win_config, 0), true)
    MiniTest.expect.equality(win_config.width, vim.api.nvim_win_get_width(0))
    MiniTest.expect.equality(
      vim.api.nvim_buf_get_lines(vim.api.nvim_win_get_buf(winid), 0, 2, false),
      { " %  b.lua ", " o  a.lua " }
    )
  end)

  it("follows the active pane", function()
    hud.refresh()
    vim.cmd("vsplit " .. vim.fn.fnameescape(file("c.lua")))
    hud.refresh()
    local left = vim.api.nvim_get_current_win()
    local win_config = vim.api.nvim_win_get_config(assert(hud.get_winid()))
    MiniTest.expect.equality(win_config.win, left)
    MiniTest.expect.equality(win_config.width, vim.api.nvim_win_get_width(left))

    vim.cmd("wincmd l")
    hud.refresh()
    MiniTest.expect.equality(
      vim.api.nvim_win_get_config(assert(hud.get_winid())).win,
      vim.api.nvim_get_current_win()
    )
    vim.cmd("only")
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
    local second_buf = vim.api.nvim_win_get_buf(second)

    vim.cmd("tabclose")
    hud.refresh()
    MiniTest.expect.equality(hud.get_winid(), first)
    MiniTest.expect.equality(vim.api.nvim_buf_is_valid(second_buf), false)
  end)

  it("hides for the tabs sidebar", function()
    hud.refresh()
    MiniTest.expect.equality(hud.get_winid() ~= nil, true)

    require("radar.ui.tabs").open(test_config)
    MiniTest.expect.equality(hud.get_winid(), nil)
    require("radar.ui.tabs").close()
    MiniTest.expect.equality(hud.get_winid() ~= nil, true)
  end)

  it("updates on lock changes", function()
    hud.refresh()
    local before = vim.api.nvim_buf_get_lines(
      vim.api.nvim_win_get_buf(assert(hud.get_winid())),
      0,
      -1,
      false
    )
    MiniTest.expect.equality(before[1], " %  b.lua ")

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
      table.concat(after, "\n"):find(" 1  c.lua", 1, true) ~= nil,
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

  it("moves to the top of the pane while the cursor line runs under it", function()
    vim.api.nvim_buf_set_lines(0, 0, -1, false, vim.fn["repeat"]({ "x" }, 200))
    vim.api.nvim_win_set_cursor(0, { 1, 0 })
    hud.refresh()
    local winid = assert(hud.get_winid())
    MiniTest.expect.equality(bottom_of(vim.api.nvim_win_get_config(winid), 0), true)

    vim.cmd("normal! L")
    hud.dodge()
    MiniTest.expect.equality(vim.api.nvim_win_get_config(winid).row, 0)

    vim.cmd("normal! H")
    hud.dodge()
    MiniTest.expect.equality(bottom_of(vim.api.nvim_win_get_config(winid), 0), true)
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

    it("does nothing on the prefix again", function()
      local windows = #vim.api.nvim_list_wins()
      press(" ")
      MiniTest.expect.equality(vim.api.nvim_buf_get_name(0), file("b.lua"))
      MiniTest.expect.equality(#vim.api.nvim_list_wins(), windows)
    end)

    it("opens the alternative file with o", function()
      press("o")
      MiniTest.expect.equality(vim.api.nvim_buf_get_name(0), file("a.lua"))
    end)

    it("locks and unlocks the current buffer", function()
      hud.refresh()
      press("l")
      MiniTest.expect.equality(state.get_locks()[1].filename, "b.lua")

      press("l")
      MiniTest.expect.equality(#state.get_locks(), 0)
    end)

    it("toggles the HUD with h", function()
      hud.refresh()
      press("h")
      MiniTest.expect.equality(hud.get_winid(), nil)
    end)

    it("opens the tabs view at least as tall as the HUD", function()
      hud.refresh()
      local hud_height = hud.get_height()
      press("t")
      local winid = require("radar.data.state").get_tabs_winid()
      MiniTest.expect.equality(vim.api.nvim_win_get_height(winid), hud_height)
      require("radar.ui.tabs").close()
    end)

    it("toggles the tabs sidebar with t", function()
      local tabs = require("radar.ui.tabs")
      press("t")
      MiniTest.expect.equality(tabs.exists(), true)
      press("t")
      MiniTest.expect.equality(tabs.exists(), false)
    end)

    it("opens the lock editor at the bottom of the pane", function()
      local winborder = vim.o.winborder
      vim.o.winborder = "rounded"
      state.set_locks({ { label = "1", filename = "c.lua" } })
      hud.refresh()
      local pane = vim.api.nvim_get_current_win()
      local buffer_count = #vim.api.nvim_list_bufs()

      press("e")
      vim.o.winborder = winborder
      local edit_win = assert(state.get_edit_winid())
      local win_config = vim.api.nvim_win_get_config(edit_win)
      MiniTest.expect.equality(vim.api.nvim_get_current_win(), edit_win)
      MiniTest.expect.equality(win_config.relative, "win")
      MiniTest.expect.equality(win_config.win, pane)
      MiniTest.expect.equality(win_config.border, "none")
      MiniTest.expect.equality(win_config.focusable, true)
      MiniTest.expect.equality(win_config.zindex > 10, true)
      MiniTest.expect.equality(win_config.col, 0)
      MiniTest.expect.equality(win_config.width, vim.api.nvim_win_get_width(pane))
      MiniTest.expect.equality(win_config.height, 3)
      MiniTest.expect.equality(bottom_of(win_config, pane), true)
      MiniTest.expect.equality(vim.wo[edit_win].winblend, 0)
      MiniTest.expect.equality(hud.get_winid(), nil)

      vim.api.nvim_buf_set_lines(0, 0, -1, false, { "a.lua", "c.lua" })
      vim.cmd("silent write")
      MiniTest.expect.equality(
        vim.tbl_map(function(lock)
          return lock.filename
        end, state.get_locks()),
        { "a.lua", "c.lua" }
      )

      vim.api.nvim_feedkeys("q", "x", false)
      vim.wait(100, function()
        return state.get_edit_winid() == nil
      end)
      MiniTest.expect.equality(vim.api.nvim_win_is_valid(edit_win), false)
      MiniTest.expect.equality(state.get_edit_winid(), nil)
      MiniTest.expect.equality(vim.api.nvim_get_current_win(), pane)
      MiniTest.expect.equality(hud.get_winid() ~= nil, true)
      MiniTest.expect.equality(#vim.api.nvim_list_bufs(), buffer_count)
    end)

    it("discards lock editor changes on :quit!", function()
      state.set_locks({ { label = "1", filename = "c.lua" } })
      hud.refresh()
      local pane = vim.api.nvim_get_current_win()
      local buffer_count = #vim.api.nvim_list_bufs()

      press("e")
      vim.api.nvim_buf_set_lines(0, 0, -1, false, { "a.lua" })
      vim.cmd("quit!")
      vim.wait(100, function()
        return state.get_edit_winid() == nil
      end)

      MiniTest.expect.equality(state.get_locks()[1].filename, "c.lua")
      MiniTest.expect.equality(#state.get_locks(), 1)
      MiniTest.expect.equality(state.get_edit_winid(), nil)
      MiniTest.expect.equality(vim.api.nvim_get_current_win(), pane)
      MiniTest.expect.equality(hud.get_winid() ~= nil, true)
      MiniTest.expect.equality(#vim.api.nvim_list_bufs(), buffer_count)
    end)

    it("opens and closes the help with ?", function()
      local pane = vim.api.nvim_get_current_win()
      press("?")
      local help = require("radar.ui.help")
      MiniTest.expect.equality(help.is_open(), true)
      local lines = vim.api.nvim_buf_get_lines(0, 0, -1, false)
      MiniTest.expect.equality(
        table.concat(lines, "\n"):find("Edit locks", 1, true) ~= nil,
        true
      )

      vim.api.nvim_feedkeys("q", "x", false)
      MiniTest.expect.equality(help.is_open(), false)
      MiniTest.expect.equality(vim.api.nvim_get_current_win(), pane)
    end)

    it("does nothing on <Esc>", function()
      state.set_locks({ { label = "1", filename = "c.lua" } })
      press("\27")
      MiniTest.expect.equality(vim.api.nvim_buf_get_name(0), file("b.lua"))
    end)

    it("cancels when reading the key fails", function()
      vim.fn.getcharstr = function()
        error("Keyboard interrupt")
      end
      vim.fn.maparg(test_config.keys.prefix, "n", false, true).callback()
      MiniTest.expect.equality(vim.api.nvim_buf_get_name(0), file("b.lua"))
    end)
  end)
end)
