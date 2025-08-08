local time = datetime.now("America/Chicago").time

local time_text = if time.twelve_hour > 9
	then `{time.twelve_hour}:{time.minute}`
	else ` {time.twelve_hour}:{time.minute}`

local blink_animation: CustomAnimation = {
	component_indexes = { 0 },
	animation = { loop = true, speed = 20, duration = 3 },
	states = { { timestamp = 0, text = time_text }, { timestamp = 1, text = time_text:gsub(":", " ") } },
}

return niceclock
	.modulebuilder("Basic Clock", 30, {}, { blink_animation })
	:text({ y = 0, x = 0 }, niceclock.fonts.Font12x24, time_text, { r = 255, g = 0, b = 0 })
