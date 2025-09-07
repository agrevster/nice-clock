const std = @import("std");
const zlua = @import("zlua");
const common = @import("../../common.zig");
const http = std.http;
const Luau = zlua.Lua;
const wrap = zlua.wrap;
const LuauTry = common.luau.loader.LuauTry;
const luauError = common.luau.loader.luauError;

///Sends the exported functions to luau.
pub fn load_export(luau: *Luau) void {
    luau.newTable();

    luau.pushFunction(wrap(fetch_fn));
    luau.setField(-2, "fetch");

    //Push all HTTP methods to the methods enum.
    luau.newTable();
    for (std.enums.values(http.Method)) |method| {
        const method_name = @tagName(method);
        _ = luau.pushString(method_name);
        luau.setField(-2, method_name);
    }
    luau.setField(-2, "methods");

    luau.setGlobal("http");
}

const logger = std.log.scoped(.luau_HTTP);

///Sends an HTTP request to the given URL.
///Response buffer is required to read the response of the request.
fn fetch(
    allocator: std.mem.Allocator,
    url: []const u8,
    method: http.Method,
    response_writer: *std.io.Writer,
    body: ?[]const u8,
    content_type: ?[]const u8,
    authorization: ?[]const u8,
) anyerror!http.Status {
    var http_client = http.Client{ .allocator = allocator };
    defer http_client.deinit();

    //If a header is defined set it otherwise no header
    var content_type_value: http.Client.Request.Headers.Value = .omit;
    if (content_type) |non_null| content_type_value = .{ .override = non_null };

    var authorization_value: http.Client.Request.Headers.Value = .omit;
    if (authorization) |non_null| authorization_value = .{ .override = non_null };

    const response = try http_client.fetch(.{
        .method = method,
        .location = .{ .url = url },
        .keep_alive = false,
        .response_writer = response_writer,
        .payload = body,
        .headers = .{
            .user_agent = .{ .override = "Nice-Clock" },
            .content_type = content_type_value,
            .authorization = authorization_value,
        },
    });
    return response.status;
}

const HTTPResponseTable = struct { status: u10, body: []const u8 };

const tryToString = LuauTry([:0]const u8, "Failed to parse string from Luau!");

//Luau functions

///(Luau)
///Sends an HTTP request and returns the response and the status code in a Luau table.
fn fetch_fn(luau: *Luau) i32 {
    const allocator = std.heap.page_allocator;

    luau.checkType(1, .string);
    luau.checkType(2, .string);
    if (!luau.isNil(3) and !luau.isString(3)) luauError(luau, "body must be either type string or nil.");
    if (!luau.isNil(4) and !luau.isString(4)) luauError(luau, "content_type must be either type string or nil.");
    if (!luau.isNil(5) and !luau.isString(5)) luauError(luau, "authorization must be either type string or nil.");

    const method = std.meta.stringToEnum(http.Method, tryToString.unwrap(luau, luau.toString(2)));
    if (method == null) luauError(luau, "Invalid HTTP method.");

    const url = tryToString.unwrap(luau, luau.toString(1));
    var content_type: ?[:0]const u8 = null;
    var authorization: ?[:0]const u8 = null;
    var body: ?[:0]const u8 = null;

    if (luau.isString(3)) body = tryToString.unwrap(luau, luau.toString(3));
    if (luau.isString(4)) content_type = tryToString.unwrap(luau, luau.toString(4));
    if (luau.isString(5)) authorization = tryToString.unwrap(luau, luau.toString(5));

    var response_writer = std.io.Writer.Allocating.init(allocator);
    defer response_writer.deinit();

    if (fetch(allocator, url[0..], method.?, &response_writer.writer, body, content_type, authorization)) |response_status| {
        if (@intFromEnum(response_status) >= 400) {
            const message_buffer = std.fmt.allocPrint(allocator, "HTTP Error: {d} ({t})", .{ @intFromEnum(response_status), response_status }) catch |e| {
                luauError(luau, "Failed to allocate http error message buffer!");
                logger.err("Failed to allocate http error message buffer: {t}", .{e});
            };

            logger.err("{s}", .{message_buffer});
            luauError(luau, message_buffer);
            defer allocator.free(message_buffer);
        }

        const table = HTTPResponseTable{ .status = @intFromEnum(response_status), .body = response_writer.written() };
        luau.pushAny(table) catch |e| {
            logger.err("Error pushing HTTPResponseTable from zig: {t}", .{e});
            luauError(luau, "Error pushing HTTPResponseTable from zig.");
        };
    } else |e| {
        logger.err("Error fetching url: {s} from Luau: {t}", .{ url, e });
        luauError(luau, "Error fetching.");
    }

    return 1;
}
