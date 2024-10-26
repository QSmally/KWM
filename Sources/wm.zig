
const std = @import("std");

pub fn tell(comptime message: []const u8, arguments: anytype) void {
    std.debug.print("ExtendedWM: " ++ message ++ "\n", arguments);
    // flush
}

pub fn die(comptime message: []const u8, arguments: anytype) noreturn {
    tell(message, arguments);
    std.process.exit(1);
}
