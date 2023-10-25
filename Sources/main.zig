
const config = @import("type_config.zig");
const dwm = @cImport(@cInclude("dwm.h"));
const parser = @import("parse_config.zig");
const std = @import("std");

var configuration = std.heap.GeneralPurposeAllocator(.{}) {};
const allocator = configuration.allocator();

pub fn main() void {
    // Mark: file
    var carena = std.heap.ArenaAllocator.init(allocator);
    const callocator = carena.allocator();
    defer _ = carena.deinit();

    // const config = parser.file(callocator, "~/KWM/config.json") catch unreachable;
    const layouts = parser.mock(callocator) catch unreachable;
    const rules = config.rules(callocator, layouts) catch unreachable;
    dwm.set_rules(@ptrCast(rules), rules.len);

    _ = dwm.start();
}
