local dt = datetime.now("America/Chicago")

local time = dt.time
local date = dt.date

local time_text = if time.twelve_hour > 9
  then `{time.twelve_hour}:{time.padded_minute}`
  else ` {time.twelve_hour}:{time.padded_minute}`

local date_text = `{date.day_name:sub(0, 3)} {date.month_name:sub(0, 3)} {date.day}`

local blink_animation: CustomAnimation = {
  component_indexes = { 0 },
  animation = { loop = true, speed = 20, duration = 3 },
  states = { { timestamp = 0, text = time_text }, { timestamp = 1, text = time_text:gsub(":", " ") } },
}

return niceclock
  .modulebuilder("Basic Clock", 30, {}, { blink_animation })
  :text({ y = 0, x = 0 }, niceclock.fonts.Font12x24, time_text, { r = 255, g = 0, b = 0 })
  :text({ y = 24, x = 8 }, niceclock.fonts.Font5x8, date_text, { r = 255, g = 0, b = 0 })
