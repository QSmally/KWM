
const std = @import("std");

const Layout = @import("./Layout.zig");
const ManagedWindow = @import("./ManagedWindow.zig");
const X11 = @import("./x11.zig");

const Self = @This();

allocator: std.mem.Allocator,
layouts: Layout.List,
display: *X11.Display,
screen_width: c_int,
screen_height: c_int,
is_running: bool,
current_layout: []const u8,
current_layout_lock: std.Thread.Mutex,
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
        .current_layout = Layout.default,
        .current_layout_lock = std.Thread.Mutex {},
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

pub fn layout_for(self: *Self, managed_window: *const ManagedWindow) ?Layout {
    self.current_layout_lock.lock();
    const layout = self.layouts.get(self.current_layout);
    self.current_layout_lock.unlock();

    if (layout) |layout_| {
        for (layout_) |application| {
            if (managed_window.is_matching_rule(self, &application))
                return application;
        }
    }

    return null;
}

pub fn layout_select(self: *Self, layout: []const u8) !void {
    const layout_names = self.layouts.keys();

    for (layout_names) |layout_name| {
        if (std.mem.eql(u8, layout, layout_name)) {
            self.current_layout_lock.lock();
            defer self.current_layout_lock.unlock();

            // put current_layout pointer to list's key pointer, only
            // invalidates if the list is ever changed. 'layout' is managed
            // externally and may be invalid early
            self.current_layout = layout_name;
            return;
        }
    }

    return error.layoutUnknown;
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

pub fn rerender(self: *Self) void {
    var iterator = self.managed_windows;

    while (iterator) |managed_window| {
        // may be unsafe/inconsistent with checking current layout name if
        // the layout is changed in the middle of rerendering
        if (self.layout_for(managed_window)) |layout| {
            managed_window.prepare(self.display, layout);
            managed_window.show(self.display);
        } else {
            managed_window.hide(self.display);
        }

        iterator = managed_window.next;
    }
}
