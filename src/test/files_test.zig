//! Unit tests for `files.zig`.

const std = @import("std");
const files = @import("../files.zig");
const isDir = files.isDir;
const read = files.read;
const replace = files.replace;
const Fixture = @import("Fixture.zig");

test "replace then read round-trips and creates parents" {
    const fx = try Fixture.init();
    defer fx.deinit();
    const path = try std.fs.path.join(fx.ctx.arena, &.{ fx.ctx.home, "a", "b", "file" });

    try std.testing.expectEqual(null, try read(&fx.ctx, path));
    try replace(&fx.ctx, path, "one");
    try replace(&fx.ctx, path, "two");
    try std.testing.expectEqualStrings("two", (try read(&fx.ctx, path)).?);
    try std.testing.expect(isDir(&fx.ctx, std.fs.path.dirname(path).?));
    try std.testing.expect(!isDir(&fx.ctx, path));
}
