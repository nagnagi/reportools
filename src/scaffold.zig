//! Generates the directory layout of a new report project.

const std = @import("std");
const Context = @import("Context.zig");
const files = @import("files.zig");
const metafile = @import("metafile.zig");
const Report = @import("report.zig").Report;

const kept_dirs = [_][]const u8{
    "complete",
    "reference",
    "src/resource/code",
    "src/resource/img",
    "src/resource/title",
};

const typst_makefile = @embedFile("templates/typst/Makefile");
const typst_main = @embedFile("templates/typst/main.typ");

pub const Plan = struct {
    /// Absolute path of the project directory to create.
    root: []const u8,
    report: Report,
    /// File name of the released PDF, without extension.
    release_title: []const u8,

    /// Returns the absolute path of a file inside the project.
    fn path(plan: Plan, ctx: *const Context, relative: []const u8) ![]const u8 {
        return std.fs.path.join(ctx.arena, &.{ plan.root, relative });
    }
};

/// Creates the project described by `plan`, including its metafile.
pub fn create(ctx: *const Context, plan: Plan) !void {
    for (kept_dirs) |dir| {
        const keep = try std.fs.path.join(ctx.arena, &.{ dir, ".gitkeep" });
        try files.write(ctx, try plan.path(ctx, keep), "");
    }
    try files.write(ctx, try plan.path(ctx, "src/main.bib"), "");
    try files.write(ctx, try plan.path(ctx, ".gitignore"), try gitignore(ctx, plan));
    switch (plan.report.style) {
        .typst => {
            try files.write(ctx, try plan.path(ctx, "src/main.typ"), typst_main);
            try files.write(ctx, try plan.path(ctx, "Makefile"), try makefile(ctx, plan));
        },
        .latex => try files.write(ctx, try plan.path(ctx, "src/main.tex"), ""),
    }
    try metafile.save(ctx, plan.root, plan.report);
}

/// Renders the ignore list for build products.
fn gitignore(ctx: *const Context, plan: Plan) ![]const u8 {
    return std.fmt.allocPrint(ctx.arena, "main.pdf\ncomplete/{s}.pdf\n", .{plan.release_title});
}

/// Renders the Typst Makefile with the release title filled in.
fn makefile(ctx: *const Context, plan: Plan) ![]const u8 {
    return std.mem.replaceOwned(u8, ctx.arena, typst_makefile, "@TITLE@", plan.release_title);
}

const Fixture = @import("Fixture.zig");

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
