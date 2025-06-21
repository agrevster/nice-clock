const std = @import("std");

pub fn build(b: *std.Build) !void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    const common_lib = b.addModule("common", .{
        .root_source_file = b.path("src/common/common.zig"),
        .target = target,
        .optimize = optimize,
    });

    const sim_exe = b.addExecutable(.{
        .name = "nice-clock-sim",
        .root_source_file = b.path("src/simulator/simulator.zig"),
        .target = target,
        .optimize = std.builtin.OptimizeMode.Debug,
    });

    //
    // Dependencies
    //
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

    sim_exe.root_module.addImport("common", common_lib);

    b.installArtifact(sim_exe);

    const sim_run_cmd = b.addRunArtifact(sim_exe);

    sim_run_cmd.step.dependOn(b.getInstallStep());

    if (b.args) |args| {
        sim_run_cmd.addArgs(args);
    }

    const common_lib_tests = b.addTest(.{ .root_module = common_lib });
    const run_lib_tests = b.addRunArtifact(common_lib_tests);

    const test_step = b.step("test", "Run unit tests");
    test_step.dependOn(&run_lib_tests.step);

    const check = b.step("check", "Check if foo compiles");
    check.dependOn(&sim_exe.step);

    const sim_run_step = b.step("run-sim", "Run the clock sim");
    sim_run_step.dependOn(&sim_run_cmd.step);
}
