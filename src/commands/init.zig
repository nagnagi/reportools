const std = @import("std");
const args = @import("../args.zig");
const columns = @import("../columns.zig");
const Config = @import("../config.zig").Config;
const Context = @import("../Context.zig");
const files = @import("../files.zig");
const git = @import("../git.zig");
const github = @import("../github.zig");
const Registry = @import("../registry.zig").Registry;
const report_mod = @import("../report.zig");
const scaffold = @import("../scaffold.zig");

pub const summary = "create a report project and its private repository";
pub const usage =
    \\init <short> [--style <latex|typst>] [--title <text>] [--subject <text>]
    \\             [--deadline "YYYY-MM-DD HH:MM"]
    \\
    \\Creates ./<short>, commits it, registers it, then creates the private
    \\repository <user>/<short> and pushes. Requires release.title to be set.
;
pub const spec: args.Spec = .{ .values = &.{ .style, .title, .subject, .deadline } };

const title_unset =
    \\release.title is not set
    \\
    \\Set the file name of the released PDF (without ".pdf") first:
    \\
    \\    reportools config release.title <name>
;

/// Scaffolds, commits, registers and publishes a new report project.
pub fn run(ctx: *Context, parsed: args.Parsed) !void {
    const config = try Config.load(ctx);
    const release_title = config.get(.release_title) orelse return ctx.fail(title_unset, .{});
    const report = try describe(ctx, &parsed, &config);

    var registry = try Registry.load(ctx);
    if (registry.find(report.short)) |item| {
        return ctx.fail("{s} is already registered at {s}", .{ item.short, item.path });
    }
    const root = try ctx.absolute(report.short);
    if (files.exists(ctx, root)) return ctx.fail("{s} already exists", .{root});
    const repo: github.Repo = .{ .owner = try github.resolveUser(ctx, &config), .name = report.short };

    try scaffold.create(ctx, .{ .root = root, .report = report, .release_title = release_title });
    try git.initialCommit(ctx, root);
    try registry.register(ctx, .{ .short = report.short, .path = root });
    github.createPrivate(ctx, repo, root) catch |e| {
        ctx.warn("{s} is ready and registered locally, but was not published", .{root});
        return e;
    };
    try ctx.out.print("initialized {s} in {s}\n", .{ report.short, root });
}

/// Builds the report record from the command line.
fn describe(ctx: *Context, parsed: *const args.Parsed, config: *const Config) !report_mod.Report {
    if (parsed.positionals.len != 1) return ctx.fail("init takes exactly one <short>", .{});
    var report: report_mod.Report = .{ .short = "", .style = config.defaultStyle() };
    report.set(.short, parsed.positionals[0]) catch |e|
        return ctx.fail("{s}: {s}", .{ parsed.positionals[0], report_mod.explain(e) });
    _ = try columns.apply(ctx, parsed, &report, &.{ .style, .title, .subject, .deadline });
    return report;
}
