local date = datetime.fromiso("2026-02-06T06:00:00Z")
local delta = date:sub(datetime.utcnow())

local white: Color = { r = 255, g = 255, b = 255 }
local green: Color = { r = 0, g = 166, b = 81 }
local blue: Color = { r = 0, g = 128, b = 200 }
local yellow: Color = { r = 252, g = 177, b = 49 }

local module = niceclock
  .modulebuilder("countdown", 20, { "olympic-rings-small", "olympic-torch" }, {})
  :image({ x = 0, y = 0 }, "olympic-rings-small")

if delta.days <= 0 then
  module = module
    :text({ x = 29, y = 0 }, niceclock.fonts.Font6x12, "The", green)
    :text({ x = 30, y = 10 }, niceclock.fonts.Font6x13, "Torch", blue)
    :text({ x = 29, y = 21 }, niceclock.fonts.Font6x12, "Is Lit", yellow)
    :image({ x = 0, y = 11 }, "olympic-torch")
else
  if delta.days > 0 then
    module = module:text(
      { x = (34 - (#tostring(delta.days) * 6)), y = 0 },
      niceclock.fonts.Font6x13,
      `{delta.days} Days`,
      white
    )
  end
  module = module
    :text({ x = 30, y = 14 }, niceclock.fonts.Font5x8_2, "Until", white)
    :text({ x = 2, y = 22 }, niceclock.fonts.Font5x8_2, "The Olympics", white)
end

return module
