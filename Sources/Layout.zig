
const std = @import("std");

const Layout = @This();

const ParseList = std.json.ArrayHashMap([]Layout);
pub const List = std.StringArrayHashMapUnmanaged([]Layout);
pub const default = "default";

titles: ?[]const u8 = null,
coordinates: [4]c_uint = .{ 0, 0, 400, 250 },
touch_jump_to: ?[]const u8 = null,
fallback_to: ?[]const u8 = null,

pub fn from_file(alloc: std.mem.Allocator, path: []const u8) !List {
    const content = try std.fs
        .cwd()
        .openFile(path, .{});
    defer content.close();

    var reader = std.json.reader(alloc, content.reader());
    defer reader.deinit();

    const parsed = try std.json.parseFromTokenSource(ParseList, alloc, &reader, .{});
    return parsed.value.map;
}
