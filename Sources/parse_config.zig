
const dwm = @cImport(@cInclude("dwm.h"));
const config = @import("type_config.zig");
const std = @import("std");

// pub fn file(allocator: std.mem.Allocator, filename: []const u8) !config.LayoutList {
//     const content = try std.fs
//         .cwd()
//         .openFile(filename, .{});
//     return config.LayoutList.jsonParse(allocator, content.reader(), .{});
// }

pub fn mock(allocator: std.mem.Allocator) !config.LayoutList {
    var layouts = config.LayoutList.init(allocator);
    try layouts.put("layout1", .{ .tag = 3, .applications = &.{
        .{ .class = "st" } } });
    try layouts.put("layout2", .{ .tag = 2, .applications = &.{
        .{ .class = "LibreWolf" } } });
    return layouts;
}
