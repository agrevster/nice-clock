local time = datetime.now("America/Chicago").time
local time_text = if time.twelve_hour > 9 then `{time.twelve_hour}:{time.minute}` else ` {time.twelve_hour}:{time.minute}` 

return niceclock.modulebuilder("Basic Clock", 30, {})
	:text({y=0,x=0}, niceclock.fonts.Font12x24, time_text, {r=255,g=0,b=0})
