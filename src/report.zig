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
