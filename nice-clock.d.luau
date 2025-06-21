-- GLOBAL
export type GlobalDatetime = {
--- For a list of timezones see  https://github.com/frmdstryr/zig-datetime/blob/master/src/timezones.zig
	now: (timezone: string) -> Datetime, 
	utcnow: () -> Datetime,
	new: (year: number, month: number, day: number, hour: number, minute: number, second: number, timezone: string) -> Datetime,
	fromiso: (iso8601_timestamp: string) -> Datetime, 
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
