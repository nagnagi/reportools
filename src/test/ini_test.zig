//! Unit tests for `ini.zig`.

const std = @import("std");
const ini = @import("../ini.zig");
const Document = ini.Document;
const isSafeValue = ini.isSafeValue;

test "parse reads sections, trims, and skips comments" {
    var arena_state: std.heap.ArenaAllocator = .init(std.testing.allocator);
    defer arena_state.deinit();
    var line: usize = 0;
    const doc = try Document.parse(arena_state.allocator(),
        \\# comment
        \\[report]
        \\title =  第1回 レポート
        \\empty =
        \\
        \\[ other ]
        \\title = x = y
    , &line);

    try std.testing.expectEqualStrings("第1回 レポート", doc.get("report", "title").?);
    try std.testing.expectEqualStrings("", doc.get("report", "empty").?);
    try std.testing.expectEqualStrings("x = y", doc.get("other", "title").?);
    try std.testing.expectEqual(null, doc.get("report", "missing"));
}

test "parse reports the line of a malformed entry" {
    var arena_state: std.heap.ArenaAllocator = .init(std.testing.allocator);
    defer arena_state.deinit();
    var line: usize = 0;

    try std.testing.expectError(error.InvalidLine, Document.parse(arena_state.allocator(), "[a]\nk = v\nbroken\n", &line));
    try std.testing.expectEqual(3, line);
    try std.testing.expectError(error.InvalidLine, Document.parse(arena_state.allocator(), "k = v\n", &line));
    try std.testing.expectEqual(1, line);
}

test "set then render round-trips through parse" {
    var arena_state: std.heap.ArenaAllocator = .init(std.testing.allocator);
    defer arena_state.deinit();
    const arena = arena_state.allocator();
    var doc: Document = .{};
    try doc.set(arena, "a", "k", "old");
    try doc.set(arena, "b", "k", "2");
    try doc.set(arena, "a", "k", "new");

    const text = try doc.render(arena);
    try std.testing.expectEqualStrings("[a]\nk = new\n\n[b]\nk = 2\n", text);
    var line: usize = 0;
    const again = try Document.parse(arena, text, &line);
    try std.testing.expectEqualStrings("new", again.get("a", "k").?);
}

test "isSafeValue rejects values that would not round-trip" {
    try std.testing.expect(isSafeValue("plain 値"));
    try std.testing.expect(isSafeValue(""));
    try std.testing.expect(!isSafeValue("two\nlines"));
    try std.testing.expect(!isSafeValue("tab\there"));
    try std.testing.expect(!isSafeValue(" padded"));
}
