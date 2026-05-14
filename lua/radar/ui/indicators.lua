local M = {}

---Helper to get a color attribute from a highlight group
---@param group string
---@param attr string
---@return string?
local function get_attr(group, attr)
  local hl = vim.api.nvim_get_hl(0, { name = group, link = false })
  local val = hl[attr]
  return val and string.format("#%06x", val) or nil
end

---Create highlight groups for git and LSP indicators from theme colors.
---Pill/badge style: labels use Comment fg on DiffChange/VirtualTextHint bg,
---values use semantic sign colors (mini.diff / diagnostic) with matching bg.
function M.setup_highlights()
  local git_bg = get_attr("DiffChange", "bg")
  local lsp_bg = get_attr("DiagnosticVirtualTextHint", "bg")
  local muted = get_attr("Comment", "fg")

  -- Git indicator groups
  vim.api.nvim_set_hl(0, "RadarTabsGitSection", { bg = git_bg })
  vim.api.nvim_set_hl(0, "RadarTabsGitLabel", { fg = muted, bg = git_bg })
  vim.api.nvim_set_hl(
    0,
    "RadarTabsGitAdd",
    { fg = get_attr("MiniDiffSignAdd", "fg"), bg = git_bg }
  )
  vim.api.nvim_set_hl(
    0,
    "RadarTabsGitChange",
    { fg = get_attr("MiniDiffSignChange", "fg"), bg = git_bg }
  )
  vim.api.nvim_set_hl(
    0,
    "RadarTabsGitDelete",
    { fg = get_attr("MiniDiffSignDelete", "fg"), bg = git_bg }
  )

  -- LSP indicator groups
  vim.api.nvim_set_hl(0, "RadarTabsLspSection", { bg = lsp_bg })
  vim.api.nvim_set_hl(0, "RadarTabsLspLabel", { fg = muted, bg = lsp_bg })
  vim.api.nvim_set_hl(
    0,
    "RadarTabsLspError",
    { fg = get_attr("DiagnosticSignError", "fg"), bg = lsp_bg }
  )
  vim.api.nvim_set_hl(
    0,
    "RadarTabsLspWarn",
    { fg = get_attr("DiagnosticSignWarn", "fg"), bg = lsp_bg }
  )
  vim.api.nvim_set_hl(
    0,
    "RadarTabsLspInfo",
    { fg = get_attr("DiagnosticSignInfo", "fg"), bg = lsp_bg }
  )
  vim.api.nvim_set_hl(
    0,
    "RadarTabsLspHint",
    { fg = get_attr("DiagnosticSignHint", "fg"), bg = lsp_bg }
  )
end

-- Create highlight groups on module load so they're always available
M.setup_highlights()

-- Rebuild on theme change
local ind_augroup = vim.api.nvim_create_augroup("RadarIndicators", { clear = true })
vim.api.nvim_create_autocmd("ColorScheme", {
  group = ind_augroup,
  callback = M.setup_highlights,
  desc = "Rebuild git/LSP indicator highlights on theme change",
})

---Build git and LSP indicator string for a buffer
---@param bufnr integer
---@return string
function M.get_buffer_indicators(bufnr)
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

---Align string to the left with a right-aligned suffix
---@param left string
---@param suffix string
---@param total_width integer Total columns available
---@param indent integer Leading indentation in spaces (unused currently, kept for API compatibility)
---@return string
function M.right_align_line(left, suffix, total_width, indent)
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

---Apply pill/badge extmark highlighting for git and LSP indicator sections
---@param bufnr integer
---@param ns integer Extmark namespace
---@param lines string[] Buffer lines
function M.highlight_indicators(bufnr, ns, lines)
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

return M
