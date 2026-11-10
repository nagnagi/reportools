//! Unit tests for `scaffold.zig`.

const std = @import("std");
const files = @import("../files.zig");
const Fixture = @import("Fixture.zig");
const metafile = @import("../metafile.zig");
const scaffold = @import("../scaffold.zig");
const Plan = scaffold.Plan;
const create = scaffold.create;
const kept_dirs = scaffold.kept_dirs;

/// Reads a project file that the test expects to exist.
fn readExpected(fx: *Fixture, plan: Plan, relative: []const u8) ![]const u8 {
    return try files.read(&fx.ctx, try plan.path(&fx.ctx, relative)) orelse error.TestExpectedFile;
}

test "typst project has the documented layout and a titled Makefile" {
    const fx = try Fixture.init();
    defer fx.deinit();
    const plan: Plan = .{
        .root = try fx.ctx.absolute("algo1"),
        .report = .{ .short = "algo1", .style = .typst },
        .release_title = "12345_name",
    };
    try create(&fx.ctx, plan);

    for (kept_dirs) |dir| {
        try std.testing.expect(files.exists(&fx.ctx, try plan.path(&fx.ctx, try std.fs.path.join(fx.ctx.arena, &.{ dir, ".gitkeep" }))));
    }
    try std.testing.expectEqualStrings("main.pdf\ncomplete/12345_name.pdf\n", try readExpected(fx, plan, ".gitignore"));
    try std.testing.expectEqualStrings("", try readExpected(fx, plan, "src/main.bib"));
    try std.testing.expect((try readExpected(fx, plan, "src/main.typ")).len != 0);

    const rendered = try readExpected(fx, plan, "Makefile");
    try std.testing.expect(std.mem.find(u8, rendered, "\nTITLE := 12345_name.pdf\n") != null);
    try std.testing.expect(std.mem.find(u8, rendered, "@TITLE@") == null);
    try std.testing.expect(std.mem.find(u8, rendered, "\n\tcp $(TARGET) complete/$(TITLE)\n") != null);

    try std.testing.expect(!files.exists(&fx.ctx, try plan.path(&fx.ctx, ".version")));
    try std.testing.expectEqualStrings("algo1", (try metafile.load(&fx.ctx, plan.root)).short);
}

test "latex project has the same layout without a Makefile" {
    const fx = try Fixture.init();
    defer fx.deinit();
    const plan: Plan = .{
        .root = try fx.ctx.absolute("tex1"),
        .report = .{ .short = "tex1", .style = .latex },
        .release_title = "t",
    };
    try create(&fx.ctx, plan);

    try std.testing.expect(files.exists(&fx.ctx, try plan.path(&fx.ctx, "src/main.tex")));
    try std.testing.expect(files.exists(&fx.ctx, try plan.path(&fx.ctx, "src/resource/img/.gitkeep")));
    try std.testing.expect(!files.exists(&fx.ctx, try plan.path(&fx.ctx, "src/main.typ")));
    try std.testing.expect(!files.exists(&fx.ctx, try plan.path(&fx.ctx, "Makefile")));
}
