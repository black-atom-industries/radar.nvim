local M = {}

---@class Radar.Config
M.default = {
  keys = {
    prefix = "<space>",
    lock = "l",
    locks = { "1", "2", "3", "4", "5", "6", "7", "8", "9" },
    alternative = nil, -- defaults to prefix (double-tap to open alternative)
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
    tabs_toggle = "<leader>t",
  },

  persist = {
    path = vim.fs.joinpath(vim.fn.stdpath("data"), "radar", "data.json"),
    defer_ms = 500,
  },

  -- Window presets - users can override or add custom presets
  win_presets = {},

  -- Main radar window
  radar = {
    grid_size = { width = 125, height = 20 },
    border = "single",
    position = "center",
    winblend = 0,
    max_recent_files = 25,
    show_empty_message = true,
    titles = {
      main = "󰐷  RADAR",
      locks = "󰋱  LOCKED IN",
      alternative = "  OTHER",
      recent = "󰽏  NEAR",
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

  -- Tabs floating window
  tabs = {
    auto_close = true,
    win_preset = "center",
    win_opts = {
      number = false,
      cursorline = true,
      wrap = false,
    },
  },
}

return M
