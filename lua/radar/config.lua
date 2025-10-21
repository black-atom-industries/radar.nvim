local M = {}

---@class Radar.Config
M.default = {
  keys = {
    prefix = "<space>",
    lock = "l",
    locks = { "1", "2", "3", "4", "5", "6", "7", "8", "9" },
    alternative = "o",
    recent = { "q", "w", "e", "r", "t" },
    modified = { "a", "s", "d", "f", "g" },
    pull_request = { "z", "x", "c", "v", "b" },
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

  persist = {
    path = vim.fs.joinpath(vim.fn.stdpath("data"), "radar", "data.json"),
    defer_ms = 500,
  },

  -- Window presets - users can override or add custom presets
  win_presets = {},

  -- Main radar window
  radar = {
    grid_size = { width = 135, height = 35 },
    position = "center",
    winblend = 0,
    max_recent_files = 20,
    show_empty_message = true,
    titles = {
      main = "󰐷  RADAR",
      locks = "󰋱  LOCKED IN",
      alternative = "  OTHER",
      recent = "󰽏  NEAR",
      modified = "󰷉  GIT STATUS",
      pull_request = "  PULL REQUEST",
      hints = "  KEYS",
    },
    win_opts = {
      number = false,
      relativenumber = false,
      cursorline = true,
      wrap = false,
    },
  },

  -- Lock label editor window
  radar_edit = {
    win_preset = "center",
    win_opts = {
      number = true,
      relativenumber = false,
      cursorline = true,
      wrap = false,
    },
  },

  -- File float window
  file_float = {
    win_preset = "center_large",
    win_opts = {
      number = true,
      relativenumber = true,
      cursorline = true,
      wrap = true,
    },
  },
}

return M
