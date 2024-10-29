
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
            X11.ButtonPress => on_button_press(runtime, &event.xbutton),
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

    wm.debug("new window. managed windows={}", .{ runtime.managed_window_len() });
}

fn on_destroy_notify(runtime: *Runtime, event: *X11.XDestroyWindowEvent) void {
    if (runtime.managed_window_find(event.window)) |managed_window|
        runtime.unmanage_window(managed_window);
    wm.debug("window quit. managed windows={}", .{ runtime.managed_window_len() });
}

fn on_button_press(runtime: *Runtime, event: *X11.XButtonPressedEvent) void {
    wm.debug("button press. x={} y={}", .{ event.x_root, event.y_root });
    defer _ = X11.XAllowEvents(runtime.display, X11.ReplayPointer, X11.CurrentTime);

    const managed_window = runtime.managed_window_find(event.subwindow) orelse return;
    const layout = runtime.layout_for(managed_window) orelse return;
    const target_layout = layout.touch_jump_to orelse return;

    runtime.layout_select(target_layout) catch {
        // perhaps make this unreachable and verify fallback_to and
        // touch_jump_to on start-up
        wm.tell("unknown layout '{s}'", .{ target_layout });
        return;
    };

    runtime.rerender();
    runtime.rerender();
}
