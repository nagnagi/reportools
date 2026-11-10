const std = @import("std");
const args = @import("../args.zig");
const columns = @import("../columns.zig");
const Context = @import("../Context.zig");
const lookup = @import("../lookup.zig");
const Registry = @import("../registry.zig").Registry;
const Entry = @import("../report.zig").Entry;
const Field = @import("../report.zig").Field;
const table = @import("../table.zig");

pub const summary = "show every report, soonest deadline first";
pub const usage =
    \\list [--<column>...]
    \\
    \\With columns, prints only those columns, tab-separated and without a header.
    \\Columns: --short --title --subject --deadline --state --style --path
;
pub const spec: args.Spec = .{ .flags = &columns.options };

const table_fields = [_]Field{ .short, .subject, .deadline, .state, .title };

/// Prints the reports as a table, or as raw columns when any are selected.
pub fn run(ctx: *Context, parsed: args.Parsed) !void {
    if (parsed.positionals.len != 0) return ctx.fail("unexpected argument: {s}", .{parsed.positionals[0]});
    const registry = try Registry.load(ctx);
    const entries = try lookup.loadAll(ctx, &registry);
    const fields = try columns.selected(ctx.arena, &parsed);
    if (fields.len != 0) return columns.writeRows(ctx.out, entries, fields);
    if (entries.len != 0) try writeTable(ctx, entries);
}

/// Prints an aligned table with a header row.
fn writeTable(ctx: *Context, entries: []const Entry) !void {
    const rows = try ctx.arena.alloc([]const []const u8, entries.len + 1);
    rows[0] = &.{ "SHORT", "SUBJECT", "DEADLINE", "STATE", "TITLE" };
    for (entries, rows[1..]) |*entry, *row| {
        const cells = try ctx.arena.alloc([]const u8, table_fields.len);
        for (table_fields, cells) |field, *cell| cell.* = entry.get(field);
        row.* = cells;
    }
    try table.write(ctx.out, ctx.arena, rows);
}
