const std = @import("std");
const args = @import("../args.zig");
const columns = @import("../columns.zig");
const Context = @import("../Context.zig");
const lookup = @import("../lookup.zig");
const metafile = @import("../metafile.zig");
const Registry = @import("../registry.zig").Registry;
const Field = @import("../report.zig").Field;

pub const summary = "update the details or state of a report";
pub const usage =
    \\modify [short] [--state <draft|submit|resub|ok>] [--title <text>] [--subject <text>]
    \\               [--deadline "YYYY-MM-DD HH:MM"] [--path <dir>]
    \\
    \\Rewrites .reportools without committing. --path only updates where the
    \\project is found on this machine.
;
pub const spec: args.Spec = .{ .values = &.{ .short, .title, .subject, .deadline, .state, .path } };

const editable = [_]Field{ .title, .subject, .deadline, .state };

/// Applies the given values to a report's metafile and, for `--path`, to the path list.
pub fn run(ctx: *Context, parsed: args.Parsed) !void {
    if (parsed.has(.short)) return ctx.fail("short cannot be changed: it names the repository", .{});
    var registry = try Registry.load(ctx);
    const short = try lookup.shortArg(ctx, &parsed);
    if (parsed.value(.path)) |path| try relocate(ctx, &registry, short, path);

    var entry = try lookup.resolve(ctx, &registry, short);
    if (try columns.apply(ctx, &parsed, &entry.report, &editable)) {
        try metafile.save(ctx, entry.path, entry.report);
    } else if (!parsed.has(.path)) {
        return ctx.fail("nothing to modify; see `reportools modify --help`", .{});
    }
}

/// Points the path list entry of a report at the directory it was moved to.
fn relocate(ctx: *Context, registry: *Registry, short: ?[]const u8, path: []const u8) !void {
    const name = short orelse (try lookup.resolve(ctx, registry, null)).report.short;
    const item = registry.find(name) orelse return ctx.fail("{s}: no such report", .{name});
    const root = try ctx.absolute(path);
    _ = metafile.load(ctx, root) catch |e| switch (e) {
        error.MetafileNotFound => return ctx.fail("{s}: no {s} there", .{ root, metafile.name }),
        else => return e,
    };
    item.path = root;
    try registry.save(ctx);
}
