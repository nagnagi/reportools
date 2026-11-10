//! The path list: which report lives in which directory on this machine.

const std = @import("std");
const Io = std.Io;
const Allocator = std.mem.Allocator;
const Context = @import("Context.zig");
const files = @import("files.zig");

pub const Item = struct {
    short: []const u8,
    path: []const u8,
};

pub const Registry = struct {
    items: std.ArrayList(Item) = .empty,

    /// Parses the tab-separated path list, which the registry borrows.
    pub fn parse(gpa: Allocator, text: []const u8) Allocator.Error!Registry {
        var registry: Registry = .{};
        var lines = std.mem.tokenizeScalar(u8, text, '\n');
        while (lines.next()) |line| {
            const short, const path = std.mem.cutScalar(u8, line, '\t') orelse continue;
            try registry.items.append(gpa, .{ .short = short, .path = path });
        }
        return registry;
    }

    /// Returns the item registered under `short`.
    pub fn find(self: *const Registry, short: []const u8) ?*Item {
        for (self.items.items) |*item| {
            if (std.mem.eql(u8, item.short, short)) return item;
        }
        return null;
    }

    /// Registers a new item. Fails if `short` already points at another directory.
    pub fn add(self: *Registry, gpa: Allocator, item: Item) (error{AlreadyRegistered} || Allocator.Error)!void {
        if (self.find(item.short)) |existing| {
            if (std.mem.eql(u8, existing.path, item.path)) return;
            return error.AlreadyRegistered;
        }
        try self.items.append(gpa, item);
    }

    /// Registers `item` and saves the list, reporting a conflicting registration to the user.
    pub fn register(self: *Registry, ctx: *const Context, item: Item) !void {
        self.add(ctx.arena, item) catch |e| switch (e) {
            error.AlreadyRegistered => return ctx.fail(
                "{s} is already registered at {s}",
                .{ item.short, self.find(item.short).?.path },
            ),
            error.OutOfMemory => return e,
        };
        try self.save(ctx);
    }

    /// Unregisters `short`. Returns false if it was not registered.
    pub fn remove(self: *Registry, short: []const u8) bool {
        for (self.items.items, 0..) |item, index| {
            if (!std.mem.eql(u8, item.short, short)) continue;
            _ = self.items.orderedRemove(index);
            return true;
        }
        return false;
    }

    /// Loads the path list; a missing file is an empty list.
    pub fn load(ctx: *const Context) !Registry {
        const text = try files.read(ctx, try ctx.registryPath()) orelse return .{};
        return parse(ctx.arena, text);
    }

    /// Writes the path list back to disk.
    pub fn save(self: *const Registry, ctx: *const Context) !void {
        var out: Io.Writer.Allocating = .init(ctx.arena);
        for (self.items.items) |item| try out.writer.print("{s}\t{s}\n", .{ item.short, item.path });
        try files.replace(ctx, try ctx.registryPath(), out.written());
    }
};

const Fixture = @import("Fixture.zig");

test "add rejects a short that points elsewhere but tolerates a repeat" {
    var arena_state: std.heap.ArenaAllocator = .init(std.testing.allocator);
    defer arena_state.deinit();
    const arena = arena_state.allocator();
    var registry: Registry = .{};

    try registry.add(arena, .{ .short = "a", .path = "/x" });
    try registry.add(arena, .{ .short = "a", .path = "/x" });
    try std.testing.expectError(error.AlreadyRegistered, registry.add(arena, .{ .short = "a", .path = "/y" }));
    try std.testing.expectEqual(1, registry.items.items.len);
}

test "remove reports whether the short was registered" {
    var arena_state: std.heap.ArenaAllocator = .init(std.testing.allocator);
    defer arena_state.deinit();
    var registry = try Registry.parse(arena_state.allocator(), "a\t/x\nb\t/y\n");

    try std.testing.expect(registry.remove("a"));
    try std.testing.expect(!registry.remove("a"));
    try std.testing.expectEqualStrings("/y", registry.find("b").?.path);
}

test "save then load round-trips, and a missing file is empty" {
    const fx = try Fixture.init();
    defer fx.deinit();

    var registry = try Registry.load(&fx.ctx);
    try std.testing.expectEqual(0, registry.items.items.len);

    try registry.add(fx.ctx.arena, .{ .short = "a", .path = "/dir with space/a" });
    try registry.save(&fx.ctx);
    const again = try Registry.load(&fx.ctx);
    try std.testing.expectEqualStrings("/dir with space/a", again.find("a").?.path);
}
