//! Unit tests for `proc.zig`.

const std = @import("std");
const Fixture = @import("Fixture.zig");
const proc = @import("../proc.zig");
const capture = proc.capture;
const query = proc.query;
const run = proc.run;

test "capture trims output and honors the working directory" {
    const fx = try Fixture.init();
    defer fx.deinit();

    const output = try capture(&fx.ctx, .{ .argv = &.{ "sh", "-c", "pwd" }, .cwd = fx.ctx.cwd });
    try std.testing.expectEqualStrings(fx.ctx.cwd, output);
}

test "a non-zero exit and a missing program are reported" {
    const fx = try Fixture.init();
    defer fx.deinit();

    try std.testing.expectError(error.Reported, capture(&fx.ctx, .{ .argv = &.{ "sh", "-c", "echo why >&2; exit 3" } }));
    try std.testing.expect(std.mem.find(u8, try fx.takeErr(), "why") != null);
    try std.testing.expectEqual(null, try query(&fx.ctx, .{ .argv = &.{ "sh", "-c", "echo out; exit 3" } }));
    try std.testing.expectEqualStrings("out", (try query(&fx.ctx, .{ .argv = &.{ "sh", "-c", "echo out" } })).?);
    try std.testing.expectEqualStrings("", try fx.takeErr());
    try std.testing.expectError(error.Reported, run(&fx.ctx, .{ .argv = &.{"reportools-no-such-program"} }));
    try std.testing.expect(std.mem.find(u8, try fx.takeErr(), "command not found") != null);
}
