local M = {}

M.constants = {
  ns_mini_radar = vim.api.nvim_create_namespace("radar.win.mini"),
}

---@class Radar.Config
M.default = {
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
        config = "center",
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
        "center",
        {
          width = math.floor(vim.o.columns * 0.8),
          height = math.floor(vim.o.lines * 0.7),
          zindex = 50,
        },
      },
    },
  },
}

return M
