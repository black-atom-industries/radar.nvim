local M = {}

local state = require("radar.state")
local tabs = require("radar.tabs")
local window = require("radar.window")

---Cut item clipboard for cut/paste operations
---@type { type: "buffer"|string, filepath?: string, buffers?: string[] }?
local cut_item = nil

---Line number of the currently cut item (for visual highlight)
---@type integer?
local cut_line_num = nil

---Check if tabs window exists
---@return boolean
function M.exists()
  return state.is_tabs_window_valid()
end

---Close tabs window
---@return nil
function M.close()
  state.close_tabs_window()
end

---Create highlight groups for git and LSP indicators from theme colors
---Pill/badge style: labels use Comment fg on DiffChange/VirtualTextHint bg,
---values use semantic sign colors (mini.diff / diagnostic) with matching bg.
local function setup_highlights()
  local function get_attr(group, attr)
    local hl = vim.api.nvim_get_hl(0, { name = group, link = false })
    local val = hl[attr]
    return val and string.format("#%06x", val) or nil
  end

  local git_bg = get_attr("DiffChange", "bg")
  local lsp_bg = get_attr("DiagnosticVirtualTextHint", "bg")
  local muted = get_attr("Comment", "fg")

  -- Git indicator groups
  vim.api.nvim_set_hl(0, "RadarTabsGitSection", { bg = git_bg })
  vim.api.nvim_set_hl(0, "RadarTabsGitLabel", { fg = muted, bg = git_bg })
  vim.api.nvim_set_hl(0, "RadarTabsGitAdd", { fg = get_attr("MiniDiffSignAdd", "fg"), bg = git_bg })
  vim.api.nvim_set_hl(0, "RadarTabsGitChange", { fg = get_attr("MiniDiffSignChange", "fg"), bg = git_bg })
  vim.api.nvim_set_hl(0, "RadarTabsGitDelete", { fg = get_attr("MiniDiffSignDelete", "fg"), bg = git_bg })

  -- LSP indicator groups
  vim.api.nvim_set_hl(0, "RadarTabsLspSection", { bg = lsp_bg })
  vim.api.nvim_set_hl(0, "RadarTabsLspLabel", { fg = muted, bg = lsp_bg })
  vim.api.nvim_set_hl(0, "RadarTabsLspError", { fg = get_attr("DiagnosticSignError", "fg"), bg = lsp_bg })
  vim.api.nvim_set_hl(0, "RadarTabsLspWarn", { fg = get_attr("DiagnosticSignWarn", "fg"), bg = lsp_bg })
  vim.api.nvim_set_hl(0, "RadarTabsLspInfo", { fg = get_attr("DiagnosticSignInfo", "fg"), bg = lsp_bg })
  vim.api.nvim_set_hl(0, "RadarTabsLspHint", { fg = get_attr("DiagnosticSignHint", "fg"), bg = lsp_bg })

  -- Tab header groups (bold for all, standout fg for active)
  local tab_bg = get_attr("CursorLine", "bg")
  local active_fg = get_attr("Title", "fg")

  vim.api.nvim_set_hl(0, "RadarTabsTabHeader", { bold = true, bg = tab_bg })
  vim.api.nvim_set_hl(0, "RadarTabsTabHeaderActive", { bold = true, fg = active_fg, bg = tab_bg })
end

-- Create highlight groups on load and rebuild on theme change
setup_highlights()
local tabs_augroup = vim.api.nvim_create_augroup("RadarTabsUI", { clear = true })
vim.api.nvim_create_autocmd("ColorScheme", {
  group = tabs_augroup,
  callback = setup_highlights,
  desc = "Rebuild tabs UI indicator highlights on theme change",
})

