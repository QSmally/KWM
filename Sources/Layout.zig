
const std = @import("std");

const Self = @This();

pub const Parent = struct {
    layout: []const u8,
    application: Self,
};

const ParseList = std.json.ArrayHashMap([]Self);
pub const List = std.StringArrayHashMapUnmanaged([]Self);
pub const default = "default";

titles: ?[]const u8 = null,
classes: ?[]const u8 = null, // not implemented
instances: ?[]const u8 = null, // not implemented
coordinates: [4]c_uint = .{ 0, 0, 400, 250 },
disable_touch: bool = false, // not implemented
touch_jump_to: ?[]const u8 = null, // not implemented
fallback_to: ?[]const u8 = null, // not implemented
image_path: ?[]const u8 = null, // not implemented

pub fn from_file(alloc: std.mem.Allocator, path: []const u8) !List {
    const content = try std.fs
        .cwd()
        .openFile(path, .{});
    var reader = std.json.reader(alloc, content.reader());
    defer reader.deinit();

    const parsed = try std.json.parseFromTokenSource(ParseList, alloc, &reader, .{});
    return parsed.value.map;
}
