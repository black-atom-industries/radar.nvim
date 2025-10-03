local M = {}

---Open a file with the given command, ensuring radar exists
---@param filepath string? File path to open
---@param open_cmd? string Command to open file (edit, vsplit, split, tabedit, float)
---@param config Radar.Config
---@param mini_radar_module table
---@return nil
function M.open_file(filepath, open_cmd, config, mini_radar_module)
  if not filepath then
    return
  end

  mini_radar_module.ensure_exists(config)

  local path = vim.fn.fnameescape(filepath)
  open_cmd = open_cmd or "edit"

  if open_cmd == "float" then
    -- Create floating window for file editing
    local buf = vim.api.nvim_create_buf(false, false)

    -- Read file into the new buffer without changing main window
    if vim.fn.filereadable(vim.fn.expand(filepath)) == 1 then
      local lines = vim.fn.readfile(vim.fn.expand(filepath))
      vim.api.nvim_buf_set_lines(buf, 0, -1, false, lines)
      vim.api.nvim_buf_set_name(buf, filepath)
      vim.api.nvim_set_option_value("modified", false, { buf = buf })
      vim.api.nvim_set_option_value(
        "filetype",
        vim.filetype.match({ filename = filepath }) or "",
        { buf = buf }
      )
    end

    -- Start with base config and calculate dimensions
    local win_opts =
      vim.tbl_deep_extend("force", {}, config.windows.file_window.config)

    -- Calculate actual pixel dimensions from ratios
    local width = math.floor(vim.o.columns * win_opts.width)
    local height = math.floor(vim.o.lines * win_opts.height)

    -- Center the window
    local row = math.floor((vim.o.lines - height) / 2)
    local col = math.floor((vim.o.columns - width) / 2)

    -- Override with calculated values and add title
    win_opts.width = width
    win_opts.height = height
    win_opts.row = row
    win_opts.col = col
    win_opts.title = " " .. vim.fn.fnamemodify(filepath, ":.") .. " "

    local win = vim.api.nvim_open_win(buf, true, win_opts)

    -- Add keymap to save and close the floating window
    vim.api.nvim_buf_set_keymap(buf, "n", "q", "", {
      noremap = true,
      silent = true,
      desc = "Save and close floating window",
      callback = function()
        -- Save file if modified, using write! to overwrite
        if vim.api.nvim_get_option_value("modified", { buf = buf }) then
          vim.cmd("write!")
        end
        -- Close the window
        if vim.api.nvim_win_is_valid(win) then
          vim.api.nvim_win_close(win, true)
        end
      end,
    })
  else
    vim.cmd(open_cmd .. " " .. path)
  end
end

---Open lock by label
---@param label string
---@param open_cmd? string Command to open file (edit, vsplit, split, tabedit, float)
---@param config Radar.Config
---@param mini_radar_module table
---@return nil
function M.open_lock(label, open_cmd, config, mini_radar_module)
  local state = require("radar.state")
  local lock = state.get_lock_from_label(tostring(label))
  if lock then
    M.open_file(lock.filename, open_cmd, config, mini_radar_module)
  end
end

---Open recent file by label
---@param label string
---@param open_cmd? string Command to open file (edit, vsplit, split, tabedit, float)
---@param config Radar.Config
---@param mini_radar_module table
---@return nil
function M.open_recent(label, open_cmd, config, mini_radar_module)
  local state = require("radar.state")
  -- Find the recent file by label
  for i, recent_label in ipairs(config.keys.recent) do
    if recent_label == label and state.recent_files[i] then
      M.open_file(state.recent_files[i], open_cmd, config, mini_radar_module)
      return
    end
  end
end

---Register keymaps for a collection of file labels
---@param labels string[] Array of labels
---@param open_fn function Function to open files by label
---@param desc_prefix string Description prefix for keymap descriptions
---@param config Radar.Config
---@param mini_radar_module table
---@return nil
function M.register_file_keymaps(
  labels,
  open_fn,
  desc_prefix,
  config,
  mini_radar_module
)
  for _, label in ipairs(labels) do
    local prefix = config.keys.prefix

    -- Regular open
    vim.keymap.set("n", prefix .. label, function()
      open_fn(label, nil, config, mini_radar_module)
    end, { desc = "Open " .. label .. " " .. desc_prefix })

    -- Vertical split
    vim.keymap.set("n", prefix .. config.keys.vertical .. label, function()
      open_fn(label, "vsplit", config, mini_radar_module)
    end, { desc = "Open " .. label .. " " .. desc_prefix .. " in vertical split" })

    -- Horizontal split
    vim.keymap.set("n", prefix .. config.keys.horizontal .. label, function()
      open_fn(label, "split", config, mini_radar_module)
    end, {
      desc = "Open " .. label .. " " .. desc_prefix .. " in horizontal split",
    })

    -- New tab
    vim.keymap.set("n", prefix .. config.keys.tab .. label, function()
      open_fn(label, "tabedit", config, mini_radar_module)
    end, { desc = "Open " .. label .. " " .. desc_prefix .. " in new tab" })

    -- Float window
    vim.keymap.set("n", prefix .. config.keys.float .. label, function()
      open_fn(label, "float", config, mini_radar_module)
    end, {
      desc = "Open " .. label .. " " .. desc_prefix .. " in floating window",
    })
  end
end

return M
