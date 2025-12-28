const std = @import("std");
const builtin = @import("builtin");

pub fn build(b: *std.Build) !void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{ .preferred_optimize_mode = std.builtin.OptimizeMode.ReleaseSafe });

    const common_lib = b.addModule("common", .{
        .root_source_file = b.path("src/common/common.zig"),
        .target = target,
        .optimize = optimize,
    });

    //Common deps
    const time_dep = b.dependency("datetime", .{
        .target = target,
        .optimize = optimize,
    });

    const lua_dep = b.dependency("zlua", .{
        .target = target,
        .optimize = optimize,
        .lang = .luau,
        .shared = false,
    });

    common_lib.addImport("zlua", lua_dep.module("zlua"));
    common_lib.addImport("datetime", time_dep.module("datetime"));

    const ClockTarget = enum {
        sim,
        hardware,
    };

    const clock_target_option = b.option(ClockTarget, "clock-target", "Used to speicify if you are building the clock for a simulator or hardware. Default: sim") orelse .sim;

    //Only build for the specified platform

    // Sim
    if (clock_target_option == .sim) {
        const sim_exe = b.addExecutable(.{
            .name = "nice-clock-sim",
            .root_module = b.createModule(.{
                .root_source_file = b.path("src/simulator/simulator.zig"),
                .target = target,
                .optimize = std.builtin.OptimizeMode.Debug,
            }),
        });

        if (target.result.os.tag == .linux) {
            // The SDL package doesn't work for Linux yet, so we rely on system
            // packages for now.
            sim_exe.linkSystemLibrary("SDL2");
            sim_exe.linkLibC();
        } else {
            const sdl_dep = b.dependency("SDL", .{
                .optimize = .ReleaseFast,
                .target = target,
            });
            sim_exe.linkLibrary(sdl_dep.artifact("SDL2"));
        }

        sim_exe.root_module.addImport("common", common_lib);
        b.installArtifact(sim_exe);

        const sim_run_cmd = b.addRunArtifact(sim_exe);

        sim_run_cmd.step.dependOn(b.getInstallStep());
        const sim_run_step = b.step("run", "Run the clock sim");
        sim_run_step.dependOn(&sim_run_cmd.step);
        const check = b.step("check", "Check if code compiles");
        check.dependOn(&sim_exe.step);
    } else {
        //Hardware
        const hardware_exe = b.addExecutable(.{
            .name = "nice-clock-hardware",
            .root_module = b.createModule(.{
                .root_source_file = b.path("src/hardware/hardware.zig"),
                .target = target,
                .optimize = optimize,
            }),
        });

        hardware_exe.root_module.addImport("common", common_lib);
        hardware_exe.addIncludePath(b.path("include/rpi-rgb-led-matrix/include"));

        hardware_exe.addCSourceFiles(.{ .root = b.path("include/rpi-rgb-led-matrix/lib"), .files = &[_][]const u8{
            "led-matrix-c.cc",
            "gpio.cc",
            "content-streamer.cc",
            "framebuffer.cc",
            "hardware-mapping.c",
            "options-initialize.cc",
            "pixel-mapper.cc",
            "thread.cc",
            "led-matrix.cc",
            "bdf-font.cc",
            "graphics.cc",
            "multiplex-mappers.cc",
        } });
        hardware_exe.linkLibC();

        b.installArtifact(hardware_exe);

        const hardware_run_cmd = b.addRunArtifact(hardware_exe);

        hardware_run_cmd.step.dependOn(b.getInstallStep());

        if (b.args) |args| {
            hardware_run_cmd.addArgs(args);
        }

        const hardware_run_step = b.step("run-hardware", "Run the clock hardware");
        hardware_run_step.dependOn(&hardware_run_cmd.step);
        const check = b.step("check", "Check if code compiles");
        check.dependOn(&hardware_exe.step);
    }

    // Rest

    const common_lib_tests = b.addTest(.{ .root_module = common_lib });
    const run_lib_tests = b.addRunArtifact(common_lib_tests);

    const test_step = b.step("test", "Run unit tests");
    test_step.dependOn(&run_lib_tests.step);
}
