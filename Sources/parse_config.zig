
const dwm = @cImport(@cInclude("dwm.h"));
const types = @import("types.zig");
const std = @import("std");

// pub fn file(allocator: std.mem.Allocator, filename: []const u8) !config.LayoutList {
//     const content = try std.fs
//         .cwd()
//         .openFile(filename, .{});
//     return config.LayoutList.jsonParse(allocator, content.reader(), .{});
// }

pub fn mock(alloc: std.mem.Allocator) !types.LayoutList {
    var layouts = types.LayoutList.init(alloc);
    try layouts.put("layout1", .{ .tag = 1, .applications = &.{
        .{ .title = "glxgears" } } });
    try layouts.put("layout2", .{ .tag = 2, .applications = &.{
        .{ .title = "vidtest" } } });
    return layouts;
}

pub fn rules(alloc: std.mem.Allocator, layouts: types.LayoutList) ![]dwm.Rule {
    var rules_list = types.RuleList.init(alloc);

    for (layouts.values()) |layout| {
        const layout_rules = try layout.rules(alloc);
        try rules_list.appendSlice(layout_rules);
    }
    return try rules_list.toOwnedSlice();
}
