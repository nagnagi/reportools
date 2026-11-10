//! Reads and writes `.reportools`, the per-project record of a report.

const std = @import("std");
const Context = @import("Context.zig");
const files = @import("files.zig");
const ini = @import("ini.zig");
const report_mod = @import("report.zig");
const Report = report_mod.Report;
const Field = report_mod.Field;

pub const name = ".reportools";

const section = "report";
const stored = [_]Field{ .short, .title, .subject, .deadline, .state, .style };

/// Loads the report recorded in `dir`. Returns `error.MetafileNotFound` if there is none.
pub fn load(ctx: *const Context, dir: []const u8) !Report {
    const path = try pathIn(ctx, dir);
    const text = try files.read(ctx, path) orelse return error.MetafileNotFound;
    var line: usize = 0;
    const doc = ini.Document.parse(ctx.arena, text, &line) catch |e| switch (e) {
        error.InvalidLine => return ctx.fail("{s}:{d}: not a valid ini line", .{ path, line }),
        error.OutOfMemory => return e,
    };

    var report: Report = .{ .short = "" };
    for (stored) |field| {
        const value = doc.get(section, @tagName(field)) orelse continue;
        report.set(field, value) catch |e|
            return ctx.fail("{s}: {s}: {s}", .{ path, @tagName(field), report_mod.explain(e) });
    }
    if (report.short.len == 0) return ctx.fail("{s}: short is missing", .{path});
    return report;
}

/// Writes `report` into `dir`.
pub fn save(ctx: *const Context, dir: []const u8, report: Report) !void {
    const entry: report_mod.Entry = .{ .report = report, .path = dir };
    var doc: ini.Document = .{};
    for (stored) |field| try doc.set(ctx.arena, section, @tagName(field), entry.get(field));
    try files.replace(ctx, try pathIn(ctx, dir), try doc.render(ctx.arena));
}

/// Returns the nearest directory at or above the working directory that holds a metafile.
pub fn findRoot(ctx: *const Context) !?[]const u8 {
    var dir: ?[]const u8 = ctx.cwd;
    while (dir) |candidate| : (dir = std.fs.path.dirname(candidate)) {
        if (files.exists(ctx, try pathIn(ctx, candidate))) return candidate;
    }
    return null;
}

/// Returns the metafile path inside `dir`.
pub fn pathIn(ctx: *const Context, dir: []const u8) ![]const u8 {
    return std.fs.path.join(ctx.arena, &.{ dir, name });
}
