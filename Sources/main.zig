
const X11 = @cImport({
    @cInclude("X11/Xlib.h");
    @cInclude("X11/X.h");
    @cInclude("X11/Xutil.h");
    @cInclude("X11/Xatom.h");
    @cInclude("X11/cursorfont.h"); });
const std = @import("std");

const Layout = @import("./Layout.zig");
const Runtime = @import("./Runtime.zig");
const runloop = @import("./runloop.zig");
const wm = @import("./wm.zig");

pub fn main() void {
    var memory = std.heap.GeneralPurposeAllocator(.{ .thread_safe = true }) {};
    var process_lifetime = std.heap.ArenaAllocator.init(memory.allocator());
    defer process_lifetime.deinit();

    // layout configuration
    const layouts = Layout.from_file(process_lifetime.allocator(), "configuration.json") catch |err|
        wm.die("couldn't parse layout configuration: {}", .{ err });
    if (!layouts.contains(Layout.default))
        wm.die("layout configuration must at least contain '{s}' layout", .{ Layout.default });

    // null defaults to $DISPLAY
    const display = X11.XOpenDisplay(null);
    _ = X11.XSetErrorHandler(on_error);

    if (display) |display_| {
        var runtime = Runtime.init(process_lifetime.allocator(), layouts, display_);
        defer runtime.deinit();
        return runloop.runloop(&runtime);
    }

    wm.die("cannot open display", .{});
}

fn on_error(display: ?*X11.Display, event: [*c]X11.XErrorEvent) callconv(.C) c_int {
    _ = display;
    const err: *X11.XErrorEvent = @ptrCast(event);
    wm.tell("fatal error. req={} err={}", .{ err.request_code, err.error_code });
    return 0;
}
