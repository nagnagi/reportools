const std = @import("std");
const args = @import("../args.zig");
const columns = @import("../columns.zig");
const Context = @import("../Context.zig");
const lookup = @import("../lookup.zig");
const Registry = @import("../registry.zig").Registry;
const Field = @import("../report.zig").Field;

pub const summary = "dump every report as TSV on standard output";
pub const usage = "export";
pub const spec: args.Spec = .{};

/// Prints a header line followed by one tab-separated line per report.
pub fn run(ctx: *Context, parsed: args.Parsed) !void {
    if (parsed.positionals.len != 0) return ctx.fail("unexpected argument: {s}", .{parsed.positionals[0]});
    const registry = try Registry.load(ctx);
    const entries = try lookup.loadAll(ctx, &registry);
    for (Field.all, 0..) |field, index| {
        if (index != 0) try ctx.out.writeByte('\t');
        try ctx.out.writeAll(@tagName(field));
    }
    try ctx.out.writeByte('\n');
    try columns.writeRows(ctx.out, entries, Field.all);
}
