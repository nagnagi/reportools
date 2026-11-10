const std = @import("std");
const args = @import("../args.zig");
const Context = @import("../Context.zig");
const lookup = @import("../lookup.zig");
const Registry = @import("../registry.zig").Registry;

pub const summary = "forget a report (its files and repository are kept)";
pub const usage = "remove [short]";
pub const spec: args.Spec = .{};

/// Drops a report from the path list without touching its directory.
pub fn run(ctx: *Context, parsed: args.Parsed) !void {
    var registry = try Registry.load(ctx);
    const short = try lookup.shortArg(ctx, &parsed) orelse
        (try lookup.resolve(ctx, &registry, null)).report.short;
    const item = registry.find(short) orelse return ctx.fail("{s}: no such report", .{short});
    const path = item.path;
    _ = registry.remove(short);
    try registry.save(ctx);
    try ctx.out.print("removed {s} from the list; files are kept in {s}\n", .{ short, path });
}
