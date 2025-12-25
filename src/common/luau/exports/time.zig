const std = @import("std");
const zlua = @import("zlua");
const datetime = @import("datetime").datetime;
const module_loader = @import("../module-loader.zig");
const logger = module_loader.logger;
const LuauTry = module_loader.LuauTry;
const luauError = module_loader.luauError;
const Datetime = datetime.Datetime;
const Time = datetime.Time;
const Date = datetime.Date;
const Luau = zlua.Lua;
const wrap = zlua.wrap;

///Sends the exported functions to luau.
pub fn load_export(luau: *Luau) void {
    luau.newTable();

    luau.pushFunction(wrap(utcNow));
    luau.setField(-2, "utcnow");

    luau.pushFunction(wrap(zonedNow));
    luau.setField(-2, "now");

    luau.pushFunction(wrap(new));
    luau.setField(-2, "new");

    luau.pushFunction(wrap(fromISO));
    luau.setField(-2, "fromiso");

    luau.setGlobal("datetime");
}

const tryBufPrint = LuauTry([]u8, "Failed write padded_mintue to buffer!");

///Converts the given time field into a Luau table.
fn createTimeTableFromZig(current: Time, luau: *Luau) void {
    luau.newTable();

    luau.pushInteger(current.hour);
    luau.setField(-2, "hour");

    luau.pushInteger(current.minute);
    luau.setField(-2, "minute");

    luau.pushInteger(current.second);
    luau.setField(-2, "second");

    _ = luau.pushString(current.amOrPm());
    luau.setField(-2, "am_pm");

    if (current.hour > 12) {
        luau.pushInteger(current.hour - 12);
    } else {
        if (current.hour == 0) luau.pushInteger(12) else luau.pushInteger(current.hour);
    }
    luau.setField(-2, "twelve_hour");

    const padded_minute_buffer = luau.allocator().alloc(u8, 2) catch luauError(luau, "Failed to allocate space for padded mintue buffer!");

    _ = tryBufPrint.unwrap(luau, std.fmt.bufPrint(padded_minute_buffer, "{d:0>2}", .{current.minute}));
    _ = luau.pushString(padded_minute_buffer);
    luau.setField(-2, "padded_minute");

    luau.setField(-2, "time");
}

///Converts the given date field into a luau table.
fn createDateTableFromZig(current: Date, luau: *Luau) void {
    luau.newTable();

    luau.pushInteger(current.year);
    luau.setField(-2, "year");

    luau.pushInteger(current.month);
    luau.setField(-2, "month");

    luau.pushInteger(current.day);
    luau.setField(-2, "day");

    _ = luau.pushString(current.weekdayName());
    luau.setField(-2, "day_name");

    _ = luau.pushString(current.monthName());
    luau.setField(-2, "month_name");

    luau.pushInteger(current.weekday());
    luau.setField(-2, "day_of_week");

    luau.pushInteger(current.dayOfYear());
    luau.setField(-2, "day_of_year");

    luau.pushInteger(current.weekOfYear());
    luau.setField(-2, "week_of_year");

    luau.setField(-2, "date");
}

///Converts the given datetime fied into a luau table.
fn createDatetimeTableFromZig(current: Datetime, luau: *Luau) void {
    luau.newTable();
    createDateTableFromZig(current.date, luau);
    createTimeTableFromZig(current.time, luau);
    const iso = current.formatISO8601(luau.allocator(), false) catch "Error";
    defer luau.allocator().free(iso);
    _ = luau.pushString(iso);
    luau.setField(-2, "iso");
    luau.pushNumber(current.toSeconds());
    luau.setField(-2, "epoch");
    luau.pushInteger(current.zone.offset);
    luau.setField(-2, "offset_minutes");
    luau.pushFunction(wrap(shift));
    luau.setField(-2, "shift");
    luau.pushFunction(wrap(sub));
    luau.setField(-2, "sub");
    luau.pushFunction(wrap(shiftZone));
    luau.setField(-2, "shiftzone");
}

