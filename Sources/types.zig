
const dwm = @cImport(@cInclude("dwm.h"));
const std = @import("std");

pub const Application = struct {

    const Self = @This();

    class: ?[]const u8 = null,
    instance: ?[]const u8 = null,
    title: ?[]const u8 = null,
    floating: bool = false,

    important: bool = false,

    pub fn rule(self: *const Self, tag: u5) dwm.Rule {
        return .{
            .class = @ptrCast(self.class),
            .instance = @ptrCast(self.instance),
            .title = @ptrCast(self.title),
            .tags = @as(c_uint, 1) << tag,
            .isfloating = (if (self.floating) 1 else 0),
            .monitor = -1 };
    }
};

pub const Layout = struct {

    const Self = @This();

    tag: u5 = 0,
    fallback: bool = false,
    applications: []const Application,

    pub fn init(layout: Layout, tag: u5) Layout {
        return .{
            .tag = tag,
            .fallback = layout.fallback,
            .applications = layout.applications };
    }

    pub fn rules(self: *const Self, alloc: std.mem.Allocator) ![]dwm.Rule {
        var dwm_rules = RuleList.init(alloc);
        for (self.applications) |application|
            try dwm_rules.append(application.rule(self.tag));
        return try dwm_rules.toOwnedSlice();
    }
};

pub const RuleList = std.ArrayList(dwm.Rule);
pub const LayoutList = std.StringArrayHashMap(Layout);
