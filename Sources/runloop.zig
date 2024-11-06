
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
            X11.EnterNotify => on_enter_notify(runtime, &event.xcrossing),
            else => {}
        }
    }
}

fn on_map_request(runtime: *Runtime, event: *X11.XMapRequestEvent) void {
    const managed_window = runtime.managed_window_from(event.window) catch |err|
        return wm.tell("failed to allocate managed window, keeping it unmanaged: {}", .{ err });
    const current_layout = runtime.current_layout_copy();
    const effective_layout = runtime.effective_layout(current_layout, Runtime.maxRecursion);

    if (runtime.layout_for(effective_layout, managed_window)) |layout| {
        // a window with fallback_to has the power to change the effective
        // layout and must therefore rerender everything, otherwise just add
        // the new window
        if (layout.fallback_to != null) {
            runtime.rerender();
            runtime.rerender();
        } else {
            managed_window.prepare(layout);
            managed_window.show();
        }
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

    const managed_window = runtime.managed_window_find(event.subwindow) orelse
        runtime.managed_window_find(event.window) orelse
        return;
    const current_layout = runtime.current_layout_copy();
    const effective_layout = runtime.effective_layout(current_layout, Runtime.maxRecursion);
    const layout = runtime.layout_for(effective_layout, managed_window) orelse return;
    const target_layout = layout.touch_jump_to orelse return;

    runtime.layout_select(target_layout) catch {
        // perhaps make this unreachable and verify fallback_to and
        // touch_jump_to on start-up
        wm.tell("unknown layout '{s}'", .{ target_layout });
        return;
    };

    runtime.rerender();
    runtime.rerender();

    // disable_touch hack by immediately grabbing pointer which is under the
    // cursor, to avoid fast touch generating an X11.AlreadyGrabbed error.
    // rewrite this to make use of coordinates and new window layout
    // var root_window_: X11.Window = undefined;
    // var child_window: X11.Window = undefined;
    // var root_x: c_int = undefined;
    // var root_y: c_int = undefined;
    // var child_x: c_int = undefined;
    // var child_y: c_int = undefined;
    // var mask: c_uint = undefined;

    // const root_window = X11.DefaultRootWindow(runtime.display);
    // _ = X11.XQueryPointer(runtime.display, root_window, &root_window_, &child_window, &root_x, &root_y, &child_x, &child_y, &mask);
    // wm.debug("XQueryPointer window={}", .{ child_window });

    // if (child_window != X11.None)
    //     on_enter_notify(runtime, .{ .window = child_window });
}

fn on_enter_notify(runtime: *Runtime, event: *X11.XEnterWindowEvent) void {
// fn on_enter_notify(runtime: *Runtime, event: anytype) void {
    _ = X11.XUngrabPointer(runtime.display, X11.CurrentTime);

    const managed_window = runtime.managed_window_find(event.window) orelse return;
    const current_layout = runtime.current_layout_copy();
    const effective_layout = runtime.effective_layout(current_layout, Runtime.maxRecursion);
    const layout = runtime.layout_for(effective_layout, managed_window) orelse return;

    if (layout.disable_touch) {
        const result = X11.XGrabPointer(
            runtime.display,
            managed_window.x11_window,
            X11.True,
            X11.ButtonPressMask,
            X11.GrabModeAsync,
            X11.GrabModeAsync,
            X11.None,
            X11.None,
            X11.CurrentTime);
        wm.debug("XGrabPointer success={} alreadygrabbed={}", .{
            result == X11.Success,
            result == X11.AlreadyGrabbed });
    }

    const window_name = managed_window.text_property_alloc(X11.XA_WM_NAME) catch |err|
        return wm.tell("XGetTextProperty failed: {}", .{ err });
    defer managed_window.allocator.free(window_name);
    wm.debug("window enter. name={s} disable_touch={}", .{ window_name, layout.disable_touch });
}
