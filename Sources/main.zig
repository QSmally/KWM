
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

    // /bin/ExtendedWM [path to configuration.json]
    var arguments = std.process.args();
    _ = arguments.skip();
    const configuration_path = arguments.next() orelse "configuration.json";

    // layout configuration
    var layouts = Layout.from_file(process_lifetime.allocator(), configuration_path) catch |err|
        wm.die("couldn't parse {s} layout: {}", .{ configuration_path, err });
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

        var tcp_thread = std.Thread.spawn(.{}, tcp.thread, .{ &runtime }) catch |err| {
            runtime.deinit(); // clean up display
            wm.die("couldn't spawn TCP thread: {}", .{ err });
        };
        defer tcp_thread.join();

        wm.debug("screen resolution: {}x{}", .{ runtime.screen_width, runtime.screen_height });
        return runloop.runloop(&runtime);
    }

    wm.die("cannot open display", .{});
}

fn on_error(display: ?*X11.Display, event: [*c]X11.XErrorEvent) callconv(.C) c_int {
    const err: *X11.XErrorEvent = @ptrCast(event);
    var error_text: [512:0]u8 = undefined;

    _ = X11.XGetErrorText(display, err.error_code, &error_text, @sizeOf(@TypeOf(error_text)));
    wm.tell("fatal error called by X. req={} err={} {s}", .{ err.request_code, err.error_code, error_text });
    return 0;
}
