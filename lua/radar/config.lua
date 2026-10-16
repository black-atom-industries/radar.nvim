local M = {}

---@class Radar.Config
M.default = {
  debug = false,

  keys = {
    prefix = "<space>",
    lock = "l",
    locks = { "1", "2", "3", "4", "5", "6", "7", "8", "9" },
    alternative = "o",
    recent = { "a", "s", "d", "f", "g" },
    tabs_toggle = "<leader>t",
    hud_toggle = "h",
    edit = "e",
    help = "?",
  },

  persist = {
    path = vim.fs.joinpath(vim.fn.stdpath("data"), "radar", "data.json"),
    defer_ms = 500,
  },

  -- Window presets - users can override or add custom presets
  win_presets = {},

  -- Recent files history
  recent = {
    max_files = 10,
  },

  -- HUD with the current and alternative file, locks and recent files
  hud = {
    enabled = true,
    max_locks = 5,
    max_recent = 3,
  },

  -- Lock label editor window
  radar_edit = {
    win_opts = {
      number = true,
      relativenumber = false,
      cursorline = true,
      wrap = false,
    },
  },

  -- File float window
  file_float = {
    win_preset = "center_narrow",
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
