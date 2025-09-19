---@class Radar.Config.Keys
---@field prefix string
---@field lock string
---@field locks string[]
---@field recent string[]
---@field vertical string
---@field horizontal string
---@field tab string

---@class Radar.Config.Persist
---@field folder string
---@field filename string

---@class Radar.Config
---@field keys Radar.Config.Keys
---@field path_format string
---@field win vim.api.keyset.win_config
---@field persist Radar.Config.Persist

---@class Radar.Lock
---@field label string
---@field filename string

---@class Radar.ProjectData
---@field locks Radar.Lock[]

---@class Radar.BranchData
---@field [string] Radar.ProjectData

---@class Radar.PersistenceData
---@field [string] Radar.BranchData

local M = {}

M.constants = {
  ns_mini_radar = vim.api.nvim_create_namespace("radar.win.mini"),
}

---@class Radar.Config
M.default = {
  keys = {
    prefix = "<space>",
    lock = ",<space>",
    locks = { "1", "2", "3", "4", "5", "6", "7", "8", "9" },
    recent = { "a", "s", "d", "f", "g" },
    vertical = "<C-v>",
    horizontal = "<C-s>",
    tab = "<C-t>",
    float = "<C-f>",
  },

  -- UI Settings
  width = 50,
  winblend = 25,
  path_format = ":p:.",
  show_empty_message = true,

  -- Headers and styling
  locks_header = "󰋱  LOCKED IN",
  recent_header = "󰽏  NEAR",
  title = "󰐷  RADAR",

  -- Edit window
  edit_width_padding = 10,
  edit_max_height = 20,
  edit_min_width = 60,

  -- Float editor window
  float_editor = {
    relative = "editor",
    width = 0.8,  -- ratio of screen width
    height = 0.7, -- ratio of screen height
    border = "solid",
    title_pos = "center",
    style = "", -- empty string means no style (normal editor)
    zindex = 50,
  },

  -- Behavior
  max_session_files = 20,
  defer_persist_ms = 500,
  hide_on_collision = true,
  collision_padding = 2,

  -- Persistence
  persist_path = vim.fs.joinpath(vim.fn.stdpath("data"), "radar", "data.json"),
}

return M