---Build git and LSP indicator string for a buffer
---@param bufnr integer
---@return string
local function get_buffer_indicators(bufnr)
  if bufnr <= 0 then
    return ""
  end

  local parts = {}

  -- Git indicators (via mini.diff)
  local ok, summary = pcall(function()
    return vim.b[bufnr].minidiff_summary
  end)
  if ok and summary then
    local git_parts = {}
    if (summary.add or 0) > 0 then
      table.insert(git_parts, "+" .. summary.add)
    end
    if (summary.change or 0) > 0 then
      table.insert(git_parts, "~" .. summary.change)
    end
    if (summary.delete or 0) > 0 then
      table.insert(git_parts, "-" .. summary.delete)
    end
    if #git_parts > 0 then
      table.insert(parts, "[GIT " .. table.concat(git_parts, " ") .. "]")
    end
  end

  -- LSP diagnostic indicators
  local diag_parts = {}
  local severities = { ERROR = "E", WARN = "W", INFO = "I", HINT = "H" }
  for severity, label in pairs(severities) do
    local ok, count = pcall(function()
      return #vim.diagnostic.get(bufnr, {
        severity = vim.diagnostic.severity[severity],
      })
    end)
    if ok and count and count > 0 then
      table.insert(diag_parts, label .. count)
    end
  end
  if #diag_parts > 0 then
    table.insert(parts, "[LSP " .. table.concat(diag_parts, " ") .. "]")
  end

  if #parts > 0 then
    return "  " .. table.concat(parts, " ")
  end
  return ""
end

---Align string to the left with right-aligned suffix
---@param left string
---@param suffix string
---@param total_width integer Total columns available (accounting for border)
---@param indent integer Leading indentation in spaces
---@return string
local function right_align_line(left, suffix, total_width, indent)
  if suffix == "" then
    return left
  end

  local left_width = vim.fn.strdisplaywidth(left)
  local suffix_width = vim.fn.strdisplaywidth(suffix)
  local min_gap = 3
  local avail = total_width - suffix_width
  local padding = math.max(min_gap, avail - left_width)
  if padding < min_gap then
    padding = min_gap
  end
  return left .. string.rep(" ", padding) .. suffix
end

---Build the content lines and line mapping
---@param tabs_data Radar.TabData[]
---@param win_width integer Width of the window in columns (excluding border)
---@return string[], Radar.TabsLineMapping[]
local function build_content(tabs_data, win_width)
  local lines = {}
  local line_mapping = {}

  for _, tab in ipairs(tabs_data) do
    -- Tab header line
    local current_marker = tab.is_current and "*" or " "
    local tab_line =
      string.format("%sTab %d (%s)", current_marker, tab.index, tab.cwd)
    table.insert(lines, tab_line)
    table.insert(line_mapping, { tabid = tab.tabid })

    -- Buffer lines (indented)
    for _, buf in ipairs(tab.buffers) do
      local filepath = vim.fn.fnamemodify(buf.filepath, ":p:.")
      local bufnr = vim.fn.bufnr(buf.filepath)
      local indicators = get_buffer_indicators(bufnr)
      local left = "    " .. filepath
      local buf_line = right_align_line(left, indicators, win_width, 4)
      table.insert(lines, buf_line)
      table.insert(line_mapping, {
        tabid = tab.tabid,
        winid = buf.winid,
        filepath = buf.filepath,
      })
    end
  end

  -- Handle empty state
  if #lines == 0 then
    table.insert(lines, " No tabs with files")
    table.insert(line_mapping, {})
  end

  return lines, line_mapping
end

