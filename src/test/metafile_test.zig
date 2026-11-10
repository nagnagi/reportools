//! Unit tests for `metafile.zig`.

const std = @import("std");
const files = @import("../files.zig");
const Fixture = @import("Fixture.zig");
const metafile = @import("../metafile.zig");
const findRoot = metafile.findRoot;
const load = metafile.load;
const pathIn = metafile.pathIn;
const save = metafile.save;
const Report = @import("../report.zig").Report;

test "save then load round-trips every stored field" {
    const fx = try Fixture.init();
    defer fx.deinit();
    const original: Report = .{
        .short = "algo1",
        .title = "第1回 レポート",
        .subject = "アルゴリズム論",
        .deadline = "2026-11-30 23:59",
        .state = .resub,
        .style = .latex,
    };

    try save(&fx.ctx, fx.ctx.cwd, original);
    try std.testing.expectEqualDeep(original, try load(&fx.ctx, fx.ctx.cwd));
}

test "load distinguishes a missing metafile from a broken one" {
    const fx = try Fixture.init();
    defer fx.deinit();

    try std.testing.expectError(error.MetafileNotFound, load(&fx.ctx, fx.ctx.cwd));

    try files.write(&fx.ctx, try pathIn(&fx.ctx, fx.ctx.cwd), "[report]\nshort = a\nstate = done\n");
    try std.testing.expectError(error.Reported, load(&fx.ctx, fx.ctx.cwd));
    try std.testing.expect(std.mem.find(u8, try fx.takeErr(), "state must be one of") != null);
}

test "findRoot walks up from a subdirectory" {
    const fx = try Fixture.init();
    defer fx.deinit();
    const root = fx.ctx.cwd;

    try std.testing.expectEqual(null, try findRoot(&fx.ctx));

    try save(&fx.ctx, root, .{ .short = "a" });
    fx.ctx.cwd = try std.fs.path.join(fx.ctx.arena, &.{ root, "src", "resource" });
    try files.makeDir(&fx.ctx, fx.ctx.cwd);
    try std.testing.expectEqualStrings(root, (try findRoot(&fx.ctx)).?);
}
