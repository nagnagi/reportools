//! Unit tests for `table.zig`.

const std = @import("std");
const Io = std.Io;
const table = @import("../table.zig");
const displayWidth = table.displayWidth;
const write = table.write;

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
