---@class Radar.Config.Keys
---@field prefix string
---@field lock string
---@field locks string[]
---@field recent string[]
---@field vertical string
---@field horizontal string
---@field tab string
---@field float string

---@class Radar.Config.Behavior
---@field max_recent_files integer
---@field show_empty_message boolean

---@class Radar.Config.Appearance
---@field path_format string
---@field titles Radar.Config.Appearance.Titles

---@class Radar.Config.Appearance.Titles
---@field main string
---@field locks string
---@field recent string

---@class Radar.Config.Windows.FileWindow
---@field config vim.api.keyset.win_config

---@class Radar.Config.Windows.Float.RadarWindow
---@field winblend integer
---@field config vim.api.keyset.win_config

---@class Radar.Config.Windows.Float.EditWindow
---@field width_padding integer
---@field max_height integer
---@field min_width integer

---@class Radar.Config.Windows.Float
---@field hide_on_collision boolean
---@field collision_padding integer
---@field radar Radar.Config.Windows.Float.RadarWindow
---@field edit Radar.Config.Windows.Float.EditWindow

---@class Radar.Config.Windows.Sidebar
---@field position "left"|"right"
---@field width integer

---@class Radar.Config.Windows
---@field file_window Radar.Config.Windows.FileWindow
---@field float Radar.Config.Windows.Float
---@field sidebar Radar.Config.Windows.Sidebar

---@class Radar.Config.Persist
---@field path string
---@field defer_ms integer

---@alias Radar.Config.Mode "float_top_right"|"sidebar_left"|"sidebar_right"

---@class Radar.Config
---@field mode Radar.Config.Mode
---@field keys Radar.Config.Keys
---@field behavior Radar.Config.Behavior
---@field appearance Radar.Config.Appearance
---@field windows Radar.Config.Windows
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
  mode = "float_top_right",

  keys = {
    prefix = "<space>",
    lock = "<space>l",
    locks = { "1", "2", "3", "4", "5", "6", "7", "8", "9" },
    recent = { "a", "s", "d", "f", "g" },
    vertical = "<C-v>",
    horizontal = "<C-s>",
    tab = "<C-t>",
    float = "<C-f>",
  },

  behavior = {
    max_recent_files = 20,
    show_empty_message = true,
  },

  appearance = {
    path_format = ":p:.",
    titles = {
      main = "󰐷  RADAR",
      locks = "󰋱  LOCKED IN",
      recent = "󰽏  NEAR",
    },
  },

  windows = {
    -- Global: file preview window (works in all modes)
    file_window = {
      config = {
        relative = "editor",
        width = 0.8, -- ratio of screen width
        height = 0.7, -- ratio of screen height
        border = "solid",
        title_pos = "center",
        style = "", -- empty string means no style (normal editor)
        zindex = 50,
      },
    },

    -- Float-specific windows and behavior
    float = {
      hide_on_collision = true,
      collision_padding = 50,

      radar = {
        winblend = 25,
        ---@type vim.api.keyset.win_config
        config = {
          relative = "editor",
          anchor = "NW",
          width = 50,
          -- `height` gets calculated dynamically
          row = 1,
          col = math.floor((vim.o.columns - 50) - 2),
          border = "solid",
          style = "minimal",
          title = "󰐷  RADAR",
          title_pos = "left",
          focusable = false,
          zindex = 100,
        },
      },

      edit = {
        width_padding = 10,
        max_height = 20,
        min_width = 60,
      },
    },

    -- Sidebar-specific (future)
    sidebar = {
      position = "right",
      width = 50,
    },
  },

  persist = {
    path = vim.fs.joinpath(vim.fn.stdpath("data"), "radar", "data.json"),
    defer_ms = 500,
  },
}

return M
