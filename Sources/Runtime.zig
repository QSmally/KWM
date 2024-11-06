
const std = @import("std");

const Layout = @import("./Layout.zig");
const ManagedWindow = @import("./ManagedWindow.zig");
const X11 = @import("./x11.zig");

const Runtime = @This();

const eventMask = X11.SubstructureRedirectMask |
    X11.SubstructureNotifyMask |
    X11.ButtonPressMask;
pub const maxRecursion = 16;

allocator: std.mem.Allocator,
layouts: Layout.List,
display: *X11.Display,
screen_width: c_int,
screen_height: c_int,
is_running: bool,
current_layout: []const u8,
current_layout_lock: std.Thread.Mutex,
managed_windows: ?*ManagedWindow,
managed_windows_lock: std.Thread.Mutex,

pub fn init(alloc: std.mem.Allocator, layouts: Layout.List, display: *X11.Display) Runtime {
    const default_screen = X11.XDefaultScreen(display);
    const screen_width = X11.XDisplayWidth(display, default_screen);
    const screen_height = X11.XDisplayHeight(display, default_screen);

    const root_window = X11.DefaultRootWindow(display);
    _ = X11.XSelectInput(display, root_window, eventMask);
    _ = X11.XGrabButton(
        display,
        X11.Button1,
        X11.False,
        root_window,
        X11.False,
        X11.ButtonPressMask,
        X11.GrabModeSync,
        X11.GrabModeAsync,
        X11.None,
        X11.None);
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
        .managed_windows = null,
        .managed_windows_lock = std.Thread.Mutex {} };
}

pub fn deinit(self: *Runtime) void {
    while (self.managed_windows) |managed_window|
        self.unmanage_window(managed_window); // mutates self.managed_windows
    _ = X11.XCloseDisplay(self.display);
}

pub fn quit(self: *Runtime) void {
    self.is_running = false;
}

pub fn managed_window_len(self: *Runtime) u32 {
    self.managed_windows_lock.lock();
    defer self.managed_windows_lock.unlock();
    var len: u32 = 0;
    var iterator = self.managed_windows;

    while (iterator) |iterator_| {
        len += 1;
        iterator = iterator_.next;
    }

    return len;
}

pub fn managed_window_from(self: *Runtime, window: X11.Window) !*ManagedWindow {
    if (self.managed_window_find(window)) |managed_window|
        return managed_window;

    // create
    var new_managed_window = try self.allocator.create(ManagedWindow);
    new_managed_window.* = ManagedWindow.init(self.allocator, self.display, window);

    // prepend
    self.managed_windows_lock.lock();
    defer self.managed_windows_lock.unlock();
    new_managed_window.next = self.managed_windows;
    self.managed_windows = new_managed_window;
    return new_managed_window;
}

pub fn managed_window_find(self: *Runtime, window: X11.Window) ?*ManagedWindow {
    self.managed_windows_lock.lock();
    defer self.managed_windows_lock.unlock();
    var iterator = self.managed_windows;

    while (iterator) |iterator_| {
        if (iterator_.is_match(window))
            return iterator_;
        iterator = iterator_.next;
    }

    return null;
}

pub fn unmanage_window(self: *Runtime, managed_window: *ManagedWindow) void {
    self.managed_windows_lock.lock();
    defer self.managed_windows_lock.unlock();

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

pub fn current_layout_copy(self: *Runtime) []const u8 {
    self.current_layout_lock.lock();
    const copy = self.current_layout;
    self.current_layout_lock.unlock();
    return copy;
}

pub fn effective_layout(self: *Runtime, layout: []const u8, max_recursion: u16) []const u8 {
    if (max_recursion == 0)
        return layout;
    const layouts = self.layouts.get(layout);

    if (layouts) |layouts_| {
        layout_loop: for (layouts_) |application| {
            if (application.fallback_to) |fallback| {
                self.managed_windows_lock.lock();
                defer self.managed_windows_lock.unlock();
                var iterator = self.managed_windows;

                // at least one window must conform to this layout
                while (iterator) |managed_window| {
                    if (managed_window.is_matching_rule(&application))
                        continue :layout_loop;
                    iterator = managed_window.next;
                }

                // else a recursive call is done to fallback
                return self.effective_layout(fallback, max_recursion - 1);
            }
        }
    }

    return layout;
}

pub fn layout_for(self: *Runtime, layout: []const u8, managed_window: *const ManagedWindow) ?Layout {
    const layouts = self.layouts.get(layout);

    if (layouts) |layouts_| {
        for (layouts_) |application| {
            if (managed_window.is_matching_rule(&application))
                return application;
        }
    }

    return null;
}

pub fn layout_select(self: *Runtime, layout: []const u8) !void {
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

pub fn rerender(self: *Runtime) void {
    const current_layout_ = self.current_layout_copy();
    const effective_layout_ = self.effective_layout(current_layout_, Runtime.maxRecursion);

    // cannot be called when current_layout_lock is locked
    self.managed_windows_lock.lock();
    defer self.managed_windows_lock.unlock();
    var iterator = self.managed_windows;

    while (iterator) |managed_window| {
        if (self.layout_for(effective_layout_, managed_window)) |layout| {
            managed_window.prepare(layout);
            managed_window.show();
        } else {
            managed_window.hide();
        }

        iterator = managed_window.next;
    }
}
