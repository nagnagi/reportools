//! Minimal ini reader and writer: `[section]` headers and `key = value` lines.

const std = @import("std");
const Io = std.Io;
const Allocator = std.mem.Allocator;

pub const Entry = struct {
    key: []const u8,
    value: []const u8,
};

pub const Section = struct {
    name: []const u8,
    entries: std.ArrayList(Entry) = .empty,
};

pub const ParseError = error{InvalidLine} || Allocator.Error;

pub const Document = struct {
    sections: std.ArrayList(Section) = .empty,

    /// Parses `text`, which the document borrows. On `InvalidLine`,
    /// `bad_line` holds the 1-based number of the offending line.
    pub fn parse(gpa: Allocator, text: []const u8, bad_line: *usize) ParseError!Document {
        var doc: Document = .{};
        var current: ?*Section = null;
        var lines = std.mem.splitScalar(u8, text, '\n');
        var number: usize = 0;
        while (lines.next()) |raw| {
            number += 1;
            bad_line.* = number;
            const line = std.mem.trim(u8, raw, " \t\r");
            if (line.len == 0 or line[0] == '#' or line[0] == ';') continue;
            if (line[0] == '[') {
                if (line[line.len - 1] != ']') return error.InvalidLine;
                current = try doc.section(gpa, std.mem.trim(u8, line[1 .. line.len - 1], " \t"));
                continue;
            }
            const key, const value = std.mem.cutScalar(u8, line, '=') orelse return error.InvalidLine;
            const target = current orelse return error.InvalidLine;
            try target.entries.append(gpa, .{
                .key = std.mem.trim(u8, key, " \t"),
                .value = std.mem.trim(u8, value, " \t"),
            });
        }
        return doc;
    }

    /// Returns the value of `key` in `section_name`, if present.
    pub fn get(doc: *const Document, section_name: []const u8, key: []const u8) ?[]const u8 {
        for (doc.sections.items) |*sec| {
            if (!std.mem.eql(u8, sec.name, section_name)) continue;
            for (sec.entries.items) |entry| {
                if (std.mem.eql(u8, entry.key, key)) return entry.value;
            }
        }
        return null;
    }

    /// Sets `key` in `section_name`, creating either as needed. The document borrows all three strings.
    pub fn set(doc: *Document, gpa: Allocator, section_name: []const u8, key: []const u8, value: []const u8) Allocator.Error!void {
        const sec = try doc.section(gpa, section_name);
        for (sec.entries.items) |*entry| {
            if (std.mem.eql(u8, entry.key, key)) {
                entry.value = value;
                return;
            }
        }
        try sec.entries.append(gpa, .{ .key = key, .value = value });
    }

    /// Writes the document in ini syntax.
    pub fn write(doc: *const Document, w: *Io.Writer) Io.Writer.Error!void {
        for (doc.sections.items, 0..) |sec, index| {
            if (index != 0) try w.writeByte('\n');
            try w.print("[{s}]\n", .{sec.name});
            for (sec.entries.items) |entry| try w.print("{s} = {s}\n", .{ entry.key, entry.value });
        }
    }

    /// Renders the document into a newly allocated string.
    pub fn render(doc: *const Document, gpa: Allocator) Allocator.Error![]u8 {
        var out: Io.Writer.Allocating = .init(gpa);
        errdefer out.deinit();
        doc.write(&out.writer) catch return error.OutOfMemory;
        return out.toOwnedSlice();
    }

    /// Returns the named section, appending it if missing.
    fn section(doc: *Document, gpa: Allocator, name: []const u8) Allocator.Error!*Section {
        for (doc.sections.items) |*sec| {
            if (std.mem.eql(u8, sec.name, name)) return sec;
        }
        try doc.sections.append(gpa, .{ .name = name });
        return &doc.sections.items[doc.sections.items.len - 1];
    }
};

/// Reports whether `value` survives a write and re-parse unchanged.
pub fn isSafeValue(value: []const u8) bool {
    for (value) |byte| {
        if (byte < 0x20 or byte == 0x7f) return false;
    }
    return std.mem.trim(u8, value, " ").len == value.len;
}
