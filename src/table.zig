//! Aligned text tables that account for double-width (CJK) characters.

const std = @import("std");
const Io = std.Io;

const gap = 2;

/// Writes `rows` as aligned columns. Every row must have the same number of cells.
pub fn write(w: *Io.Writer, gpa: std.mem.Allocator, rows: []const []const []const u8) !void {
    if (rows.len == 0) return;
    const widths = try gpa.alloc(usize, rows[0].len);
    defer gpa.free(widths);
    @memset(widths, 0);
    for (rows) |row| {
        for (row, widths) |cell, *width| width.* = @max(width.*, displayWidth(cell));
    }
    for (rows) |row| {
        for (row, widths, 0..) |cell, width, column| {
            try w.writeAll(cell);
            if (column + 1 != row.len) try w.splatByteAll(' ', width - displayWidth(cell) + gap);
        }
        try w.writeByte('\n');
    }
}

/// Returns how many terminal columns `text` occupies.
pub fn displayWidth(text: []const u8) usize {
    const view = std.unicode.Utf8View.init(text) catch return text.len;
    var codepoints = view.iterator();
    var width: usize = 0;
    while (codepoints.nextCodepoint()) |codepoint| width += if (isWide(codepoint)) 2 else 1;
    return width;
}

/// Reports whether a code point is rendered two columns wide.
fn isWide(codepoint: u21) bool {
    const ranges = [_][2]u21{
        .{ 0x1100, 0x115F }, .{ 0x2E80, 0xA4CF },   .{ 0xAC00, 0xD7A3 },
        .{ 0xF900, 0xFAFF }, .{ 0xFE30, 0xFE4F },   .{ 0xFF00, 0xFF60 },
        .{ 0xFFE0, 0xFFE6 }, .{ 0x1F300, 0x1FAFF }, .{ 0x20000, 0x3FFFD },
    };
    for (ranges) |range| {
        if (codepoint >= range[0] and codepoint <= range[1]) return true;
    }
    return false;
}

test "displayWidth counts CJK as two columns" {
    try std.testing.expectEqual(5, displayWidth("algo1"));
    try std.testing.expectEqual(8, displayWidth("レポート"));
    try std.testing.expectEqual(7, displayWidth("第1回 A"));
}

test "write pads by display width and leaves the last column ragged" {
    var out: Io.Writer.Allocating = .init(std.testing.allocator);
    defer out.deinit();
    try write(&out.writer, std.testing.allocator, &.{
        &.{ "SHORT", "SUBJECT", "TITLE" },
        &.{ "a", "数学", "x" },
    });

    try std.testing.expectEqualStrings(
        "SHORT  SUBJECT  TITLE\n" ++
            "a      数学     x\n",
        out.written(),
    );
}
