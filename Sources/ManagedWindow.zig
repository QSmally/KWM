
const std = @import("std");

const Layout = @import("./Layout.zig");
const Runtime = @import("./Runtime.zig");
const X11 = @import("./x11.zig");
const wm = @import("./wm.zig");

const ManagedWindow = @This();

next: ?*ManagedWindow,
allocator: std.mem.Allocator,
display: *X11.Display,
x11_window: X11.Window,

pub fn init(alloc: std.mem.Allocator, display: *X11.Display, window: X11.Window) ManagedWindow {
    return .{
        .next = null,
        .allocator = alloc,
        .display = display,
        .x11_window = window };
}

pub fn deinit(self: *ManagedWindow) void {
    self.allocator.destroy(self);
}

pub fn is_match(self: *const ManagedWindow, window: X11.Window) bool {
    return self.x11_window == window;
}

pub fn is_matching_rule(self: *const ManagedWindow, layout: *const Layout) bool {
    const window_name = self.text_property_alloc(X11.XA_WM_NAME) catch |err| {
        wm.tell("XGetTextProperty failed: {}", .{ err });
        return false;
    };
    defer self.allocator.free(window_name);

    if (layout.titles) |titles|
        return std.mem.indexOf(u8, titles, window_name) != null;
    return false;
}

pub fn text_property_alloc(self: *const ManagedWindow, atom: X11.Atom) ![]const u8 {
    var property: X11.XTextProperty = undefined;

    if (X11.XGetTextProperty(self.display, self.x11_window, &property, atom) < X11.Success)
        return error.badAtomOrWindow;
    if (property.value == null)
        return error.nullWindowName;
    defer _ = X11.XFree(property.value);

    // copy, caller owns memory
    return self.allocator.dupe(u8, std.mem.span(property.value));
}

const eventMask = X11.EnterWindowMask;

pub fn prepare(self: *const ManagedWindow, layout: Layout) void {
    _ = X11.XMoveResizeWindow(
        self.display,
        self.x11_window,
        @intCast(layout.coordinates[0]),
        @intCast(layout.coordinates[1]),
        layout.coordinates[2],
        layout.coordinates[3]);
    _ = X11.XSelectInput(self.display, self.x11_window, eventMask);
}

pub fn show(self: *const ManagedWindow) void {
    _ = X11.XMapWindow(self.display, self.x11_window);
}

pub fn hide(self: *const ManagedWindow) void {
    _ = X11.XUnmapWindow(self.display, self.x11_window);
}