---Apply highlights to the tabs buffer
---@param bufnr integer
---@param tabs_data Radar.TabData[]
local function apply_highlights(bufnr, tabs_data)
  local ns = vim.api.nvim_create_namespace("radar.tabs")
  vim.api.nvim_buf_clear_namespace(bufnr, ns, 0, -1)

  local lines = vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)
  local line_idx = 0

  for _, tab in ipairs(tabs_data) do
    -- Highlight tab header (all get bold + subtle bg, active gets standout fg)
    if line_idx < #lines then
      local hl_group = tab.is_current and "RadarTabsTabHeaderActive" or "RadarTabsTabHeader"
      vim.api.nvim_buf_set_extmark(bufnr, ns, line_idx, 0, {
        end_col = #lines[line_idx + 1],
        hl_group = hl_group,
      })
    end
    line_idx = line_idx + 1

    -- Buffer lines
    for _ in ipairs(tab.buffers) do
      line_idx = line_idx + 1
    end
  end

  -- Highlight the cut line if there's an active cut item
  if cut_line_num and cut_line_num >= 1 and cut_line_num <= #lines then
    local cut_line = lines[cut_line_num]
    if cut_line and #cut_line > 0 then
      vim.api.nvim_buf_set_extmark(bufnr, ns, cut_line_num - 1, 0, {
        end_col = #cut_line,
        hl_group = "@comment",
      })
    end
  end

  -- Highlight git and LSP indicators on buffer lines (pill/badge style)
  local indicator_sections = {
    {
      label = "[GIT",
      section_hl = "RadarTabsGitSection",
      label_hl = "RadarTabsGitLabel",
      tokens = {
        { pattern = "([+])%d+", hl = "RadarTabsGitAdd" },
        { pattern = "([~])%d+", hl = "RadarTabsGitChange" },
        { pattern = "([-])%d+", hl = "RadarTabsGitDelete" },
      },
    },
    {
      label = "[LSP",
      section_hl = "RadarTabsLspSection",
      label_hl = "RadarTabsLspLabel",
      tokens = {
        { pattern = "([E])%d+", hl = "RadarTabsLspError" },
        { pattern = "([W])%d+", hl = "RadarTabsLspWarn" },
        { pattern = "([I])%d+", hl = "RadarTabsLspInfo" },
        { pattern = "([H])%d+", hl = "RadarTabsLspHint" },
      },
    },
  }

  for line_num, line in ipairs(lines) do
    for _, section in ipairs(indicator_sections) do
      local start_pos = line:find(section.label, 1, true)
      if start_pos then
        -- Find the closing bracket to scope the section
        local end_pos = line:find("]", start_pos + 1, true)
        if end_pos then
          -- Step 1: Fill the full section background (creates the pill)
          vim.api.nvim_buf_set_extmark(bufnr, ns, line_num - 1, start_pos - 1, {
            end_col = end_pos,
            hl_group = section.section_hl,
          })

          -- Step 2: Overlay the label text (muted fg + matching bg)
          vim.api.nvim_buf_set_extmark(bufnr, ns, line_num - 1, start_pos - 1, {
            end_col = start_pos + 3,
            hl_group = section.label_hl,
          })

          -- Step 3: Overlay individual values with semantic colors + matching bg
          for _, token in ipairs(section.tokens) do
            local pos_start, pos_end = line:find(token.pattern, start_pos)
            while pos_start and pos_start <= end_pos do
              vim.api.nvim_buf_set_extmark(bufnr, ns, line_num - 1, pos_start - 1, {
                end_col = pos_end,
                hl_group = token.hl,
              })
              pos_start, pos_end = line:find(token.pattern, pos_end + 1)
            end
          end
        end
      end
    end
  end
end