///Converts luau table into a Zig datetime struct.
fn createDatetimeFromLuauTable(luau: *Luau, index: i32) Datetime {
    _ = luau.getField(index, "epoch");
    _ = luau.getField(index, "offset_minutes");
    const epoch: f64 = LuauTry(f64, "Failed to get epoch integer.").unwrap(luau, luau.toNumber(-2));
    const offset_minutes: i16 = @truncate(LuauTry(c_int, "Failed to get epoch integer.").unwrap(luau, luau.toInteger(-1)));
    var dt = Datetime.fromSeconds(epoch);
    dt.zone = datetime.Timezone.create("Custom ISO", offset_minutes, .no_dst);
    luau.pop(2);

    return dt;
}

///Attempts to get int from luau, if we run into issues return a default int.
fn getIntFieldOrDefault(luau: *Luau, field_name: [:0]const u8, index: i32, default: zlua.Integer) zlua.Integer {
    _ = luau.getField(index, field_name);
    if (luau.isNoneOrNil(-1)) return default;
    const number: zlua.Integer = LuauTry(zlua.Integer, "Failed to parse number.").unwrap(luau, luau.toInteger(-1));
    luau.pop(1);
    return number;
}

///Creates a zig DatetimeDelta struct from the delta table in luau.
fn createDeltaFromLuauTable(luau: *Luau, index: i32) Datetime.Delta {
    const years: i16 = @intCast(getIntFieldOrDefault(luau, "years", index, 0));
    const days: i32 = @intCast(getIntFieldOrDefault(luau, "days", index, 0));
    const seconds: i64 = @intCast(getIntFieldOrDefault(luau, "seconds", index, 0));

    return Datetime.Delta{ .days = days, .years = years, .seconds = seconds };
}

///Creates a datetime delta table in luau from the given datetime delta struct.
fn createDeltaTableFromZig(luau: *Luau, delta: Datetime.Delta) void {
    luau.newTable();

    luau.pushInteger(delta.days);
    luau.setField(-2, "days");
    luau.pushInteger(delta.years);
    luau.setField(-2, "years");
    luau.pushInteger(@as(zlua.Integer, @intCast(delta.seconds)));
    luau.setField(-2, "seconds");
}

//
// Luau Functions
//

///(Luau)
///Returns the current time in UTC.
fn utcNow(luau: *Luau) i32 {
    createDatetimeTableFromZig(Datetime.now(), luau);
    return 1;
}

///(Luau)
///Returns the current time in the given timezone.
fn zonedNow(luau: *Luau) i32 {
    luau.checkType(1, zlua.LuaType.string);
    if (luau.toString(1)) |time_zone_str| {
        if (datetime.timezones.getByName(time_zone_str)) |time_zone| {
            createDatetimeTableFromZig(Datetime.now().shiftTimezone(time_zone), luau);
        } else |_| {
            _ = luau.pushString("Invalid time zone!");
            luau.raiseError();
        }
    } else |e| {
        logger.err("Now: {t}", .{e});
    }
    return 1;
}

///(Luau)
///Creates a new datetime table from args.
fn new(luau: *Luau) i32 {
    luau.checkType(1, zlua.LuaType.number);
    luau.checkType(2, zlua.LuaType.number);
    luau.checkType(3, zlua.LuaType.number);
    luau.checkType(4, zlua.LuaType.number);
    luau.checkType(5, zlua.LuaType.number);
    luau.checkType(6, zlua.LuaType.number);
    luau.checkType(7, zlua.LuaType.string);
    const time_zone_str = LuauTry([:0]const u8, "Error loading timezone string.").unwrap(luau, luau.toString(7));
    const tryToInt = LuauTry(c_int, "Error loading int from luau.");

    if (datetime.timezones.getByName(time_zone_str)) |time_zone| {
        const year: u32 = @intCast(tryToInt.unwrap(luau, luau.toInteger(1)));
        const month: u32 = @intCast(tryToInt.unwrap(luau, luau.toInteger(2)));
        const day: u32 = @intCast(tryToInt.unwrap(luau, luau.toInteger(3)));
        const hour: u32 = @intCast(tryToInt.unwrap(luau, luau.toInteger(4)));
        const minute: u32 = @intCast(tryToInt.unwrap(luau, luau.toInteger(5)));
        const second: u32 = @intCast(tryToInt.unwrap(luau, luau.toInteger(6)));
        if (Datetime.create(year, month, day, hour, minute, second, 0, time_zone)) |new_datetime| {
            createDatetimeTableFromZig(new_datetime, luau);
        } else |e| {
            _ = luau.pushString("Error creating new datetime!");
            luau.raiseError();
            logger.err("New: {t}", .{e});
        }
    } else |_| {
        _ = luau.pushString("Invalid time zone!");
        luau.raiseError();
    }
    return 1;
}

