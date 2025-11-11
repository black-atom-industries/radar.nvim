---@alias Radar.Config.WinPreset "center" | "center_large" | "cursor" | "top_right" | "bottom_center" | "full_height_sidebar"

---@class Radar.Config.Keys.Line
---@field open string
---@field vertical string
---@field horizontal string
---@field tab string
---@field float string

---@class Radar.Config.Keys
---@field prefix string
---@field lock string
---@field locks string[]
---@field alternative string
---@field recent string[]
---@field vertical string
---@field horizontal string
---@field tab string
---@field float string
---@field line Radar.Config.Keys.Line

---@class Radar.Config.Persist
---@field path string
---@field defer_ms integer

---@class Radar.Config.GridSize
---@field width integer Grid total width
---@field height integer Grid total height

---@alias Radar.Config.Position "center" | "top_left" | "top_right" | "bottom_left" | "bottom_right"

---@class Radar.Config.Titles
---@field main string
---@field locks string
---@field alternative string
---@field recent string
---@field hints string

---@class Radar.Config.Radar
---@field grid_size Radar.Config.GridSize
---@field border? string Border style (see |nvim_open_win()| 'border' option)
---@field position Radar.Config.Position
---@field winblend integer
---@field max_recent_files integer
---@field show_empty_message boolean
---@field titles Radar.Config.Titles
---@field win_opts table<string, any> Window-local options (see |options-list|)

---@class Radar.Config.RadarEdit
---@field win_preset Radar.Config.WinPreset|string
---@field win_opts table<string, any> Window-local options (see |options-list|)

---@class Radar.Config.FileFloat
---@field win_preset Radar.Config.WinPreset|string
---@field win_opts table<string, any> Window-local options (see |options-list|)

---@class Radar.Config
---@field keys Radar.Config.Keys
---@field persist Radar.Config.Persist
---@field win_presets table<Radar.Config.WinPreset|string, table|fun(config: Radar.Config): vim.api.keyset.win_config>
---@field radar Radar.Config.Radar
---@field radar_edit Radar.Config.RadarEdit
---@field file_float Radar.Config.FileFloat

---@class Radar.Lock
---@field label string
---@field filename string

---@class Radar.BranchData
---@field locks Radar.Lock[]
---@field lastAccessed number

---@class Radar.ProjectBranches
---@field [string] Radar.BranchData

---@class Radar.Projects
---@field [string] Radar.ProjectBranches

---@class Radar.PersistenceData
---@field version number
---@field projects Radar.Projects
