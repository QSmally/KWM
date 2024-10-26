
const X11 = @cImport({
    @cInclude("X11/Xlib.h");
    @cInclude("X11/X.h");
    @cInclude("X11/Xutil.h");
    @cInclude("X11/Xatom.h");
    @cInclude("X11/cursorfont.h"); });
const std = @import("std");

const Layout = @import("./Layout.zig");
const Runtime = @import("./Runtime.zig");
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
        const coordinates = layout.application.coordinates;
        _ = X11.XMoveResizeWindow(runtime.display, managed_window.x11_window, @intCast(coordinates[0]), @intCast(coordinates[1]), coordinates[2], coordinates[3]);

        if (layout.is_same_layout(runtime.current_layout))
            _ = X11.XMapWindow(runtime.display, managed_window.x11_window);
    }
}

fn on_destroy_notify(runtime: *Runtime, event: *X11.XDestroyWindowEvent) void {
    const managed_window = runtime.managed_window_find(event.window);
    if (managed_window) |managed_window_|
        runtime.unmanage_window(managed_window_);
}