---Setup keymaps for the tabs buffer
---@param bufnr integer
---@param config Radar.Config
local function setup_keymaps(bufnr, config)
  local opts = { buffer = bufnr, silent = true, noremap = true, nowait = true }

  -- Jump to tab/buffer
  vim.keymap.set("n", "<CR>", function()
    M.jump_to_line(config)
  end, vim.tbl_extend("force", opts, { desc = "Jump to tab/buffer" }))

  -- Close
  vim.keymap.set("n", "q", function()
    M.close()
  end, vim.tbl_extend("force", opts, { desc = "Close tabs window" }))

  vim.keymap.set("n", "<Esc>", function()
    M.close()
  end, vim.tbl_extend("force", opts, { desc = "Close tabs window" }))

  -- Delete buffer / close tab
  vim.keymap.set("n", "x", function()
    M.delete_line(config)
  end, vim.tbl_extend("force", opts, { desc = "Delete buffer/close tab" }))

  -- Make tab/buffer the only one
  vim.keymap.set("n", "o", function()
    M.only_line(config)
  end, vim.tbl_extend("force", opts, { desc = "Make tab/buffer the only one" }))

  -- New tab
  vim.keymap.set("n", "n", function()
    M.new_line(config)
  end, vim.tbl_extend("force", opts, { desc = "New tab" }))

  -- Vertical split
  vim.keymap.set("n", "v", function()
    M.vsplit_line(config)
  end, vim.tbl_extend("force", opts, { desc = "Vertical split" }))

  -- Horizontal split
  vim.keymap.set("n", "s", function()
    M.split_line(config)
  end, vim.tbl_extend("force", opts, { desc = "Horizontal split" }))

  -- Cut buffer/tab into clipboard
  vim.keymap.set("n", "dd", function()
    M.cut_line(config)
  end, vim.tbl_extend("force", opts, { desc = "Cut tab/buffer" }))

  -- Paste cut item after cursor
  vim.keymap.set("n", "p", function()
    M.paste_line(config)
  end, vim.tbl_extend("force", opts, { desc = "Paste cut tab/buffer" }))

  -- Paste cut item before cursor
  vim.keymap.set("n", "P", function()
    M.paste_line_before(config)
  end, vim.tbl_extend("force", opts, { desc = "Paste cut tab/buffer before" }))
end

---Open the tabs floating window
---@param config Radar.Config
---@return nil
function M.open(config)
  -- Capture the source buffer before creating the tabs window
  local source_buf = vim.api.nvim_get_current_buf()
  local source_filepath = vim.api.nvim_buf_get_name(source_buf)
  local source_tabid = vim.api.nvim_get_current_tabpage()

  -- Resolve window config from preset (before building content to get width)
  local win_config = window.resolve_config(config, config.tabs.win_preset, {
    title = "  TABS ",
    footer = " [CR]jump [x]close [o]only [v]vsp [s]hsp [n]tab [dd]cut [p]paste [q]quit ",
    footer_pos = "left",
    border = "solid",
  })

  -- Get tabs data
  local tabs_data = tabs.get_tabs_data()

  -- Build content with right-aligned indicators
  local content_width = win_config.width - 2 -- subtract border
  local lines, line_mapping = build_content(tabs_data, content_width)
  state.tabs_line_mapping = line_mapping

  -- Create buffer
  local bufnr = vim.api.nvim_create_buf(false, true)
  vim.api.nvim_set_option_value("buftype", "nofile", { buf = bufnr })
  vim.api.nvim_set_option_value("bufhidden", "wipe", { buf = bufnr })
  vim.api.nvim_set_option_value("swapfile", false, { buf = bufnr })

  -- Set content
  vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, lines)
  vim.api.nvim_set_option_value("modifiable", false, { buf = bufnr })

  -- Setup keymaps
  setup_keymaps(bufnr, config)

  -- Store buffer id
  state.tabs_bufid = bufnr

  local winid = vim.api.nvim_open_win(bufnr, true, win_config)

  -- Store window id
  state.tabs_winid = winid

  -- Apply window options
  for opt, value in pairs(config.tabs.win_opts) do
    vim.api.nvim_set_option_value(opt, value, { win = winid })
  end

  -- Apply highlights
  apply_highlights(bufnr, tabs_data)

  -- Position cursor on the source buffer's line
  local cursor_line = 1

  -- Find the line matching current tab + buffer
  for i, entry in ipairs(line_mapping) do
    if entry.tabid == source_tabid then
      if entry.filepath and entry.filepath == source_filepath then
        -- Exact buffer match (highest priority)
        cursor_line = i
        break
      elseif cursor_line == 1 then
        -- Tab header match (fallback if no buffer found)
        cursor_line = i
      end
    end
  end

  vim.api.nvim_win_set_cursor(winid, { cursor_line, 0 })
end

---Toggle tabs window
---@param config Radar.Config
---@return nil
function M.toggle(config)
  if M.exists() then
    M.close()
  else
    M.open(config)
  end
end

