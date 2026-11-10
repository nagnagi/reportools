//! Generates the directory layout of a new report project.

const std = @import("std");
const Context = @import("Context.zig");
const files = @import("files.zig");
const metafile = @import("metafile.zig");
const Report = @import("report.zig").Report;

pub const kept_dirs = [_][]const u8{
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
    pub fn path(plan: Plan, ctx: *const Context, relative: []const u8) ![]const u8 {
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
