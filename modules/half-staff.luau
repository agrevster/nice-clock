local state = getcfg("half_staff_state")

if state == nil then
  error("You must specify a state in the config via the 'half_staff_state' key!")
end

local url = `https://halfstaff.org/wp-json/halfstaff/v1/widget?state={state}`

local data = json.load(http.fetch(url, http.methods.GET, nil, nil, nil).body)
local flag_height = if data.type == "none" then 0 else 8

local reason = data.title

local module = niceclock
  .modulebuilder("half staff", 20, { "flags/us_small" }, {})
  :box({ x = 3, y = 0 }, 2, 32, true, { r = 128, g = 128, b = 128 })
  :image({ x = 5, y = flag_height }, "flags/us_small")

if reason ~= nil then
  module = module:horizontalscrollingtext(
    { x = 64, y = 0 },
    niceclock.fonts.Font5x8,
    reason,
    { r = 255, g = 255, b = 255 },
    3,
    -20,
    { loop = true, speed = 2, duration = 20 }
  )
end

return module
