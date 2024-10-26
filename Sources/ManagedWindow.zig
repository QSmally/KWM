
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
