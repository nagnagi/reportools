const std = @import("std");
const args = @import("../args.zig");
const columns = @import("../columns.zig");
const Config = @import("../config.zig").Config;
const Context = @import("../Context.zig");
const files = @import("../files.zig");
const metafile = @import("../metafile.zig");
const Registry = @import("../registry.zig").Registry;
const report_mod = @import("../report.zig");
const tracking = @import("../tracking.zig");

pub const summary = "register an existing report directory";
pub const usage =
    \\add [path] [--short <name>] [--title <text>] [--subject <text>]
    \\           [--deadline "YYYY-MM-DD HH:MM"] [--state <state>] [--style <latex|typst>]
    \\
    \\Uses the directory's .reportools, or creates one from the options.
    \\Without --short, a new .reportools takes the directory name.
;
pub const spec: args.Spec = .{ .values = &.{ .short, .title, .subject, .deadline, .state, .style } };

const editable = [_]report_mod.Field{ .short, .title, .subject, .deadline, .state, .style };

/// Registers a directory, writing its metafile when it is new or options change it.
pub fn run(ctx: *Context, parsed: args.Parsed) !void {
    if (parsed.positionals.len > 1) return ctx.fail("unexpected argument: {s}", .{parsed.positionals[1]});
    const root = try ctx.absolute(if (parsed.positionals.len == 1) parsed.positionals[0] else ".");
    if (!files.isDir(ctx, root)) return ctx.fail("{s} is not a directory", .{root});

    var is_new = false;
    var report = metafile.load(ctx, root) catch |e| switch (e) {
        error.MetafileNotFound => blk: {
            is_new = true;
            break :blk try fresh(ctx, root);
        },
        else => return e,
    };
    const changed = try columns.apply(ctx, &parsed, &report, &editable);
    if (report.short.len == 0) {
        return ctx.fail("cannot use the directory name as short; pass --short <name>", .{});
    }

    var registry = try Registry.load(ctx);
    try registry.register(ctx, .{ .short = report.short, .path = root });
    if (is_new or changed) try metafile.save(ctx, root, report);
    try ctx.out.print("added {s} in {s}\n", .{ report.short, root });
    try tracking.settle(ctx, root, "Add " ++ metafile.name, .warn);
}

/// Starts a record for a directory without a metafile; `short` stays empty if the name is unusable.
fn fresh(ctx: *Context, root: []const u8) !report_mod.Report {
    const config = try Config.load(ctx);
    const dir_name = std.fs.path.basename(root);
    return .{
        .short = if (report_mod.isValidShort(dir_name)) dir_name else "",
        .style = config.defaultStyle(),
    };
}
