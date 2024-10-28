
const std = @import("std");

const Layout = @import("./Layout.zig");
const Runtime = @import("./Runtime.zig");
const X11 = @import("./x11.zig");
const wm = @import("./wm.zig");

const Self = @This();

next: ?*Self,
allocator: std.mem.Allocator,
x11_window: X11.Window,

pub fn init(alloc: std.mem.Allocator, window: X11.Window) Self {
    return .{
        .allocator = alloc,
        .x11_window = window,
        .next = null };
}

pub fn deinit(self: *Self) void {
    self.allocator.destroy(self);
}

pub fn is_match(self: *const Self, window: X11.Window) bool {
    return self.x11_window == window;
}

pub fn is_matching_rule(self: *const Self, runtime: *const Runtime, layout: *const Layout) bool {
    const window_name = runtime.text_property_alloc(X11.XA_WM_NAME, self.x11_window) catch |err| {
        wm.tell("XGetTextProperty failed: {}", .{ err });
        return false;
    };
    defer runtime.allocator.free(window_name);

    if (layout.titles) |titles|
        return std.mem.indexOf(u8, titles, window_name) != null;
    return false;
}

pub fn prepare(self: *const Self, display: *X11.Display, layout: Layout) void {
    _ = X11.XMoveResizeWindow(
        display,
        self.x11_window,
        @intCast(layout.coordinates[0]),
        @intCast(layout.coordinates[1]),
        layout.coordinates[2],
        layout.coordinates[3]);
}

pub fn show(self: *const Self, display: *X11.Display) void {
    _ = X11.XMapWindow(display, self.x11_window);
}

pub fn hide(self: *const Self, display: *X11.Display) void {
    _ = X11.XUnmapWindow(display, self.x11_window);
}
