local dt = datetime.now(getcfg("zone") or "UTC")
local module_time = 30

function time_text(datetime: Datetime): string
  local time = datetime.time
  return if time.hour > 9 then `{time.hour}:{time.padded_minute}` else ` {time.hour}:{time.padded_minute}`
end

function date_text(datetime: Datetime): string
  local date = datetime.date
  return `{date.day_name:sub(0, 3)} {date.month_name:sub(0, 3)} {date.day}`
end

local second_advance_animation: CustomAnimation = {
  component_indexes = { 0 },
  animation = { loop = false, speed = 61, duration = 60 - dt.time.second },
  states = {
    { timestamp = 0, text = time_text(dt) },
    { timestamp = 60 - dt.time.second, text = time_text(dt:shift({ seconds = 60 })) },
  },
}

return niceclock
  .modulebuilder("24 Hour Clock", module_time, {}, { second_advance_animation })
  :text({ y = 0, x = 0 }, niceclock.fonts.Font12x24, time_text(dt), { r = 255, g = 0, b = 0 })
  :text({ y = 24, x = 8 }, niceclock.fonts.Font5x8, date_text(dt), { r = 255, g = 0, b = 0 })
