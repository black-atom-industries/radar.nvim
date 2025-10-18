---@alias Radar.Config.WinPreset "center" | "cursor" | "top_right" | "bottom_center" | "full_height_sidebar"

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

---@class Radar.Config.Behavior
---@field max_recent_files integer
---@field show_empty_message boolean

---@class Radar.Config.Appearance
---@field path_format string
---@field titles Radar.Config.Appearance.Titles

---@class Radar.Config.Appearance.Titles
---@field main string
---@field locks string
---@field alternative string
---@field recent string

---@class Radar.Config.Windows.FileWindow
---@field config Radar.Config.WinPreset | { [1]: Radar.Config.WinPreset, [2]: vim.api.keyset.win_config }

---@class Radar.Config.Windows.Float.RadarWindow
---@field winblend integer
---@field config Radar.Config.WinPreset | { [1]: Radar.Config.WinPreset, [2]: vim.api.keyset.win_config }

---@class Radar.Config.Windows.Float.EditWindow
---@field width_padding integer
---@field max_height integer
---@field min_width integer

---@class Radar.Config.Windows.Float
---@field radar Radar.Config.Windows.Float.RadarWindow
---@field edit Radar.Config.Windows.Float.EditWindow

---@class Radar.Config.Windows.Sidebar
---@field position "left"|"right"
---@field width integer

---@class Radar.Config.Windows
---@field file_window Radar.Config.Windows.FileWindow
---@field float Radar.Config.Windows.Float

---@class Radar.Config.Persist
---@field path string
---@field defer_ms integer

---@alias Radar.Config.Mode "float_top_right"|"sidebar_left"|"sidebar_right"

---@class Radar.Config
---@field mode Radar.Config.Mode
---@field keys Radar.Config.Keys
---@field behavior Radar.Config.Behavior
---@field appearance Radar.Config.Appearance
---@field windows Radar.Config.Windows
---@field persist Radar.Config.Persist

---@class Radar.Lock
---@field label string
---@field filename string

---@class Radar.ProjectData
---@field locks Radar.Lock[]

---@class Radar.BranchData
---@field [string] Radar.ProjectData

---@class Radar.PersistenceData
---@field [string] Radar.BranchData
