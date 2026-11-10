//! Unit tests for `registry.zig`.

const std = @import("std");
const Fixture = @import("Fixture.zig");
const Registry = @import("../registry.zig").Registry;

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
