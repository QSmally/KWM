
const dwm = @cImport(@cInclude("dwm.h"));
const parse_config = @import("parse_config.zig");
const std = @import("std");
const types = @import("types.zig");

var allocType = std.heap.GeneralPurposeAllocator(.{}) {};
const allocator = allocType.allocator();

pub fn main() void {
    // Mark: file
    var config_alloc = std.heap.ArenaAllocator.init(allocator);
    defer _ = config_alloc.deinit();

    // const types = parse_config.file(config_alloc.allocator(), "~/KWM/types.json") catch unreachable;
    const layouts = parse_config.mock(config_alloc.allocator()) catch unreachable;
    const rules = parse_config.rules(config_alloc.allocator(), layouts) catch unreachable;
    dwm.set_rules(@ptrCast(rules), rules.len);

    _ = dwm.start();
}
