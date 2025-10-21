local M = {}

-- Check if nerd fonts are available
local function has_nerd_fonts()
  -- Check for common terminals that support nerd fonts
  local term = vim.env.TERM_PROGRAM or ""
  local terminals = { "WezTerm", "iTerm", "Alacritty", "kitty" }
  for _, t in ipairs(terminals) do
    if term:find(t) then
      return true
    end
  end
  return vim.fn.has("gui_running") == 1
end

local use_icons = has_nerd_fonts()

-- Status code mapping to icons, letters, and highlight groups
local STATUS_MAP = {
  M = { icon = "", letter = "M", hl = "RadarGitModified", desc = "Modified" },
  A = { icon = "", letter = "A", hl = "RadarGitAdded", desc = "Added" },
  D = { icon = "", letter = "D", hl = "RadarGitDeleted", desc = "Deleted" },
  R = { icon = "", letter = "R", hl = "RadarGitRenamed", desc = "Renamed" },
  C = { icon = "", letter = "C", hl = "RadarGitRenamed", desc = "Copied" },
  U = { icon = "", letter = "U", hl = "RadarGitModified", desc = "Updated" },
  ["?"] = {
    icon = "󰽤",
    letter = "?",
    hl = "RadarGitUntracked",
    desc = "Untracked",
  },
  [" "] = { icon = "", letter = "", hl = "NormalFloat", desc = "Unchanged" },
}

---Get display text and highlight group for a status code
---@param status_code string Single character status code
---@return string text Display text (icon or letter)
---@return string hl Highlight group
local function get_status_char(status_code)
  local status = STATUS_MAP[status_code] or STATUS_MAP[" "]
  local text = use_icons and status.icon or status.letter
  return text, status.hl
end

---Get status display for staged and unstaged changes
---@param staged string Staged status code
---@param unstaged string Unstaged status code
---@return string text Combined status text
---@return table hl_info Array of {text, hl_group} for each character
function M.get_status_display(staged, unstaged)
  local parts = {}

  -- Staged status (index)
  if staged ~= " " then
    local text, hl = get_status_char(staged)
    table.insert(parts, { text = text, hl = hl })
  end

  -- Unstaged status (working tree)
  if unstaged ~= " " then
    local text, hl = get_status_char(unstaged)
    table.insert(parts, { text = text, hl = hl })
  end

  -- If no status, show space
  if #parts == 0 then
    table.insert(parts, { text = " ", hl = "Normal" })
  end

  -- Build combined text
  local combined_text = ""
  for _, part in ipairs(parts) do
    combined_text = combined_text .. part.text
  end

  -- Add padding space after status
  combined_text = combined_text .. " "

  return combined_text, parts
end

---Setup highlight groups for git status indicators
function M.setup_highlights()
  -- Use colors that work well with both light and dark themes
  vim.api.nvim_set_hl(0, "RadarGitModified", { fg = "#e5c07b", default = true })
  vim.api.nvim_set_hl(0, "RadarGitAdded", { fg = "#98c379", default = true })
  vim.api.nvim_set_hl(0, "RadarGitDeleted", { fg = "#e06c75", default = true })
  vim.api.nvim_set_hl(0, "RadarGitRenamed", { fg = "#61afef", default = true })
  vim.api.nvim_set_hl(0, "RadarGitUntracked", { fg = "#5c6370", default = true })
end

return M
