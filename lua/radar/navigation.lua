local M = {}

---Get file path from current line in radar window
---@param config Radar.Config
---@return string? filepath
function M.get_file_from_line(config)
  local mini_radar = require("radar.ui.mini_radar")
  local bufid = mini_radar.get_bufid()
  if not bufid then
    return nil
  end

  local current_line_nr = vim.api.nvim_win_get_cursor(0)[1]
  local lines = vim.api.nvim_buf_get_lines(bufid, 0, -1, false)
  local state = require("radar.state")

  -- Track which section we're in and the index within that section
  local current_section = nil
  local section_index = 0

  for i, line in ipairs(lines) do
    -- Section headers - reset section tracking
    if line == config.radar.titles.locks then
      current_section = "locks"
      section_index = 0
    elseif line == config.radar.titles.alternative then
      current_section = "alternative"
      section_index = 0
    elseif line == config.radar.titles.recent then
      current_section = "recent"
      section_index = 0
    elseif line ~= "" and line ~= " " and current_section then
      -- This is a file entry line - increment index
      section_index = section_index + 1

      -- Check if this is our target line
      if i == current_line_nr then
        -- Return the file based on section and index
        if current_section == "locks" and state.locks[section_index] then
          return state.locks[section_index].filename
        elseif current_section == "alternative" then
          local alternative = require("radar.alternative")
          return alternative.get_alternative_file()
        elseif current_section == "recent" and state.recent_files[section_index] then
          return state.recent_files[section_index]
        end
      end
    end
  end

  return nil
end

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

  -- Close radar first, so file opens in the previous window
  mini_radar_module.close()

  local path = vim.fn.fnameescape(filepath)
  open_cmd = open_cmd or "edit"

  if open_cmd == "float" then
    -- Resolve window config from preset
    local window = require("radar.window")
    local win_opts = window.resolve_config(config, config.file_float.win_preset, {
      title = " " .. vim.fn.fnamemodify(filepath, ":.") .. " ",
    })

    -- Create scratch buffer initially
    local buf = vim.api.nvim_create_buf(false, true)
    local win = vim.api.nvim_open_win(buf, true, win_opts)

    -- Apply window-local options
    for opt, value in pairs(config.file_float.win_opts) do
      vim.api.nvim_set_option_value(opt, value, { win = win })
    end

    -- Now edit the file in the floating window (this triggers all autocmds, treesitter, etc.)
    ---@diagnostic disable-next-line: undefined-field
    vim.cmd.edit(path)

    -- Get the actual buffer after editing
    buf = vim.api.nvim_win_get_buf(win)

    -- Add keymap to save and close the floating window
    vim.api.nvim_buf_set_keymap(buf, "n", "q", "", {
      noremap = true,
      silent = true,
      desc = "Save and close floating window",
      callback = function()
        -- Save file if modified
        local current_buf = vim.api.nvim_win_get_buf(win)
        if
          vim.api.nvim_buf_is_valid(current_buf)
          and vim.api.nvim_get_option_value("modified", { buf = current_buf })
        then
          vim.cmd("write")
        end
        -- Close the window
        if vim.api.nvim_win_is_valid(win) then
          vim.api.nvim_win_close(win, false)
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
  local lock = state.get_lock_by_field("label", tostring(label))
  if lock then
    M.open_file(lock.filename, open_cmd, config, mini_radar_module)
  end
end

---Open alternative file
---@param open_cmd? string Command to open file (edit, vsplit, split, tabedit, float)
---@param config Radar.Config
---@param mini_radar_module table
---@return nil
function M.open_alternative(open_cmd, config, mini_radar_module)
  local state = require("radar.state")
  -- Use the alternate file captured when radar was opened
  local alt_file = state.source_alt_file
  if alt_file then
    M.open_file(alt_file, open_cmd, config, mini_radar_module)
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

---Open file from current line in radar window
---@param open_cmd? string Command to open file (edit, vsplit, split, tabedit, float)
---@param config Radar.Config
---@param mini_radar_module table
---@return nil
function M.open_file_from_line(open_cmd, config, mini_radar_module)
  local filepath = M.get_file_from_line(config)
  if filepath then
    M.open_file(filepath, open_cmd, config, mini_radar_module)
  end
end

return M
