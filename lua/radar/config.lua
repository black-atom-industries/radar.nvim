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

  persist = {
    path = vim.fs.joinpath(vim.fn.stdpath("data"), "radar", "data.json"),
    defer_ms = 500,
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
}

return M
