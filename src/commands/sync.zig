const std = @import("std");
const args = @import("../args.zig");
const Context = @import("../Context.zig");
const files = @import("../files.zig");
const git = @import("../git.zig");
const lookup = @import("../lookup.zig");
const registry_mod = @import("../registry.zig");

pub const summary = "pull from and push to the upstream repository";
pub const usage =
    \\sync [short]
    \\sync --all
    \\
    \\Runs `git pull` and then `git push`. Nothing is committed.
;
pub const spec: args.Spec = .{ .flags = &.{.all} };

/// Synchronizes one report, or every registered report with `--all`.
pub fn run(ctx: *Context, parsed: args.Parsed) !void {
    const registry = try registry_mod.Registry.load(ctx);
    const short = try lookup.shortArg(ctx, &parsed);
    if (!parsed.has(.all)) {
        const entry = try lookup.resolve(ctx, &registry, short);
        return syncOne(ctx, .{ .short = entry.report.short, .path = entry.path });
    }
    if (short != null) return ctx.fail("--all takes no <short>", .{});

    var failures: usize = 0;
    for (registry.items.items) |item| {
        syncOne(ctx, item) catch |e| switch (e) {
            error.Reported => failures += 1,
            else => return e,
        };
    }
    if (failures != 0) return ctx.fail("{d} report(s) failed to sync", .{failures});
}

/// Pulls and pushes a single project.
fn syncOne(ctx: *Context, item: registry_mod.Item) !void {
    try ctx.out.print("==> {s}\n", .{item.short});
    if (!files.isDir(ctx, item.path)) return ctx.fail("{s}: {s} is not a directory", .{ item.short, item.path });
    try git.pull(ctx, item.path);
    try git.push(ctx, item.path);
}
