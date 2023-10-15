
const std = @import("std");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    const dwm = b.addObject(.{
        .name = "DWM",
        .link_libc = true,
        .target = target,
        .optimize = optimize });
    dwm.addCSourceFiles(
        &.{ "Sources/libdwm/dwm.c", "Sources/libdwm/drw.c", "Sources/libdwm/util.c" },
        &.{ "-Wno-deprecated-declarations" });
    dwm.addIncludePath(.{ .path = "Sources/include" });
    dwm.linkSystemLibrary("X11");
    dwm.linkSystemLibrary("Xft");
    dwm.linkSystemLibrary("Xinerama");
    dwm.linkSystemLibrary("fontconfig");

    const kwm = b.addExecutable(.{
        .name = "KWM",
        .root_source_file = .{ .path = "Sources/main.zig" },
        .target = target,
        .optimize = optimize });
    kwm.addIncludePath(.{ .path = "Sources/libdwm" });
    kwm.addObject(dwm);

    b.installArtifact(kwm);
}
