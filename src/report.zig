//! The report record and the rules its fields obey.

const std = @import("std");
const deadline = @import("deadline.zig");
const ini = @import("ini.zig");

pub const State = enum { draft, submit, resub, ok };

pub const Style = enum { typst, latex };

pub const Field = enum {
    short,
    title,
    subject,
    deadline,
    state,
    style,
    path,

    pub const all = std.enums.values(Field);
};

pub const SetError = error{
    InvalidShort,
    InvalidText,
    InvalidDeadline,
    InvalidState,
    InvalidStyle,
    NotStored,
};

pub const Report = struct {
    short: []const u8,
    title: []const u8 = "",
    subject: []const u8 = "",
    deadline: []const u8 = "",
    state: State = .draft,
    style: Style = .typst,

    /// Validates `value` and stores it in `field`. The report borrows `value`.
    pub fn set(self: *Report, field: Field, value: []const u8) SetError!void {
        switch (field) {
            .short => {
                if (!isValidShort(value)) return error.InvalidShort;
                self.short = value;
            },
            .title, .subject => {
                if (!ini.isSafeValue(value)) return error.InvalidText;
                if (field == .title) self.title = value else self.subject = value;
            },
            .deadline => {
                if (value.len != 0 and !deadline.isValid(value)) return error.InvalidDeadline;
                self.deadline = value;
            },
            .state => self.state = std.meta.stringToEnum(State, value) orelse return error.InvalidState,
            .style => self.style = std.meta.stringToEnum(Style, value) orelse return error.InvalidStyle,
            .path => return error.NotStored,
        }
    }
};

/// A report together with the directory it lives in.
pub const Entry = struct {
    report: Report,
    path: []const u8,

    /// Returns the text of `field`.
    pub fn get(self: *const Entry, field: Field) []const u8 {
        return switch (field) {
            .short => self.report.short,
            .title => self.report.title,
            .subject => self.report.subject,
            .deadline => self.report.deadline,
            .state => @tagName(self.report.state),
            .style => @tagName(self.report.style),
            .path => self.path,
        };
    }

    /// Orders entries by deadline, soonest first and undated last, then by short.
    pub fn dueBefore(_: void, a: Entry, b: Entry) bool {
        const a_dated = a.report.deadline.len != 0;
        const b_dated = b.report.deadline.len != 0;
        if (a_dated != b_dated) return a_dated;
        return switch (std.mem.order(u8, a.report.deadline, b.report.deadline)) {
            .lt => true,
            .gt => false,
            .eq => std.mem.lessThan(u8, a.report.short, b.report.short),
        };
    }
};

/// Reports whether `text` can name a report and its repository.
pub fn isValidShort(text: []const u8) bool {
    if (text.len == 0 or text[0] == '-' or text[0] == '.') return false;
    for (text) |byte| {
        if (!std.ascii.isAlphanumeric(byte) and std.mem.findScalar(u8, "._-", byte) == null) return false;
    }
    return true;
}

/// Explains a `SetError` for the user.
pub fn explain(err: SetError) []const u8 {
    return switch (err) {
        error.InvalidShort => "short may contain only letters, digits, '.', '_' and '-'",
        error.InvalidText => "text must be a single line without tabs or surrounding spaces",
        error.InvalidDeadline => "deadline must be \"" ++ deadline.format ++ "\"",
        error.InvalidState => "state must be one of: draft, submit, resub, ok",
        error.InvalidStyle => "style must be one of: typst, latex",
        error.NotStored => "path is not stored in the metafile",
    };
}

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
