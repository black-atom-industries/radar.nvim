local M = {}

local path_utils = require("radar.path")

local ns = vim.api.nvim_create_namespace("radar.hud")

---@type Radar.Config?
local _config = nil

---Session override of config.hud.enabled
---@type boolean?
local _enabled = nil

---@class Radar.Hud
---@field bufnr integer
---@field winid integer?
---@field anchor integer? pane the HUD sits in
---@field height integer
---@field corner "top" | "bottom"?

---@type table<integer, Radar.Hud>
local huds = {}

---@class Radar.HudData
---@field alt string? alternative file path
---@field locks Radar.Lock[]
---@field recent string[]
---@field current string current buffer name
---@field current_lock string current buffer as a lock path

---@class Radar.HudHighlight
---@field line integer 0-indexed
---@field col_start integer
---@field col_end integer
---@field hl_group string

---@class Radar.HudContent
---@field lines string[]
---@field highlights Radar.HudHighlight[]

---Shorten a path from the left so it fits `max_width` cells
---@param text string
---@param max_width integer
---@return string
local function fit(text, max_width)
  if vim.fn.strdisplaywidth(text) <= max_width then
    return text
  end
  local chars = vim.fn.strchars(text)
  local keep = math.max(max_width - 1, 1)
  return "…" .. vim.fn.strcharpart(text, chars - keep, keep)
end

---Build the HUD lines and highlights
---@param config Radar.Config
---@param data Radar.HudData
---@param max_width integer
---@return Radar.HudContent
function M.build(config, data, max_width)
  local lines, highlights = {}, {}

  local function add(icon, label, target, current)
    local icon_part = " " .. icon .. " "
    local label_part = "[" .. label .. "]"
    local prefix = icon_part .. label_part .. " "
    local avail = max_width - vim.fn.strdisplaywidth(prefix) - 1
    local text = target and fit(path_utils.display(target), avail) or "-"
    local line = prefix .. text .. " "
    table.insert(lines, line)
    if not target or current then
      table.insert(highlights, {
        line = #lines - 1,
        col_start = #prefix,
        col_end = #line,
        hl_group = target and current and "Title" or "Comment",
      })
    end
    table.insert(highlights, {
      line = #lines - 1,
      col_start = 1,
      col_end = #icon_part - 1,
      hl_group = "Comment",
    })
    table.insert(highlights, {
      line = #lines - 1,
      col_start = #icon_part,
      col_end = #icon_part + #label_part,
      hl_group = "@keyword",
    })
  end

  local locks = vim.list_slice(data.locks, 1, config.hud.max_locks)

  local recent = {}
  for i, file in ipairs(data.recent) do
    local label = config.keys.recent[i]
    if not label or #recent == config.hud.max_recent then
      break
    end
    if file ~= data.current then
      table.insert(recent, { label = label, file = file })
    end
  end

  if data.current == "" and not data.alt and #locks == 0 and #recent == 0 then
    return { lines = lines, highlights = highlights }
  end

  add(
    config.hud.icons.current,
    "%",
    data.current ~= "" and data.current or nil,
    true
  )
  add(config.hud.icons.alternative, config.keys.alternative, data.alt)

  if #locks > 0 then
    table.insert(lines, "")
    for _, lock in ipairs(locks) do
      add(
        config.hud.icons.locks,
        lock.label,
        lock.filename,
        lock.filename == data.current_lock
      )
    end
  end

  if config.hud.max_recent > 0 then
    table.insert(lines, "")
    for i = 1, config.hud.max_recent do
      local entry = recent[i]
      add(
        config.hud.icons.recent,
        entry and entry.label or " ",
        entry and entry.file
      )
    end
  end

  return { lines = lines, highlights = highlights }
end

---Collect the HUD data for the current buffer
---@return Radar.HudData
local function gather()
  local state = require("radar.data.state")
  local source = state.get_source_bufnr()
  local in_radar = require("radar.ui.radar").exists()
    and source
    and vim.api.nvim_buf_is_valid(source)
  local current = vim.api.nvim_buf_get_name(in_radar and source or 0)
  local alt
  if in_radar then
    alt = state.get_source_alt_file() or nil
  else
    alt = require("radar.data.alternative").get_alternative_file()
  end
  return {
    alt = alt,
    locks = vim.tbl_filter(function(lock)
      return path_utils.is_url(lock.filename)
        or vim.fn.filereadable(path_utils.to_absolute(lock.filename)) == 1
    end, state.get_locks()),
    recent = state.get_recent_files(),
    current = current,
    current_lock = current ~= "" and path_utils.to_lock_path(current) or "",
  }
end

---@param config Radar.Config
---@return boolean
local function enabled(config)
  if _enabled == nil then
    return config.hud.enabled
  end
  return _enabled
end

---@param config Radar.Config
---@return boolean
local function should_show(config)
  local state = require("radar.data.state")
  local tab = vim.api.nvim_get_current_tabpage()
  local function covers(winid)
    return winid ~= nil
      and vim.api.nvim_win_is_valid(winid)
      and vim.api.nvim_win_get_tabpage(winid) == tab
  end
  if covers(state.get_tabs_winid()) or covers(state.get_edit_winid()) then
    return false
  end
  return enabled(config)
end

---Pane the HUD belongs to: the current window, or the previous pane while a
---float such as the radar has focus
---@param hud Radar.Hud?
---@return integer?
local function anchor_window(hud)
  local function is_pane(winid)
    return winid ~= 0
      and vim.api.nvim_win_is_valid(winid)
      and vim.api.nvim_win_get_config(winid).relative == ""
  end
  local current = vim.api.nvim_get_current_win()
  if is_pane(current) then
    return current
  end
  if hud and hud.anchor and is_pane(hud.anchor) then
    return hud.anchor
  end
  local previous = vim.fn.win_getid(vim.fn.winnr("#"))
  return is_pane(previous) and previous or nil
