local M = {}

M.constants = {
  ns_mini_radar = vim.api.nvim_create_namespace("radar.win.mini"),
}

---@class Radar.Config
M.default = {
  mode = "float_top_right",

  keys = {
    prefix = "<space>",
    lock = "l",
    locks = { "1", "2", "3", "4", "5", "6", "7", "8", "9" },
    alternative = "<space>",
    recent = { "a", "s", "d", "f", "g" },
    vertical = "<C-v>",
    horizontal = "<C-s>",
    tab = "<C-t>",
    float = "<C-f>",
    line = {
      open = "<CR>",
      vertical = "V",
      horizontal = "S",
      tab = "T",
      float = "F",
    },
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
      alternative = "  OTHER",
      recent = "󰽏  NEAR",
    },
  },

  persist = {
    path = vim.fs.joinpath(vim.fn.stdpath("data"), "radar", "data.json"),
    defer_ms = 500,
  },

  windows = {
    float = {
      radar = {
        winblend = 0,
        config = {
          relative = "cursor",
          anchor = "NW",
          width = 75,
          -- `height` gets calculated dynamically
          row = 1,
          col = 0,
          border = "solid",
          style = "minimal",
          title = "󰐷  RADAR",
          title_pos = "left",
          focusable = true,
          zindex = 100,
        },
      },
      edit = {
        width_padding = 10,
        max_height = 20,
        min_width = 60,
      },
    },

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
  },
}

return M
