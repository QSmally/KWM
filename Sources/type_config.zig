
const dwm = @cImport(@cInclude("dwm.h"));
const std = @import("std");

pub const Application = struct {

    class: ?[]const u8 = null,
    instance: ?[]const u8 = null,
    title: ?[]const u8 = null,
    floating: bool = false,
    important: bool = false,

    pub fn rule(self: @This(), tag: u5) dwm.Rule {
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

    tag: u5 = 0,
    fallback: bool = false,
    applications: []const Application,

    pub fn init(layout: Layout, tag: u5) Layout {
        return .{
            .tag = tag,
            .fallback = layout.fallback,
            .applications = layout.applications };
    }

    pub fn rules(self: @This(), allocator: std.mem.Allocator) ![]dwm.Rule {
        var dwm_rules = std.ArrayList(dwm.Rule).init(allocator);
        for (self.applications) |application|
            try dwm_rules.append(application.rule(self.tag));
        return dwm_rules.toOwnedSlice();
    }
};

pub const RuleList = std.ArrayList(dwm.Rule);
pub const LayoutList = std.StringArrayHashMap(Layout);

pub fn rules(allocator: std.mem.Allocator, layouts: LayoutList) ![]dwm.Rule {
    var rules_list = RuleList.init(allocator);

    for (layouts.values()) |layout| {
        const layout_rules = try layout.rules(allocator);
        try rules_list.appendSlice(layout_rules);
    }
    return try rules_list.toOwnedSlice();
}