///(Luau)
///Creates a datetime object from ISO format.
fn fromISO(luau: *Luau) u32 {
    luau.checkType(1, zlua.LuaType.string);
    const timestamp = LuauTry([:0]const u8, "Error getting ISO timestamp").unwrap(luau, luau.toString(1));

    const parseInt = std.fmt.parseInt;
    const tryParseIntu8 = LuauTry(u8, "Error getting int from timestamp.").unwrap;
    const tryParseInti9 = LuauTry(i9, "Error getting int from timestamp.").unwrap;

    const year: u16 = LuauTry(u16, "Error getting int from timestamp.").unwrap(luau, parseInt(u16, timestamp[0..4], 10));
    const month: u4 = LuauTry(u4, "Error getting int from timestamp.").unwrap(luau, parseInt(u4, timestamp[5..7], 10));
    const day: u8 = tryParseIntu8(luau, parseInt(u8, timestamp[8..10], 10));
    const hour: u8 = tryParseIntu8(luau, parseInt(u8, timestamp[11..13], 10));
    const minute: u8 = tryParseIntu8(luau, parseInt(u8, timestamp[14..16], 10));
    const second: u8 = tryParseIntu8(luau, parseInt(u8, timestamp[17..19], 10));

    var zone: datetime.Timezone = datetime.timezones.UTC;
    _ = &zone;

    switch (timestamp[19]) {
        'Z' => {},
        '+' => {
            const hours = tryParseInti9(luau, parseInt(i9, timestamp[20..22], 10));
            const minutes = tryParseInti9(luau, parseInt(i9, timestamp[23..25], 10));
            zone = datetime.Timezone.create("Custom ISO", (hours * 60) + minutes, .no_dst);
        },
        '-' => {
            const hours = tryParseInti9(luau, parseInt(i9, timestamp[20..22], 10));
            const minutes = tryParseInti9(luau, parseInt(i9, timestamp[23..25], 10));
            zone = datetime.Timezone.create("Custom ISO", -((hours * 60) + minutes), .no_dst);
        },
        else => {
            _ = luau.pushString("Invalid iso offset!");
            luau.raiseError();
        },
    }

    const dt = Datetime{
        .date = Date{
            .year = year,
            .month = month,
            .day = day,
        },
        .time = Time{
            .hour = hour,
            .minute = minute,
            .second = second,
        },
        .zone = zone,
    };

    createDatetimeTableFromZig(dt, luau);

    return 1;
}

///(Luau)
///Shifts the given datetime by the given delta.
fn shift(luau: *Luau) i32 {
    luau.checkType(1, zlua.LuaType.table);
    luau.checkType(2, zlua.LuaType.table);
    const dt = createDatetimeFromLuauTable(luau, 1);
    var delta = createDeltaFromLuauTable(luau, 2);
    delta.relative_to = dt;

    createDatetimeTableFromZig(dt.shift(delta), luau);
    return 1;
}

///(Luau)
///Subtracts one datetime from another datetime.
fn sub(luau: *Luau) i32 {
    luau.checkType(1, zlua.LuaType.table);
    luau.checkType(2, zlua.LuaType.table);
    const dt1 = createDatetimeFromLuauTable(luau, 1);
    const dt2 = createDatetimeFromLuauTable(luau, 2);

    const delta = dt1.sub(dt2);
    createDeltaTableFromZig(luau, delta);

    return 1;
}

fn shiftZone(luau: *Luau) i32 {
    luau.checkType(1, zlua.LuaType.table);
    luau.checkType(2, zlua.LuaType.string);

    const dt = createDatetimeFromLuauTable(luau, 1);

    if (luau.toString(2)) |time_zone_str| {
        if (datetime.timezones.getByName(time_zone_str)) |time_zone| {
            createDatetimeTableFromZig(dt.shiftTimezone(time_zone), luau);
        } else |_| {
            _ = luau.pushString("Invalid time zone!");
            luau.raiseError();
        }
    } else |_| {}
    return 1;
}
