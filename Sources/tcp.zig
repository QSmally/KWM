
const std = @import("std");

const Poke = @import("./Poke.zig");
const Runtime = @import("./Runtime.zig");
const wm = @import("./wm.zig");

const address = "0.0.0.0";
const port = 1025;
const maxBufferLen = 4096;

pub fn thread(runtime: *Runtime) void {
    const listen_address = std.net.Ip4Address.parse(address, port) catch unreachable;
    const localhost = std.net.Address { .in = listen_address };
    var server = localhost.listen(.{}) catch wm.die("failed to listen to {s}:{}", .{ address, port });
    defer server.deinit();

    wm.debug("{s}:{}: thread spawned with TCP listener", .{ address, port });

    while (runtime.is_running) {
        var connection = server.accept() catch |err| {
            wm.tell("error encountered whilst accepting connection: {}", .{ err });
            continue;
        };

        var connection_lifetime = std.heap.ArenaAllocator.init(runtime.allocator);

        defer {
            connection.stream.close();
            connection_lifetime.deinit();
            wm.tell("{}: connection stream closed", .{ connection.address });
        }

        wm.tell("{}: new connection", .{ connection.address });

        // currently only handles one connection at a time, synchronously
        on_connection(connection_lifetime.allocator(), runtime, &connection) catch |err| {
            wm.tell("{}: request error: {}", .{ connection.address, err });
        };
    }
}

fn on_connection(alloc: std.mem.Allocator, runtime: *Runtime, connection: *std.net.Server.Connection) !void {
    if (try connection.stream
        .reader()
        .readUntilDelimiterOrEofAlloc(alloc, '\n', maxBufferLen)
    ) |message| {
        wm.debug("{}: >>> {s}", .{ connection.address, message });

        const poke = try std.json.parseFromSliceLeaky(Poke, alloc, message, .{});

        // select new layout
        if (poke.layout_select) |layout| {
            wm.tell("{}: layout_select '{s}'", .{ connection.address, layout });
            try runtime.layout_select(layout);

            // rerender twice for good measure
            runtime.rerender();
            runtime.rerender();
        }
    }
}
