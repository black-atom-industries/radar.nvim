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
    locks = { "1", "2", "3", "4", "5", "6", "7", "8", "9" }, -- num row
    recent = { "a", "s", "d", "f", "g" }, -- home row
    modified = { "q", "w", "e", "r", "t" }, -- upper row
    pr_files = { "z", "x", "c", "v", "b" }, -- bottom row

    -- Navigation modifiers
    vertical = "<C-v>",
    horizontal = "<C-s>",
    tab = "<C-t>",
  },

  ui = {
    mini = {
      position = "right", -- "left" or "right"
      width = 40,
      fixed_width = true,
      title = "󰐷  RADAR",
      title_hl = "@constant",
      sections = {
        locks = {
          header = "󰋱  LOCKED IN",
          header_hl = "@tag.builtin",
          entry_hl = "@function",
        },
        recent = {
          header = "󰽏  NEAR",
          header_hl = "@type",
          entry_hl = "@function",
        },
        empty = {
          show_title = true,
          instructions = true,
        },
      },
      path_format = ":p:.",
      entry_format = "   [%s] %s  ",
      separator = " ",
    },
    edit = {
      win_width_padding = 10,
      max_height = 20,
      min_width = 60,
    },
    full = {}, -- Future full radar config
  },

  behavior = {
    always_show = true,
    deduplicate = true,
    max_session_files = 20,
    defer_persist_ms = 500,
  },

  persist = {
    folder = vim.fs.joinpath(vim.fn.stdpath("data"), "radar"),
    filename = "data.json",
  },
}

return M
