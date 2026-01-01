local date = datetime.fromiso("2026-01-01T06:00:00Z")
local delta = date:sub(datetime.utcnow())

local white: Color = { r = 255, g = 255, b = 255 }
local red: Color = { r = 238, g = 71, b = 111 }
local blue: Color = { r = 17, g = 138, b = 178 }
local yellow: Color = { r = 255, g = 183, b = 3 }

local module = niceclock.modulebuilder("countdown", 20, { "fireworks" }, {}):image({ x = 0, y = 0 }, "fireworks")

if delta.seconds <= 0 then
  module = module:text({ x = 29, y = 0 }, niceclock.fonts.Font7x13, "Happy", red)
  module = module:text({ x = 30, y = 10 }, niceclock.fonts.Font7x13, "New", blue)
  module = module:text({ x = 29, y = 21 }, niceclock.fonts.Font7x13, "Year", yellow)
else
  if delta.days > 0 then
    module = module:text(
      { x = (34 - (#tostring(delta.days) * 6)), y = 0 },
      niceclock.fonts.Font6x13,
      `{delta.days} Days`,
      white
    )
  else
    local hours = (delta.seconds // 60 // 60)
    module =
      module:text({ x = (33 - (#tostring(hours) * 5)), y = 4 }, niceclock.fonts.Font5x8_2, `{hours} Hours`, white)
  end
  module = module
    :text({ x = 30, y = 14 }, niceclock.fonts.Font5x8_2, "Until", white)
    :text({ x = 14, y = 22 }, niceclock.fonts.Font5x8_2, "New Year's", white)
end

return module
