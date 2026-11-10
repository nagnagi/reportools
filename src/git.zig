//! The `git` operations reportools performs on a project.

const Context = @import("Context.zig");
const proc = @import("proc.zig");

/// Turns `dir` into a repository whose first commit holds everything in it.
pub fn initialCommit(ctx: *const Context, dir: []const u8) !void {
    try proc.run(ctx, .{ .argv = &.{ "git", "init", "--quiet" }, .cwd = dir });
    try proc.run(ctx, .{ .argv = &.{ "git", "add", "--all" }, .cwd = dir });
    try proc.run(ctx, .{ .argv = &.{ "git", "commit", "--quiet", "--message", "Initial commit" }, .cwd = dir });
}

/// Fetches and integrates upstream changes.
pub fn pull(ctx: *const Context, dir: []const u8) !void {
    try proc.run(ctx, .{ .argv = &.{ "git", "pull" }, .cwd = dir });
}

/// Publishes local commits upstream.
pub fn push(ctx: *const Context, dir: []const u8) !void {
    try proc.run(ctx, .{ .argv = &.{ "git", "push" }, .cwd = dir });
}