---Update tabs window content
---@param config Radar.Config
---@return nil
function M.update(config)
  if not M.exists() then
    return
  end

  -- Get fresh data
  local tabs_data = tabs.get_tabs_data()

  -- Determine window width for alignment
  local content_width = 73 -- fallback
  if state.tabs_winid and vim.api.nvim_win_is_valid(state.tabs_winid) then
    content_width = vim.api.nvim_win_get_width(state.tabs_winid) - 2
  end

  local lines, line_mapping = build_content(tabs_data, content_width)
  state.tabs_line_mapping = line_mapping

  local bufnr = state.tabs_bufid
  if not bufnr or not vim.api.nvim_buf_is_valid(bufnr) then
    return
  end

  -- Update content
  vim.api.nvim_set_option_value("modifiable", true, { buf = bufnr })
  vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, lines)
  vim.api.nvim_set_option_value("modifiable", false, { buf = bufnr })

  -- Re-apply highlights
  apply_highlights(bufnr, tabs_data)
end

---Delete the buffer or close the tab on the current line
---@param config Radar.Config
---@return nil
function M.delete_line(config)
  if not M.exists() then
    return
  end

  local cursor = vim.api.nvim_win_get_cursor(state.tabs_winid)
  local line_num = cursor[1]
  local item = state.tabs_line_mapping[line_num]

  if not item or not item.tabid then
    return
  end

  if item.winid then
    -- Buffer line: close the window (not the buffer, which may be open elsewhere)
    local ok, err = pcall(vim.api.nvim_win_close, item.winid, false)
    if not ok then
      vim.notify("Cannot close window: " .. err, vim.log.levels.WARN)
      return
    end
  else
    -- Tab header line: close the tab
    local tab_count = #vim.api.nvim_list_tabpages()
    if tab_count <= 1 then
      vim.notify("Cannot close the last tab", vim.log.levels.WARN)
      return
    end

    local ok, err =
      pcall(vim.cmd, "tabclose " .. vim.api.nvim_tabpage_get_number(item.tabid))
    if not ok then
      vim.notify("Cannot close tab: " .. err, vim.log.levels.WARN)
      return
    end
  end

  -- Refresh the tabs window
  M.update(config)

  -- Clamp cursor if past the new last line
  if
    M.exists()
    and state.tabs_bufid
    and vim.api.nvim_buf_is_valid(state.tabs_bufid)
  then
    local new_count = vim.api.nvim_buf_line_count(state.tabs_bufid)
    if line_num > new_count then
      vim.api.nvim_win_set_cursor(state.tabs_winid, { math.max(1, new_count), 0 })
    end
  end
end

---Make the tab or buffer the only one (tabonly/only)
---@param config Radar.Config
---@return nil
function M.only_line(config)
  if not M.exists() then
    return
  end

  local cursor = vim.api.nvim_win_get_cursor(state.tabs_winid)
  local line_num = cursor[1]
  local item = state.tabs_line_mapping[line_num]

  if not item or not item.tabid then
    return
  end

  -- Close the tabs window first
  M.close()

  if item.winid then
    -- Buffer line: switch to this window, then close all other windows in the tab
    vim.api.nvim_set_current_win(item.winid)
    vim.cmd("only")
  else
    -- Tab header line: switch to this tab, then close all other tabs
    local tab_win = vim.api.nvim_tabpage_get_win(item.tabid)
    vim.api.nvim_set_current_win(tab_win)
    vim.cmd("tabonly")
  end
end

---Create a new tab from the current tab header line
---@param config Radar.Config
---@return nil
function M.new_line(config)
  if not M.exists() then
    return
  end

  local cursor = vim.api.nvim_win_get_cursor(state.tabs_winid)
  local line_num = cursor[1]
  local item = state.tabs_line_mapping[line_num]

  if not item or not item.tabid or item.winid then
    return
  end

  -- Close the tabs window first
  M.close()

  -- Tab header line: create a new tab
  vim.cmd("tabnew")
end

