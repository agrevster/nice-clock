local test_animation: CustomAnimation = {
	component_indexes={0},
	animation={duration=30,loop=true,speed=3},
	states={
		{timestamp=00,color={r=255,g=0,b=0}},
		{timestamp=10,color={r=0,g=0,b=255}},
		{timestamp=20,color={r=0,g=255,b=0}},
	}
}
local test = niceclock.modulebuilder("Test module", 30, {}, {test_animation})
	:tile({x=0,y=0}, {r=255,g=0,b=0})

return test
