const std = @import("std");
const args = @import("../args.zig");
const columns = @import("../columns.zig");
const Context = @import("../Context.zig");
const lookup = @import("../lookup.zig");
const Registry = @import("../registry.zig").Registry;
const report_mod = @import("../report.zig");
const table = @import("../table.zig");

pub const summary = "show the details of one report";
pub const usage =
    \\at [short] [--<column>...]
    \\
    \\With columns, prints only their values, one per line.
    \\Columns: --short --title --subject --deadline --state --style --path
;
pub const spec: args.Spec = .{ .flags = &columns.options };

/// Prints every field of a report, or just the selected values.
pub fn run(ctx: *Context, parsed: args.Parsed) !void {
    const registry = try Registry.load(ctx);
    const entry = try lookup.resolve(ctx, &registry, try lookup.shortArg(ctx, &parsed));
    const fields = try columns.selected(ctx.arena, &parsed);
    if (fields.len != 0) {
        for (fields) |field| try ctx.out.print("{s}\n", .{entry.get(field)});
        return;
    }
    try writeAll(ctx, &entry);
}

/// Prints every field as an aligned `name value` pair.
fn writeAll(ctx: *Context, entry: *const report_mod.Entry) !void {
    var rows: [report_mod.Field.all.len][]const []const u8 = undefined;
    for (report_mod.Field.all, &rows) |field, *row| {
        const cells = try ctx.arena.alloc([]const u8, 2);
        cells[0] = @tagName(field);
        cells[1] = entry.get(field);
        row.* = cells;
    }
    try table.write(ctx.out, ctx.arena, &rows);
}