end

---Float position at the top or bottom edge of a pane
---@param anchor integer
---@param corner "top" | "bottom"
---@param height integer
---@return vim.api.keyset.win_config
local function position(anchor, corner, height)
  local row = corner == "top" and 0
    or math.max(vim.api.nvim_win_get_height(anchor) - height, 0)
  return { relative = "win", win = anchor, row = row, col = 0 }
end

---@param hud Radar.Hud?
---@return boolean
local function is_open(hud)
  return hud ~= nil and hud.winid ~= nil and vim.api.nvim_win_is_valid(hud.winid)
end

---Drop HUDs of closed tabpages
local function prune()
  for tab, hud in pairs(huds) do
    if not vim.api.nvim_tabpage_is_valid(tab) then
      if is_open(hud) then
        vim.api.nvim_win_close(hud.winid, true)
      end
      if vim.api.nvim_buf_is_valid(hud.bufnr) then
        vim.api.nvim_buf_delete(hud.bufnr, { force = true })
      end
      huds[tab] = nil
    end
  end
end

---@param hud Radar.Hud?
local function hide(hud)
  if is_open(hud) then
    vim.api.nvim_win_close(hud.winid, true)
  end
  if hud then
    hud.winid = nil
    hud.corner = nil
  end
end

---Store the config the HUD renders with
---@param config Radar.Config
function M.setup(config)
  _config = config
end

---Rebuild and show the HUD of the current tabpage, or hide it
---@return nil
function M.refresh()
  local config = _config
  if not config then
    return
  end
  prune()

  local tab = vim.api.nvim_get_current_tabpage()
  local hud = huds[tab]
  if not should_show(config) then
    hide(hud)
    return
  end

  local anchor = anchor_window(hud)
  if not anchor then
    hide(hud)
    return
  end

  if require("radar.data.locks").prune(config) then
    require("radar.persist.persistence").persist(config)
  end
  require("radar.data.recent").update_state(config)
  local width = vim.api.nvim_win_get_width(anchor)
  local content = M.build(config, gather(), width)
  if
    #content.lines == 0
    or vim.api.nvim_win_get_height(anchor) < #content.lines + 2
  then
    hide(hud)
    return
  end

  if not hud or not vim.api.nvim_buf_is_valid(hud.bufnr) then
    local bufnr = vim.api.nvim_create_buf(false, true)
    vim.api.nvim_set_option_value("bufhidden", "hide", { buf = bufnr })
    hud = { bufnr = bufnr, height = 0 }
    huds[tab] = hud
  end

  vim.api.nvim_buf_set_lines(hud.bufnr, 0, -1, false, content.lines)
  vim.api.nvim_buf_clear_namespace(hud.bufnr, ns, 0, -1)
  for _, hl in ipairs(content.highlights) do
    vim.api.nvim_buf_set_extmark(hud.bufnr, ns, hl.line, hl.col_start, {
      end_col = hl.col_end,
      hl_group = hl.hl_group,
    })
  end

  hud.anchor, hud.height = anchor, #content.lines

  local win_config =
    vim.tbl_extend("force", position(anchor, "bottom", hud.height), {
      width = width,
      height = hud.height,
    })
  if is_open(hud) then
    vim.api.nvim_win_set_config(hud.winid, win_config)
  else
    hud.winid = vim.api.nvim_open_win(
      hud.bufnr,
      false,
      vim.tbl_extend("force", win_config, {
        style = "minimal",
        border = "none",
        focusable = false,
        noautocmd = true,
        zindex = 10,
      })
    )
    vim.api.nvim_set_option_value(
      "winhighlight",
      "Normal:NormalFloat",
      { win = hud.winid }
    )
    vim.api.nvim_set_option_value("winblend", 0, { win = hud.winid })
  end
  hud.corner = "bottom"
  M.dodge()
end

---Keep the HUD at the bottom of its pane, and move it to the top while the
---cursor line runs under it
---@return nil
function M.dodge()
  local hud = huds[vim.api.nvim_get_current_tabpage()]
  if not is_open(hud) then
    return
  end
  ---@cast hud Radar.Hud
  if vim.api.nvim_get_current_win() ~= hud.anchor then
    return
  end

  local under_bottom = vim.fn.winline()
    > vim.api.nvim_win_get_height(hud.anchor) - hud.height
  local corner = under_bottom and "top" or "bottom"
  if corner == hud.corner then
    return
  end

  vim.api.nvim_win_set_config(hud.winid, position(hud.anchor, corner, hud.height))
  hud.corner = corner
end

---Toggle the HUD for this session
---@return nil
function M.toggle()
  if not _config then
    return
  end
  _enabled = not enabled(_config)
  M.refresh()
end

---Whether the HUD of the current tabpage is shown
---@return boolean
function M.is_visible()
  return is_open(huds[vim.api.nvim_get_current_tabpage()])
end

---Window of the HUD in the current tabpage
---@return integer?
function M.get_winid()
  local hud = huds[vim.api.nvim_get_current_tabpage()]
  return is_open(hud) and hud.winid or nil
end

---Close all HUDs and forget the config and session toggle
---@return nil
function M.reset()
  for tab, hud in pairs(huds) do
    hide(hud)
    if vim.api.nvim_buf_is_valid(hud.bufnr) then
      vim.api.nvim_buf_delete(hud.bufnr, { force = true })
    end
    huds[tab] = nil
  end
  _config = nil
  _enabled = nil
end

return M
