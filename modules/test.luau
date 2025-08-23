local test = niceclock
	.modulebuilder("Test module", 30, {}, {})
	:text({ x = 0, y = 0 }, niceclock.fonts.Font5x8, "Test", { r = 255, g = 0, b = 0 })

return test
