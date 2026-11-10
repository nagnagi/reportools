const std = @import("std");
const args = @import("../args.zig");
const Context = @import("../Context.zig");
const lookup = @import("../lookup.zig");
const metafile = @import("../metafile.zig");
const Registry = @import("../registry.zig").Registry;

pub const summary = "mark a report as finished";
pub const usage =
    \\ok [short]
    \\
    \\Same as `modify [short] --state ok`.
;
pub const spec: args.Spec = .{};

/// Sets the state of a report to `ok` in its metafile.
pub fn run(ctx: *Context, parsed: args.Parsed) !void {
    const registry = try Registry.load(ctx);
    var entry = try lookup.resolve(ctx, &registry, try lookup.shortArg(ctx, &parsed));
    entry.report.state = .ok;
    try metafile.save(ctx, entry.path, entry.report);
}
