local API = {}

---Open the radar window
function API.open()
  local config -- get merged config somehow
  require("radar.ui.mini_radar").create(config)
end

return API
