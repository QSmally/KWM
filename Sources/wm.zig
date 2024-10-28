
const std = @import("std");

pub fn tell(comptime message: []const u8, arguments: anytype) void {
    std.debug.print("ExtendedWM: " ++ message ++ "\n", arguments);
}

pub fn debug(comptime message: []const u8, arguments: anytype) void {
    if ((std.process.parseEnvVarInt("DEBUG_ENABLED", i8, 10) catch 0) > 0)
        tell(message, arguments);
}

pub fn die(comptime message: []const u8, arguments: anytype) noreturn {
    tell(message, arguments);
    std.process.exit(1);
}
