local M = {}

---@class Radar.TabBuffer
---@field winid integer
---@field filepath string

---@class Radar.TabData
---@field tabid integer
---@field index integer
---@field is_current boolean
---@field cwd string
---@field buffers Radar.TabBuffer[]

---Get the working directory name for a tab
---@param tabid integer
---@return string
function M.get_tab_cwd(tabid)
  local ok, cwd = pcall(vim.api.nvim_tabpage_get_var, tabid, "cwd")
  if ok and cwd then
    return vim.fn.fnamemodify(cwd, ":t")
  end

  -- Fallback: get cwd from the first window in the tab
  local wins = vim.api.nvim_tabpage_list_wins(tabid)
  if #wins > 0 then
    local win = wins[1]
    local buf = vim.api.nvim_win_get_buf(win)
    local bufname = vim.api.nvim_buf_get_name(buf)
    if bufname ~= "" then
      local dir = vim.fn.fnamemodify(bufname, ":h:t")
      return dir ~= "" and dir or "unnamed"
    end
  end

  return "unnamed"
end

---Check if a window is a floating window
---@param winid integer
---@return boolean
local function is_floating_window(winid)
  local config = vim.api.nvim_win_get_config(winid)
  return config.relative ~= ""
end

---Check if a buffer is a file buffer (not special)
---@param bufnr integer
---@return boolean
local function is_file_buffer(bufnr)
  local buftype = vim.api.nvim_get_option_value("buftype", { buf = bufnr })
  return buftype == ""
end

---Get all tabs with their buffers
---@return Radar.TabData[]
function M.get_tabs_data()
  local tabs = vim.api.nvim_list_tabpages()
  local current_tabid = vim.api.nvim_get_current_tabpage()
  local result = {}

  for index, tabid in ipairs(tabs) do
    local tab_data = {
      tabid = tabid,
      index = index,
      is_current = tabid == current_tabid,
      cwd = M.get_tab_cwd(tabid),
      buffers = {},
    }

    -- Get all windows in this tab
    local wins = vim.api.nvim_tabpage_list_wins(tabid)
    for _, winid in ipairs(wins) do
      -- Skip floating windows
      if not is_floating_window(winid) then
        local bufnr = vim.api.nvim_win_get_buf(winid)
        -- Only include file buffers
        if is_file_buffer(bufnr) then
          local filepath = vim.api.nvim_buf_get_name(bufnr)
          if filepath ~= "" then
            table.insert(tab_data.buffers, {
              winid = winid,
              filepath = filepath,
            })
          end
        end
      end
    end

    table.insert(result, tab_data)
  end

  return result
end

return M
