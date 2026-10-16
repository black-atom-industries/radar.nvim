---@alias Radar.Config.WinPreset "center" | "center_large" | "cursor" | "top_right" | "bottom_center" | "full_height_sidebar"

---@class Radar.Config.Keys
---@field prefix string
---@field lock string
---@field locks string[]
---@field alternative string
---@field recent string[]
---@field tabs_toggle string
---@field hud_toggle string
---@field tabs string
---@field edit string
---@field help string

---@class Radar.Config.Persist
---@field path string
---@field defer_ms integer

---@class Radar.Config.Recent
---@field max_files integer Recent files kept per project and branch

---@class Radar.Config.Hud
---@field enabled boolean Show the HUD on startup
---@field max_locks integer Locks shown in the HUD
---@field max_recent integer Recent files shown in the HUD

---@class Radar.Config.RadarEdit
---@field win_opts table<string, any> Window-local options (see |options-list|)

---@class Radar.Config.FileFloat
---@field win_preset Radar.Config.WinPreset|string
---@field win_opts table<string, any> Window-local options (see |options-list|)

---@class Radar.Config.Tabs
---@field auto_close boolean Close window after selecting a tab/buffer
---@field win_opts table<string, any> Window-local options (see |options-list|)

---@class Radar.Config
---@field debug boolean Enable verbose debug logging
---@field keys Radar.Config.Keys
---@field persist Radar.Config.Persist
---@field win_presets table<Radar.Config.WinPreset|string, table|fun(config: Radar.Config): vim.api.keyset.win_config>
---@field recent Radar.Config.Recent
---@field hud Radar.Config.Hud
---@field radar_edit Radar.Config.RadarEdit
---@field file_float Radar.Config.FileFloat
---@field tabs Radar.Config.Tabs

---@class Radar.Lock
---@field label string
---@field filename string

---@class Radar.BranchData
---@field locks Radar.Lock[]
---@field recent? string[] lock paths, most recent first
---@field lastAccessed number

---@class Radar.ProjectBranches
---@field [string] Radar.BranchData

---@class Radar.Projects
---@field [string] Radar.ProjectBranches

---@class Radar.PersistenceData
---@field version number
---@field projects Radar.Projects
