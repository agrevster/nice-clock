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
	r: number,
	g: number,
	b: number,
}

export type Pos = {
	x: number,
	y: number,
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
