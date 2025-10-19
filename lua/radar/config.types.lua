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

---@class Radar.Config.Persist
---@field path string
---@field defer_ms integer

---@class Radar.Config.Titles
---@field main string
---@field locks string
---@field alternative string
---@field recent string

---@class Radar.Config.Radar
---@field win_preset Radar.Config.WinPreset
---@field width integer
---@field winblend integer
---@field max_recent_files integer
---@field show_empty_message boolean
---@field path_format string
---@field titles Radar.Config.Titles

---@class Radar.Config.RadarEdit
---@field win_preset Radar.Config.WinPreset
---@field width_padding integer
---@field max_height integer
---@field min_width integer

---@class Radar.Config.FileFloat
---@field win_preset Radar.Config.WinPreset

---@class Radar.Config
---@field keys Radar.Config.Keys
---@field persist Radar.Config.Persist
---@field win_presets table<string, table|fun(base_preset: vim.api.keyset.win_config, config: Radar.Config): vim.api.keyset.win_config>
---@field radar Radar.Config.Radar
---@field radar_edit Radar.Config.RadarEdit
---@field file_float Radar.Config.FileFloat

---@class Radar.Lock
---@field label string
---@field filename string

---@class Radar.ProjectData
---@field locks Radar.Lock[]

---@class Radar.BranchData
---@field [string] Radar.ProjectData

---@class Radar.PersistenceData
---@field [string] Radar.BranchData
