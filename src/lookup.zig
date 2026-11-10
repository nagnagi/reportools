//! Finds the reports a command should act on.

const std = @import("std");
const args = @import("args.zig");
const Context = @import("Context.zig");
const metafile = @import("metafile.zig");
const Registry = @import("registry.zig").Registry;
const Entry = @import("report.zig").Entry;

/// Returns the single optional `[short]` argument.
pub fn shortArg(ctx: *const Context, parsed: *const args.Parsed) !?[]const u8 {
    return switch (parsed.positionals.len) {
        0 => null,
        1 => parsed.positionals[0],
        else => ctx.fail("unexpected argument: {s}", .{parsed.positionals[1]}),
    };
}

/// Returns the report named `short`, or the one enclosing the working directory when `short` is null.
pub fn resolve(ctx: *const Context, registry: *const Registry, short: ?[]const u8) !Entry {
    const name = short orelse return enclosing(ctx);
    const item = registry.find(name) orelse return ctx.fail("{s}: no such report", .{name});
    const report = metafile.load(ctx, item.path) catch |e| switch (e) {
        error.MetafileNotFound => return ctx.fail(
            "{s}: no {s} in {s}\nif the project moved, run: reportools modify {s} --path <dir>",
            .{ name, metafile.name, item.path, name },
        ),
        else => return e,
    };
    return .{ .report = report, .path = item.path };
}

/// Loads every registered report, soonest deadline first. Unreadable ones are skipped with a warning.
pub fn loadAll(ctx: *const Context, registry: *const Registry) ![]Entry {
    var entries: std.ArrayList(Entry) = .empty;
    for (registry.items.items) |item| {
        const report = metafile.load(ctx, item.path) catch |e| switch (e) {
            error.MetafileNotFound => {
                ctx.warn("{s}: no {s} in {s}", .{ item.short, metafile.name, item.path });
                continue;
            },
            error.Reported => continue,
            else => return e,
        };
        try entries.append(ctx.arena, .{ .report = report, .path = item.path });
    }
    std.mem.sort(Entry, entries.items, {}, Entry.dueBefore);
    return entries.toOwnedSlice(ctx.arena);
}

/// Returns the report whose project contains the working directory.
fn enclosing(ctx: *const Context) !Entry {
    const root = try metafile.findRoot(ctx) orelse
        return ctx.fail("not inside a report project; pass <short>", .{});
    return .{ .report = try metafile.load(ctx, root), .path = root };
}
