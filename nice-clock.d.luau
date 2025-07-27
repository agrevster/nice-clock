-- GLOBAL
export type GlobalDatetime = {
--- For a list of timezones see  https://github.com/frmdstryr/zig-datetime/blob/master/src/timezones.zig
	now: (timezone: string) -> Datetime, 
	utcnow: () -> Datetime,
	new: (year: number, month: number, day: number, hour: number, minute: number, second: number, timezone: string) -> Datetime,
	fromiso: (iso8601_timestamp: string) -> Datetime, 
}

export type GlobalNiceClock = {
	modulebuilder: (name: string, timelimit: number, imagenames: {string}) -> ClockModuleBuilder,
	fonts: Fonts,
}

-- niceclock

export type ClockModuleBuilder = {
	name: string,
	timelimit: number,
	components: {ClockComponent},
	imagenames: {string},
	init_fn: nil | () -> (),
	deinit_fn: nil | () -> (),
	init: (self: ClockModuleBuilder, fn: () -> ()) -> ClockModuleBuilder,
	deinit: (self: ClockModuleBuilder, fn: () -> ()) -> ClockModuleBuilder,
	build: (self: ClockModuleBuilder) ->  ClockModule,
	-- Components
	tile: (self: ClockModuleBuilder, pos: Pos, color: Color) -> ClockModuleBuilder,
	box: (self: ClockModuleBuilder, pos: Pos, width: number, height: number, fill_inside: boolean, color: Color) -> ClockModuleBuilder,
	circle: (self: ClockModuleBuilder, pos: Pos, radius: number, outline_thickness: number, color: Color) -> ClockModuleBuilder,
	image: (self: ClockModuleBuilder, pos: Pos, image_name: string) -> ClockModuleBuilder,
	char: (self: ClockModuleBuilder, pos: Pos, font: string, char: string, color: Color) -> ClockModuleBuilder,
	text: (self: ClockModuleBuilder, pos: Pos, font: string, text: string, color: Color)-> ClockModuleBuilder,
	wrappedtext: (self: ClockModuleBuilder, pos: Pos, font: string, text: string, color: Color, line_spacing: number) -> ClockModuleBuilder,
	horizontalscrollingtext: (self: ClockModuleBuilder, pos: Pos, font: string, text: string, color: Color, cutof_x: number, text_pos: number, animation: Animation) -> ClockModuleBuilder,
	verticalscrollingtext: (self: ClockModuleBuilder, pos: Pos, width: number, height: number, font: string, text: string, color: Color, text_pos: number,line_spacing: number, animation: Animation) -> ClockModuleBuilder,
}

export type ClockModule = {
	name: string,
	timelimit: number,
	components: {ClockComponent},
	imagenames: {string},
	init: nil | () -> (),
	deinit: nil | () -> (),
}

export type ClockComponent = {
	type: number,
	props: {}
}

export type Color = {
	b: number,
	g: number,
	r: number,
}

export type Pos = {
	y: number,
	x: number,
}

export type Animation = {
	duration: number,
	loop: boolean,
	speed: number,
}


export type Fonts = {
	Font5x8: string,
	Font5x8_2: string,
	Font6x12: string,
	Font6x13: string,
	Font7x13: string,
	Font7x14: string,
	Font12x24: string,
}

-- datetime
export type Datetime = {
	date: Date,
	time: Time,
	iso: string,
	epoch: number,
	shift: (self: Datetime, delta: DatetimeDelta) -> Datetime,
	sub: (self: Datetime, datetime: Datetime) -> DatetimeDelta,
}

export type Date = {
	year: number,
	month: number,
	day: number,
	day_name: string,
	month_name: string,
	day_of_week: number,
	day_of_year: number,
	week_of_year: number,
}

export type Time = {
	hour: number,
	minute: number,
	second: number,
	am_pm: string,
	twelve_hour: number,
}

export type DatetimeDelta = {
	years: number?,
	days: number?,
	seconds: number?,
}

-- Declarations
declare datetime: GlobalDatetime
declare niceclock: GlobalNiceClock
