//! Unit tests for `report.zig`.

const std = @import("std");
const report_mod = @import("../report.zig");
const Entry = report_mod.Entry;
const Report = report_mod.Report;
const State = report_mod.State;
const isValidShort = report_mod.isValidShort;

test "set validates each field" {
    var report: Report = .{ .short = "a" };

    try report.set(.state, "resub");
    try std.testing.expectEqual(State.resub, report.state);
    try report.set(.deadline, "2026-11-30 23:59");
    try report.set(.deadline, "");
    try report.set(.title, "第1回 レポート");

    try std.testing.expectError(error.InvalidState, report.set(.state, "done"));
    try std.testing.expectError(error.InvalidDeadline, report.set(.deadline, "2026-11-30"));
    try std.testing.expectError(error.InvalidText, report.set(.subject, "a\tb"));
    try std.testing.expectError(error.InvalidShort, report.set(.short, "a b"));
    try std.testing.expectError(error.InvalidStyle, report.set(.style, "word"));
    try std.testing.expectEqualStrings("a", report.short);
}

test "isValidShort accepts repository-safe names only" {
    try std.testing.expect(isValidShort("algo-1_v2.0"));
    try std.testing.expect(!isValidShort(""));
    try std.testing.expect(!isValidShort("-x"));
    try std.testing.expect(!isValidShort(".hidden"));
    try std.testing.expect(!isValidShort("a/b"));
    try std.testing.expect(!isValidShort("レポート"));
}

test "dueBefore sorts soonest first and undated last" {
    var entries = [_]Entry{
        .{ .report = .{ .short = "undated" }, .path = "" },
        .{ .report = .{ .short = "late", .deadline = "2026-12-01 09:00" }, .path = "" },
        .{ .report = .{ .short = "b", .deadline = "2026-11-01 09:00" }, .path = "" },
        .{ .report = .{ .short = "a", .deadline = "2026-11-01 09:00" }, .path = "" },
    };
    std.mem.sort(Entry, &entries, {}, Entry.dueBefore);

    const expected = [_][]const u8{ "a", "b", "late", "undated" };
    for (expected, entries) |short, entry| try std.testing.expectEqualStrings(short, entry.report.short);
}
