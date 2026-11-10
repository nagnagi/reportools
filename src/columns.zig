//! Bridges column options (`--state`, `--deadline`, ...) and report fields.

const std = @import("std");
const Io = std.Io;
const args = @import("args.zig");
const Context = @import("Context.zig");
const report_mod = @import("report.zig");
const Field = report_mod.Field;

/// Every option that names a column.
pub const options = [_]args.Opt{ .short, .title, .subject, .deadline, .state, .style, .path };

/// Returns the option that names `field`.
pub fn optionOf(field: Field) args.Opt {
    return std.meta.stringToEnum(args.Opt, @tagName(field)).?;
}

/// Returns the columns chosen on the command line, in the order given.
pub fn selected(gpa: std.mem.Allocator, parsed: *const args.Parsed) ![]const Field {
    var fields: std.ArrayList(Field) = .empty;
    for (parsed.seen) |opt| {
        if (std.meta.stringToEnum(Field, @tagName(opt))) |field| try fields.append(gpa, field);
    }
    return fields.toOwnedSlice(gpa);
}

/// Copies the values given for `editable` fields into `report`. Returns whether any was given.
pub fn apply(ctx: *const Context, parsed: *const args.Parsed, report: *report_mod.Report, editable: []const Field) !bool {
    var changed = false;
    for (editable) |field| {
        const value = parsed.value(optionOf(field)) orelse continue;
        report.set(field, value) catch |e|
            return ctx.fail("{s}: {s}", .{ optionOf(field).names()[0], report_mod.explain(e) });
        changed = true;
    }
    return changed;
}

/// Writes one tab-separated line per entry holding the given fields.
pub fn writeRows(w: *Io.Writer, entries: []const report_mod.Entry, fields: []const Field) !void {
    for (entries) |*entry| {
        for (fields, 0..) |field, index| {
            if (index != 0) try w.writeByte('\t');
            try w.writeAll(entry.get(field));
        }
        try w.writeByte('\n');
    }
}