---Create a vertical split from the current buffer line
---@param config Radar.Config
---@return nil
function M.vsplit_line(config)
  if not M.exists() then
    return
  end

  local cursor = vim.api.nvim_win_get_cursor(state.tabs_winid)
  local line_num = cursor[1]
  local item = state.tabs_line_mapping[line_num]

  if not item or not item.winid then
    return
  end

  -- Close the tabs window first
  M.close()

  vim.api.nvim_set_current_win(item.winid)
  vim.cmd("vsplit")
end

---Create a horizontal split from the current buffer line
---@param config Radar.Config
---@return nil
function M.split_line(config)
  if not M.exists() then
    return
  end

  local cursor = vim.api.nvim_win_get_cursor(state.tabs_winid)
  local line_num = cursor[1]
  local item = state.tabs_line_mapping[line_num]

  if not item or not item.winid then
    return
  end

  -- Close the tabs window first
  M.close()

  vim.api.nvim_set_current_win(item.winid)
  vim.cmd("split")
end

---Cut the tab or buffer on the current line (store in clipboard, don't close)
---@param config Radar.Config
---@return nil
function M.cut_line(config)
  if not M.exists() then
    return
  end

  local cursor = vim.api.nvim_win_get_cursor(state.tabs_winid)
  local line_num = cursor[1]
  local item = state.tabs_line_mapping[line_num]

  if not item or not item.tabid then
    return
  end

  if item.winid then
    -- Buffer line: store buffer info WITHOUT closing the window
    if not item.filepath then
      return
    end
    cut_item = { type = "buffer", filepath = item.filepath, winid = item.winid }
  else
    -- Tab header line: store tab info WITHOUT closing the tab
    local buffer_paths = {}
    local wins = vim.api.nvim_tabpage_list_wins(item.tabid)
    for _, winid in ipairs(wins) do
      local bufnr = vim.api.nvim_win_get_buf(winid)
      local filepath = vim.api.nvim_buf_get_name(bufnr)
      if filepath ~= "" then
        table.insert(buffer_paths, filepath)
      end
    end
    cut_item = { type = "tab", buffers = buffer_paths, tabid = item.tabid }
  end

  cut_line_num = line_num

  -- Re-apply highlights to visually mark the cut line
  if M.exists() and state.tabs_bufid and vim.api.nvim_buf_is_valid(state.tabs_bufid) then
    local tabs_data = tabs.get_tabs_data()
    apply_highlights(state.tabs_bufid, tabs_data)
  end

  vim.notify("Cut " .. cut_item.type .. " — press p to paste it", vim.log.levels.INFO)
end

---Paste the cut item after the current line
---@param config Radar.Config
---@return nil
function M.paste_line(config)
  if not M.exists() or not cut_item then
    return
  end

  local cursor = vim.api.nvim_win_get_cursor(state.tabs_winid)
  local line_num = cursor[1]
  local item = state.tabs_line_mapping[line_num]

  if not item or not item.tabid then
    return
  end

  if cut_item.type == "buffer" then
    -- Create the new window FIRST at the paste position
    if item.winid then
      vim.api.nvim_set_current_win(item.winid)
      pcall(vim.cmd, "vsplit")
      pcall(vim.cmd, "edit " .. vim.fn.fnameescape(cut_item.filepath))
    else
      local tab_win = vim.api.nvim_tabpage_get_win(item.tabid)
      vim.api.nvim_set_current_win(tab_win)
      pcall(vim.cmd, "tabedit " .. vim.fn.fnameescape(cut_item.filepath))
    end

    -- Return focus to the tabs floating window
    if M.exists() then
      pcall(vim.api.nvim_set_current_win, state.tabs_winid)
    end

    -- THEN close the original window
    if cut_item.winid and vim.api.nvim_win_is_valid(cut_item.winid) then
      pcall(vim.api.nvim_win_close, cut_item.winid, false)
    end

  elseif cut_item.type == "tab" and cut_item.tabid then
    if not vim.api.nvim_tabpage_is_valid(cut_item.tabid) then
      return
    end

    -- Calculate target position (0-indexed) for tabmove
    local tabs = vim.api.nvim_list_tabpages()
    local target_pos = nil
    for i, tabid in ipairs(tabs) do
      if tabid == item.tabid then
        target_pos = i - 1 -- 0-indexed
        break
      end
    end

    if target_pos == nil then
      return
    end

    -- Navigate to the cut tab, move it after the target, then return
    local cut_tab_win = vim.api.nvim_tabpage_get_win(cut_item.tabid)
    vim.api.nvim_set_current_win(cut_tab_win)
    vim.cmd("tabmove " .. (target_pos + 1))

    -- Return focus to the tabs floating window
    if M.exists() then
      pcall(vim.api.nvim_set_current_win, state.tabs_winid)
    end
  end

  cut_item = nil
  cut_line_num = nil

  -- Refresh the tabs window to show the new layout
  M.update(config)

  -- Clamp cursor if past the new last line
  if
    M.exists()
    and state.tabs_bufid
    and vim.api.nvim_buf_is_valid(state.tabs_bufid)
  then
    local new_count = vim.api.nvim_buf_line_count(state.tabs_bufid)
    if line_num > new_count then
      vim.api.nvim_win_set_cursor(state.tabs_winid, { math.max(1, new_count), 0 })
    end
  end
end

---Paste the cut item before the current line
---@param config Radar.Config
---@return nil
function M.paste_line_before(config)
  if not M.exists() or not cut_item then
    return
  end

  local cursor = vim.api.nvim_win_get_cursor(state.tabs_winid)
  local line_num = cursor[1]
  local item = state.tabs_line_mapping[line_num]

  if not item or not item.tabid then
    return
  end

  if cut_item.type == "tab" and cut_item.tabid then
    if not vim.api.nvim_tabpage_is_valid(cut_item.tabid) then
      return
    end

    -- Calculate target position (0-indexed) for tabmove
    local tabs = vim.api.nvim_list_tabpages()
    local target_pos = nil
    for i, tabid in ipairs(tabs) do
      if tabid == item.tabid then
        target_pos = i - 1 -- 0-indexed
        break
      end
    end

    if target_pos == nil then
      return
    end

    -- Navigate to the cut tab, move it before the target, then return
    local cut_tab_win = vim.api.nvim_tabpage_get_win(cut_item.tabid)
    vim.api.nvim_set_current_win(cut_tab_win)
    vim.cmd("tabmove " .. target_pos)

    -- Return focus to the tabs floating window
    if M.exists() then
      pcall(vim.api.nvim_set_current_win, state.tabs_winid)
    end

    cut_item = nil
    cut_line_num = nil

    -- Refresh the tabs window to show the new layout
    M.update(config)

    -- Clamp cursor if past the new last line
    if
      M.exists()
      and state.tabs_bufid
      and vim.api.nvim_buf_is_valid(state.tabs_bufid)
    then
      local new_count = vim.api.nvim_buf_line_count(state.tabs_bufid)
      if line_num > new_count then
        vim.api.nvim_win_set_cursor(state.tabs_winid, { math.max(1, new_count), 0 })
      end
    end
  else
    -- Buffer line: fall back to paste after (for now)
    M.paste_line(config)
  end
end

---Jump to the tab/buffer on the current line
---@param config Radar.Config
---@return nil
function M.jump_to_line(config)
  if not M.exists() then
    return
  end

  local cursor = vim.api.nvim_win_get_cursor(state.tabs_winid)
  local line_num = cursor[1]
  local item = state.tabs_line_mapping[line_num]

  if not item or not item.tabid then
    return
  end

  -- Close window if auto_close is enabled
  if config.tabs.auto_close then
    M.close()
  end

  -- Jump to the target
  if item.winid then
    -- Buffer line: switch to specific window (this also switches tabs)
    vim.api.nvim_set_current_win(item.winid)
  else
    -- Tab header line: switch to tab's active window
    local tab_win = vim.api.nvim_tabpage_get_win(item.tabid)
    vim.api.nvim_set_current_win(tab_win)
  end
end

return M
