
const std = @import("std");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    const exec = b.addExecutable(.{
        .name = "ExtendedWM",
        .link_libc = true,
        .root_source_file = b.path("Sources/main.zig"),
        .target = target,
        .optimize = optimize });
    exec.linkSystemLibrary("X11");
    b.installArtifact(exec);

    const run_cmd = b.addRunArtifact(exec);
    run_cmd.step.dependOn(b.getInstallStep());

    if (b.args) |args|
        run_cmd.addArgs(args);

    const run_step = b.step("run", "build and execute");
    run_step.dependOn(&run_cmd.step);
}
