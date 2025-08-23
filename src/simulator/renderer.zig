const sdl = @cImport({
    @cInclude("SDL2/SDL.h");
});
const common = @import("common");
const std = @import("std");

const Rect = struct {
    y: u6,
    x: u16,
    w: u8,
    h: u8,
};

pub fn startSimulator(logger: anytype, tiles: *[32][64]common.Color, is_active: *std.atomic.Value(bool)) !void {
    var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    defer arena.deinit();
    if (sdl.SDL_Init(sdl.SDL_INIT_VIDEO) != 0) {
        logger.err("Unable to start SDL: {s}", .{sdl.SDL_GetError()});
        return error.SDLInitializationFailed;
    }

    const screen = sdl.SDL_CreateWindow("nice clock: simulator", sdl.SDL_WINDOWPOS_UNDEFINED, sdl.SDL_WINDOWPOS_UNDEFINED, 975, 493, sdl.SDL_WINDOW_SHOWN) orelse {
        logger.err("Unable to create window SDL: {s}", .{sdl.SDL_GetError()});
        return error.SDLInitializationFailed;
    };

    const renderer = sdl.SDL_CreateRenderer(screen, -1, 0) orelse {
        logger.err("Unable to create renderer SDL: {s}", .{sdl.SDL_GetError()});
        return error.SDLInitializationFailed;
    };
    defer sdl.SDL_DestroyRenderer(renderer);
    defer sdl.SDL_DestroyWindow(screen);
    defer sdl.SDL_Quit();
    // sdl.SDL_SetWindowResizable(screen, 1);

    while (is_active.load(.seq_cst)) {
        var event: sdl.SDL_Event = undefined;
        while (sdl.SDL_PollEvent(&event) != 0) {
            switch (event.type) {
                sdl.SDL_QUIT => {
                    is_active.store(false, .seq_cst);
                },
                else => {},
            }
        }
        _ = sdl.SDL_SetRenderDrawColor(renderer, 27, 31, 25, 100);
        _ = sdl.SDL_RenderClear(renderer);
        for (0..32) |grid_y| {
            for (0..64) |grid_x| {
                const color = tiles[grid_y][grid_x];
                const grid_x_32: i32 = @intCast(grid_x);
                const grid_y_32: i32 = @intCast(grid_y);
                _ = sdl.SDL_SetRenderDrawColor(renderer, color.r, color.g, color.b, 255);
                _ = sdl.SDL_RenderFillRect(renderer, &sdl.SDL_Rect{
                    .x = 10 + (grid_x_32 * 15),
                    .y = 10 + (grid_y_32 * 15),
                    .w = 10,
                    .h = 10,
                });
            }
        }

        sdl.SDL_RenderPresent(renderer);
        sdl.SDL_Delay(15);
    }
}
