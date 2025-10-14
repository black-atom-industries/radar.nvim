local M = {}

---Setup global keymaps (only toggle)
---@param config Radar.Config
---@return nil
function M.setup(config)
  local mini_radar = require("radar.ui.mini_radar")

  -- Global toggle keymap (prefix becomes toggle)
  vim.keymap.set("n", config.keys.prefix, function()
    mini_radar.toggle(config)
  end, { desc = "Toggle Radar" })
end

---Setup buffer-local keymaps for radar window
---@param bufnr integer
---@param config Radar.Config
---@return nil
function M.setup_buffer_local_keymaps(bufnr, config)
  local navigation = require("radar.navigation")
  local mini_radar = require("radar.ui.mini_radar")
  local opts_base = { buffer = bufnr, silent = true, noremap = true, nowait = true }

  -- Close radar
  vim.keymap.set("n", "q", function()
    mini_radar.close()
  end, vim.tbl_extend("force", opts_base, { desc = "Close Radar" }))

  vim.keymap.set("n", "<Esc>", function()
    mini_radar.close()
  end, vim.tbl_extend("force", opts_base, { desc = "Close Radar" }))

  -- Lock current buffer (or source buffer if we're in radar)
  vim.keymap.set("n", config.keys.lock, function()
    local locks = require("radar.locks")
    local persistence = require("radar.persistence")
    local state = require("radar.state")

    -- Use the buffer we opened from, not the radar buffer itself
    locks.lock_current_buffer(state.source_bufnr, config, persistence, mini_radar)
  end, vim.tbl_extend("force", opts_base, { desc = "Lock source buffer" }))

  -- Lock keymaps (1-9)
  M.register_file_keymaps_buffer_local(
    bufnr,
    config.keys.locks,
    navigation.open_lock,
    "Lock",
    config,
    mini_radar
  )

  -- Alternative file (o)
  local alt_label = config.keys.alternative

  vim.keymap.set("n", alt_label, function()
    navigation.open_alternative(nil, config, mini_radar)
  end, vim.tbl_extend("force", opts_base, { desc = "Open alternative file" }))

  vim.keymap.set(
    "n",
    config.keys.vertical .. alt_label,
    function()
      navigation.open_alternative("vsplit", config, mini_radar)
    end,
    vim.tbl_extend("force", opts_base, {
      desc = "Open alternative file in vertical split",
    })
  )

  vim.keymap.set(
    "n",
    config.keys.horizontal .. alt_label,
    function()
      navigation.open_alternative("split", config, mini_radar)
    end,
    vim.tbl_extend("force", opts_base, {
      desc = "Open alternative file in horizontal split",
    })
  )

  vim.keymap.set(
    "n",
    config.keys.tab .. alt_label,
    function()
      navigation.open_alternative("tabedit", config, mini_radar)
    end,
    vim.tbl_extend("force", opts_base, {
      desc = "Open alternative file in new tab",
    })
  )

  vim.keymap.set(
    "n",
    config.keys.float .. alt_label,
    function()
      navigation.open_alternative("float", config, mini_radar)
    end,
    vim.tbl_extend("force", opts_base, {
      desc = "Open alternative file in floating window",
    })
  )

  -- Recent file keymaps (a, s, d, f, g)
  M.register_file_keymaps_buffer_local(
    bufnr,
    config.keys.recent,
    navigation.open_recent,
    "Recent File",
    config,
    mini_radar
  )

  -- Edit locks (e)
  vim.keymap.set("n", "e", function()
    require("radar.ui.edit").edit_locks(config, mini_radar)
  end, vim.tbl_extend("force", opts_base, { desc = "Edit radar locks" }))
end

---Register buffer-local keymaps for a collection of file labels
---@param bufnr integer
---@param labels string[]
---@param open_fn function
---@param desc_prefix string
---@param config Radar.Config
---@param mini_radar_module table
---@return nil
function M.register_file_keymaps_buffer_local(
  bufnr,
  labels,
  open_fn,
  desc_prefix,
  config,
  mini_radar_module
)
  local opts_base = { buffer = bufnr, silent = true, noremap = true, nowait = true }

  for _, label in ipairs(labels) do
    -- Regular open (just the label, no prefix)
    vim.keymap.set(
      "n",
      label,
      function()
        open_fn(label, nil, config, mini_radar_module)
      end,
      vim.tbl_extend("force", opts_base, {
        desc = "Open " .. label .. " " .. desc_prefix,
      })
    )

    -- Vertical split
    vim.keymap.set(
      "n",
      config.keys.vertical .. label,
      function()
        open_fn(label, "vsplit", config, mini_radar_module)
      end,
      vim.tbl_extend("force", opts_base, {
        desc = "Open " .. label .. " " .. desc_prefix .. " in vertical split",
      })
    )

    -- Horizontal split
    vim.keymap.set(
      "n",
      config.keys.horizontal .. label,
      function()
        open_fn(label, "split", config, mini_radar_module)
      end,
      vim.tbl_extend("force", opts_base, {
        desc = "Open " .. label .. " " .. desc_prefix .. " in horizontal split",
      })
    )

    -- New tab
    vim.keymap.set(
      "n",
      config.keys.tab .. label,
      function()
        open_fn(label, "tabedit", config, mini_radar_module)
      end,
      vim.tbl_extend("force", opts_base, {
        desc = "Open " .. label .. " " .. desc_prefix .. " in new tab",
      })
    )

    -- Float window
    vim.keymap.set(
      "n",
      config.keys.float .. label,
      function()
        open_fn(label, "float", config, mini_radar_module)
      end,
      vim.tbl_extend("force", opts_base, {
        desc = "Open " .. label .. " " .. desc_prefix .. " in floating window",
      })
    )
  end
end

return M
