//! Unit tests for `args.zig`.

const std = @import("std");
const args = @import("../args.zig");
const Opt = args.Opt;
const ParseError = args.ParseError;
const Parsed = args.Parsed;
const Spec = args.Spec;
const parse = args.parse;

const test_spec: Spec = .{ .flags = &.{ .all, .short, .title }, .values = &.{ .state, .deadline } };

/// Parses in a throwaway arena for tests.
fn parseForTest(arena: *std.heap.ArenaAllocator, spec: Spec, argv: []const []const u8) ParseError!Parsed {
    var culprit: []const u8 = "";
    return parse(arena.allocator(), spec, argv, &culprit);
}

test "long, short, inline and clustered forms are equivalent" {
    var arena: std.heap.ArenaAllocator = .init(std.testing.allocator);
    defer arena.deinit();
    const forms = [_][]const []const u8{
        &.{ "--state", "submit", "--all", "x" },
        &.{ "--state=submit", "-a", "x" },
        &.{ "x", "-s", "submit", "-a" },
        &.{ "-assubmit", "x" },
    };
    for (forms) |argv| {
        const parsed = try parseForTest(&arena, test_spec, argv);
        try std.testing.expectEqualStrings("submit", parsed.value(.state).?);
        try std.testing.expect(parsed.has(.all));
        try std.testing.expectEqual(1, parsed.positionals.len);
        try std.testing.expectEqualStrings("x", parsed.positionals[0]);
    }
}

test "aliases map to the same option and order of appearance is kept" {
    var arena: std.heap.ArenaAllocator = .init(std.testing.allocator);
    defer arena.deinit();
    const parsed = try parseForTest(&arena, test_spec, &.{ "--long", "--in", "2026-11-30 23:59", "-t", "--title" });

    try std.testing.expectEqualSlices(Opt, &.{ .title, .deadline, .short }, parsed.seen);
    try std.testing.expectEqualStrings("2026-11-30 23:59", parsed.value(.deadline).?);
}

test "double dash ends option parsing and help is always accepted" {
    var arena: std.heap.ArenaAllocator = .init(std.testing.allocator);
    defer arena.deinit();
    const parsed = try parseForTest(&arena, .{}, &.{ "--help", "--", "--all", "-" });

    try std.testing.expect(parsed.has(.help));
    try std.testing.expectEqual(2, parsed.positionals.len);
    try std.testing.expectEqualStrings("--all", parsed.positionals[0]);
}

test "malformed options are rejected" {
    var arena: std.heap.ArenaAllocator = .init(std.testing.allocator);
    defer arena.deinit();

    try std.testing.expectError(error.UnknownOption, parseForTest(&arena, test_spec, &.{"--nope"}));
    try std.testing.expectError(error.UnknownOption, parseForTest(&arena, test_spec, &.{"--path"}));
    try std.testing.expectError(error.UnknownOption, parseForTest(&arena, test_spec, &.{"-az"}));
    try std.testing.expectError(error.MissingValue, parseForTest(&arena, test_spec, &.{"--state"}));
    try std.testing.expectError(error.UnexpectedValue, parseForTest(&arena, test_spec, &.{"--all=yes"}));
}
