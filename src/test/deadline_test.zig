//! Unit tests for `deadline.zig`.

const std = @import("std");
const isValid = @import("../deadline.zig").isValid;

test "isValid accepts well-formed deadlines" {
    try std.testing.expect(isValid("2026-11-30 23:59"));
    try std.testing.expect(isValid("2028-02-29 00:00"));
}

test "isValid rejects missing time, bad shape, and impossible dates" {
    try std.testing.expect(!isValid("2026-11-30"));
    try std.testing.expect(!isValid("2026-11-30T23:59"));
    try std.testing.expect(!isValid("2026/11/30 23:59"));
    try std.testing.expect(!isValid("2026-11-30 23:59:00"));
    try std.testing.expect(!isValid("2026-13-01 00:00"));
    try std.testing.expect(!isValid("2026-11-31 00:00"));
    try std.testing.expect(!isValid("2026-02-29 00:00"));
    try std.testing.expect(!isValid("2026-11-30 24:00"));
    try std.testing.expect(!isValid("2026-11-30 23:60"));
    try std.testing.expect(!isValid(""));
}
