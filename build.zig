
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
        &.{ "Sources/dwm/dwm.c", "Sources/dwm/drw.c", "Sources/dwm/util.c" },
        &.{ "-Wno-deprecated-declarations" });
    dwm.addIncludePath(.{ .path = "Sources/include" });
    dwm.addIncludePath(.{ .path = "Sources/dwm" });
    dwm.linkSystemLibrary("X11");
    dwm.linkSystemLibrary("Xft");
    dwm.linkSystemLibrary("Xinerama");
    dwm.linkSystemLibrary("fontconfig");

    const kwm = b.addExecutable(.{
        .name = "KWM",
        .root_source_file = .{ .path = "Sources/main.zig" },
        .target = target,
        .optimize = optimize });
    kwm.addIncludePath(.{ .path = "Sources/dwm" });
    kwm.addObject(dwm);

    b.installArtifact(kwm);
}
