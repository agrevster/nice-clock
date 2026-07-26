local state = getcfg("half_staff_state")

if state == nil then
  error("You must specify a state in the config via the 'half_staff_state' key!")
end

local url = `https://halfstaff.org/wp-json/halfstaff/v1/widget?state={state}`

local content = http.fetch(url, http.methods.GET, nil, nil, nil, nil).body
local data = json.load(content)
local flag_height = if data.type == "none" then 0 else 8
local time = if data.type == "none" then 10 else 20

local module = niceclock
  .modulebuilder("half staff", time, { "flags/us_small" }, {})
  :box({ x = 3, y = 0 }, 2, 32, true, { r = 128, g = 128, b = 128 })
  :image({ x = 5, y = flag_height }, "flags/us_small")

if data.title ~= nil then
  module = module:horizontalscrollingtext(
    { x = 64, y = 0 },
    niceclock.fonts.Font5x8_2,
    sanitizetoascii(data.title),
    { r = 255, g = 255, b = 255 },
    5,
    -20,
    { loop = true, speed = 2, duration = 20 }
  )
end

return module
