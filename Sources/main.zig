
const std = @import("std");

const Layout = @import("./Layout.zig");
const Runtime = @import("./Runtime.zig");
const X11 = @import("./x11.zig");
const runloop = @import("./runloop.zig");
const tcp = @import("./tcp.zig");
const wm = @import("./wm.zig");

pub fn main() void {
    var memory = std.heap.GeneralPurposeAllocator(.{ .thread_safe = true }) {};
    var process_lifetime = std.heap.ArenaAllocator.init(memory.allocator());
    defer process_lifetime.deinit();

    // layout configuration
    var layouts = Layout.from_file(process_lifetime.allocator(), "configuration.json") catch |err|
        wm.die("couldn't parse configuration.json layout: {}", .{ err });
    if (!layouts.contains(Layout.default))
        wm.die("layout configuration must at least contain '{s}' layout", .{ Layout.default });
    layouts.lockPointers(); // prevent accidentally invalidating keys
    wm.debug("loaded layouts: {}", .{ layouts.count() });

    // null defaults to $DISPLAY
    const display = X11.XOpenDisplay(null);
    _ = X11.XSetErrorHandler(on_error);

    if (display) |display_| {
        var runtime = Runtime.init(process_lifetime.allocator(), layouts, display_);
        defer runtime.deinit();

        var tcp_thread = std.Thread.spawn(.{}, tcp.thread, .{ &runtime }) catch |err|
            wm.die("couldn't spawn TCP thread: {}", .{ err });
        defer tcp_thread.join();

        wm.debug("screen resolution: {}x{}", .{ runtime.screen_width, runtime.screen_height });
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
