
const std = @import("std");

const Layout = @import("./Layout.zig");
const Runtime = @import("./Runtime.zig");
const X11 = @import("./x11.zig");
const wm = @import("./wm.zig");

pub fn runloop(runtime: *Runtime) void {
    while (runtime.is_running) {
        var event: X11.XEvent = undefined;

        if (X11.XNextEvent(runtime.display, &event) != X11.Success)
            continue;
        switch (event.type) {
            X11.MapRequest => on_map_request(runtime, &event.xmaprequest),
            X11.DestroyNotify => on_destroy_notify(runtime, &event.xdestroywindow),
            else => {}
        }
    }
}

fn on_map_request(runtime: *Runtime, event: *X11.XMapRequestEvent) void {
    const managed_window = runtime.managed_window_from(event.window) catch |err| {
        wm.tell("failed to allocate managed window, keeping it unmanaged: {}", .{ err });
        return;
    };

    if (runtime.layout_for(managed_window)) |layout| {
        managed_window.prepare(runtime.display, layout);
        managed_window.show(runtime.display);
    }
}

fn on_destroy_notify(runtime: *Runtime, event: *X11.XDestroyWindowEvent) void {
    const managed_window = runtime.managed_window_find(event.window);
    if (managed_window) |managed_window_|
        runtime.unmanage_window(managed_window_);
}
