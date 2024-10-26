
const X11 = @cImport({
    @cInclude("X11/Xlib.h");
    @cInclude("X11/X.h");
    @cInclude("X11/Xutil.h");
    @cInclude("X11/Xatom.h");
    @cInclude("X11/cursorfont.h"); });
const std = @import("std");

const Layout = @import("./Layout.zig");
const ManagedWindow = @import("./ManagedWindow.zig");

const Self = @This();

allocator: std.mem.Allocator,
layouts: Layout.List,
display: *X11.Display,
screen_width: c_int,
screen_height: c_int,
is_running: bool,
current_layout: []const u8,
managed_windows: ?*ManagedWindow,

pub fn init(alloc: std.mem.Allocator, layouts: Layout.List, display: *X11.Display) Self {
    const default_screen = X11.XDefaultScreen(display);
    const screen_width = X11.XDisplayWidth(display, default_screen);
    const screen_height = X11.XDisplayHeight(display, default_screen);

    const root_window = X11.DefaultRootWindow(display);
    _ = X11.XSelectInput(display, root_window, X11.SubstructureRedirectMask | X11.SubstructureNotifyMask);
    _ = X11.XSync(display, X11.False);

    const cursor = X11.XCreateFontCursor(display, X11.XC_left_ptr);
    _ = X11.XDefineCursor(display, root_window, cursor);
    _ = X11.XSync(display, X11.False);

    return .{
        .allocator = alloc,
        .layouts = layouts,
        .display = display,
        .screen_width = screen_width,
        .screen_height = screen_height,
        .is_running = true,
        .current_layout = "default", // could be an index from process lifetime list of layout names
        .managed_windows = null };
}

pub fn deinit(self: *Self) void {
    while (self.managed_windows) |managed_window|
        self.unmanage_window(managed_window); // mutates self.managed_windows
    _ = X11.XCloseDisplay(self.display);
}

pub fn quit(self: *Self) void {
    self.is_running = false;
}

pub fn managed_window_from(self: *Self, window: X11.Window) !*ManagedWindow {
    if (self.managed_window_find(window)) |managed_window|
        return managed_window;

    // create
    var new_managed_window = try self.allocator.create(ManagedWindow);
    new_managed_window.* = ManagedWindow.init(self.allocator, window);
    new_managed_window.next = self.managed_windows;

    self.managed_windows = new_managed_window;
    return new_managed_window;
}

pub fn managed_window_find(self: *const Self, window: X11.Window) ?*ManagedWindow {
    var iterator = self.managed_windows;

    while (iterator) |iterator_| {
        if (iterator_.is_match(window))
            return iterator_;
        iterator = iterator_.next;
    }

    return null;
}

pub fn unmanage_window(self: *Self, managed_window: *ManagedWindow) void {
    // also deallocates self
    defer managed_window.deinit();

    if (self.managed_windows == managed_window) {
        self.managed_windows = managed_window.next;
        return;
    }

    var iterator = self.managed_windows;

    while (iterator) |iterator_| {
        if (iterator_.next == managed_window)
            iterator_.next = managed_window.next;
        iterator = iterator_.next;
    }
}

pub fn layout_for(self: *const Self, managed_window: *const ManagedWindow) ?Layout.Parent {
    var layouts_ = self.layouts.iterator();

    while (layouts_.next()) |layout_| {
        for (layout_.value_ptr.*) |application_| {
            if (managed_window.is_matching_rule(self, &application_))
                return .{
                    .layout = layout_.key_ptr.*,
                    .application = application_ };
        }
    }

    return null;
}

pub fn text_property_alloc(self: *const Self, atom: X11.Atom, window: X11.Window) ![]const u8 {
    var property: X11.XTextProperty = undefined;

    if (X11.XGetTextProperty(self.display, window, &property, atom) < X11.Success)
        return error.badAtomOrWindow;
    if (property.value == null)
        return error.nullWindowName;
    defer _ = X11.XFree(property.value);

    // copy, caller owns memory
    return self.allocator.dupe(u8, std.mem.span(property.value));
}
