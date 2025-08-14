const std = @import("std");
const testing = std.testing;
const common = @import("../common.zig");
const Color = common.Color;

///A PPM Image
pub const PPM = struct {
    width: u8,
    height: u8,
    pixles: []Color,

    pub const Error = error{ InvalidFileType, FailedToParseHeader, UnsuportedMaxColor, Overflow };

    ///Parses a PPM image file into a `PPM` struct.
    pub fn parsePPM(allocator: std.mem.Allocator, input: []const u8) !PPM {
        var lines = std.mem.tokenizeSequence(u8, input, "\n");

        var width: ?u8 = null;
        var height: ?u8 = null;
        var max_color_value: ?u16 = null;

        var pixles: []Color = undefined;

        //Check to see if the magic numbers match
        if (!std.mem.eql(u8, lines.next().?, "P6")) return Error.InvalidFileType;

        while (lines.next()) |line| {
            if (std.mem.startsWith(u8, line, "#")) {
                continue; // Ignore comments
            } else if (std.ascii.isDigit(line[0]) and (width == null and height == null)) {
                var width_x_height = std.mem.tokenizeSequence(u8, line, " ");
                width = try std.fmt.parseInt(u8, width_x_height.next().?, 10);
                height = try std.fmt.parseInt(u8, width_x_height.next().?, 10);
            } else if (std.ascii.isDigit(line[0]) and max_color_value == null) {
                max_color_value = try std.fmt.parseInt(u16, line, 10);
                break;
            }
        }

        if (width == null or height == null or max_color_value == null) return Error.FailedToParseHeader;
        if (max_color_value.? > 255) return Error.UnsuportedMaxColor;

        const pixle_count: u16 = try std.math.mul(u16, @intCast(width.?), @intCast(height.?));

        pixles = try allocator.alloc(Color, pixle_count);
        errdefer allocator.free(pixles);

        //Loop through the raster and convert the u8s to RGB values.
        var pixle_iterator = std.mem.window(u8, lines.next().?, 3, 3);

        for (0..(pixle_count)) |i| {
            const pixle = pixle_iterator.next().?;
            pixles[i] = Color{ .r = pixle[0], .g = pixle[1], .b = pixle[2] };
        }

        return PPM{
            .width = width.?,
            .height = height.?,
            .pixles = pixles,
        };
    }

    ///Calls `deinit` on all loaded pixels.
    pub fn deinit(self: *PPM, allocator: std.mem.Allocator) void {
        allocator.free(self.pixles);
    }
};

///Used to store images for a module. The clock has one `ImageStore` used to store images for each module.
///
///**Call the** `init` **function to create.**
pub const ImageStore = struct {
    image_map: std.StringHashMap(PPM),
    allocator: std.mem.Allocator,

    pub const Error = error{ InvalidFile, ImageLoadingError, ImageNotInStore, OutOfMemory };

    const logger = std.log.scoped(.image_store);

    ///Creates an image store
    pub fn init(allocator: std.mem.Allocator) ImageStore {
        return ImageStore{
            .image_map = std.StringHashMap(PPM).init(allocator),
            .allocator = allocator,
        };
    }

    ///Deallocates the memory created by `init` as well as all of the images.
    pub fn deinit(self: *ImageStore) void {
        self.deinitAllImages();
        self.image_map.deinit();
    }

    ///Adds an image to the store, this parses `assets/{IMAGE_NAME}.ppm`.
    pub fn addImage(self: *ImageStore, image_filename: []const u8) Error!void {
        const image_file = try loadImageFromFile(self.allocator, image_filename);
        try self.image_map.put(image_filename, image_file);
    }

    ///Gets an image from the store. If it is not there a `ImageNotInStore` error will be returned.
    pub fn getImage(self: *ImageStore, image_filename: []const u8) Error!PPM {
        if (!self.image_map.contains(image_filename)) return Error.ImageNotInStore;
        return self.image_map.get(image_filename).?;
    }

    fn loadImageFromFile(allocator: std.mem.Allocator, image_name: []const u8) Error!PPM {
        var arena = std.heap.ArenaAllocator.init(allocator);
        defer arena.deinit();

        const file_name = std.fmt.allocPrint(arena.allocator(), "./assets/images/{s}.ppm", .{image_name}) catch return Error.OutOfMemory;
        const image_file = std.fs.cwd().readFileAlloc(arena.allocator(), file_name, 1000000) catch |e| switch (e) {
            error.FileNotFound => return Error.InvalidFile,
            inline else => {
                logger.err("Error loading image from file: {s} -> {s}", .{ file_name, @errorName(e) });
                return error.ImageLoadingError;
            },
        };
        return PPM.parsePPM(allocator, image_file) catch |e| {
            logger.err("Error parsing PPM: {s} -> {s}", .{ file_name, @errorName(e) });
            return Error.ImageLoadingError;
        };
    }

    ///Attempts to add all of a module's required images to the image store.
    pub fn addImagesForModule(self: *ImageStore, module: *common.module.ClockModule) Error!void {
        if (module.image_names) |image_names| {
            for (image_names) |image_name| {
                try self.addImage(image_name);
            }
        }
    }

    ///Clears the image store a deallocates all images stored in it.
    pub fn deinitAllImages(self: *ImageStore) void {
        var it = self.image_map.valueIterator();

        while (it.next()) |entry| {
            entry.deinit(self.allocator);
        }
        self.image_map.clearRetainingCapacity();
    }
};

test {
    const image_file = try std.fs.cwd().readFileAlloc(testing.allocator, "./assets/images/test.ppm", 1000000);
    var ppm = try PPM.parsePPM(testing.allocator, image_file);
    defer {
        ppm.deinit(testing.allocator);
        testing.allocator.free(image_file);
    }

    try testing.expect(ppm.width == 5);
    try testing.expect(ppm.height == 8);

    for (0..ppm.height) |y| {
        for (0..ppm.width) |x| {
            const pixel = ppm.pixles[y * ppm.width + x];
            if (pixel.elq(Color{ .r = 255, .g = 0, .b = 0 })) {
                std.debug.print("G", .{});
            } else if (pixel.elq(Color{ .r = 0, .g = 255, .b = 0 })) {
                std.debug.print("R", .{});
            } else {
                std.debug.print(" ", .{});
            }
        }
        std.debug.print("\n", .{});
    }
}

test "load_image_from_file" {
    var file = try ImageStore.loadImageFromFile(testing.allocator, "test");
    file.deinit(testing.allocator);

    try testing.expect(file.width == 5);
    try testing.expect(file.height == 8);
}

test "ImageStore" {
    var store = ImageStore.init(testing.allocator);
    defer store.deinit();

    try store.addImage("test");
    const file = try store.getImage("test");
    try testing.expect(file.width == 5);
    try testing.expect(file.height == 8);
}
