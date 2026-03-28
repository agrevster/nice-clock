local zone = getcfg("zone") or "UTC"
local zoned_now = datetime.now(zone)

function calc_date(target: Datetime): DatetimeDelta
  return target:sub(zoned_now)
end

local birthday = {
  month = tonumber(getcfg("birthday_month"), 10),
  day = tonumber(getcfg("birthday_day"), 10),
  name = getcfg("birthday_name"),
}

local this_year_delta = calc_date(datetime.new(zoned_now.date.year, birthday.month, birthday.day + 1, 0, 0, 0, zone))
local next_year_delta =
  calc_date(datetime.new(zoned_now.date.year + 1, birthday.month, birthday.day + 1, 0, 0, 0, zone))

local delta = if this_year_delta.days < -1 then next_year_delta else this_year_delta

local white: Color = { r = 255, g = 255, b = 255 }
local red: Color = { r = 230, g = 69, b = 83 }
local green: Color = { r = 0, g = 166, b = 81 }
local blue: Color = { r = 0, g = 128, b = 200 }
local yellow: Color = { r = 252, g = 177, b = 49 }

local module = niceclock
  .modulebuilder("birthday-countdown", 20, { "birthday-cake" }, {})
  :image({ x = 0, y = 3 }, "birthday-cake")

if delta.days <= 0 then
  module = module
    :text({ x = 24, y = 0 }, niceclock.fonts.Font6x12, "Happy", green)
    :text({ x = 17, y = 10 }, niceclock.fonts.Font6x13, "Birthday", blue)
    :text({ x = (47 - (#birthday.name * 6)), y = 21 }, niceclock.fonts.Font6x12, `{birthday.name}!`, yellow)
else
  if delta.days > 0 then
    module = module:text(
      { x = (34 - (#tostring(delta.days) * 6)), y = 0 },
      niceclock.fonts.Font6x13,
      `{delta.days} {if delta.days == 1 then "Day" else "Days"}`,
      white
    )
  end
  module = module
    :text({ x = 25, y = 14 }, niceclock.fonts.Font5x8_2, "Until", blue)
    :text({ x = (20 - (#birthday.name * 5)), y = 22 }, niceclock.fonts.Font5x8_2, `{birthday.name}'s Bday`, red)
end

return module
