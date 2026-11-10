//! The `git` operations reportools performs on a project.

const Context = @import("Context.zig");
const proc = @import("proc.zig");

/// Turns `dir` into a repository whose first commit holds everything in it.
pub fn initialCommit(ctx: *const Context, dir: []const u8) !void {
    try proc.run(ctx, .{ .argv = &.{ "git", "init", "--quiet" }, .cwd = dir });
    try proc.run(ctx, .{ .argv = &.{ "git", "add", "--all" }, .cwd = dir });
    try proc.run(ctx, .{ .argv = &.{ "git", "commit", "--quiet", "--message", "Initial commit" }, .cwd = dir });
}

pub const FileStatus = enum { clean, dirty, no_repo };

/// Reports whether `file` differs from the last commit of the repository rooted at `dir`.
/// A directory that is not itself the top of a work tree counts as `no_repo`.
pub fn fileStatus(ctx: *const Context, dir: []const u8, file: []const u8) !FileStatus {
    const prefix = try proc.query(ctx, .{ .argv = &.{ "git", "rev-parse", "--show-prefix" }, .cwd = dir }) orelse
        return .no_repo;
    if (prefix.len != 0) return .no_repo;
    const changes = try proc.query(ctx, .{ .argv = &.{ "git", "status", "--porcelain", "--", file }, .cwd = dir }) orelse
        return .no_repo;
    return if (changes.len == 0) .clean else .dirty;
}

/// Commits `file` alone, leaving anything else that is staged untouched.
pub fn commitFile(ctx: *const Context, dir: []const u8, file: []const u8, message: []const u8) !void {
    try proc.run(ctx, .{ .argv = &.{ "git", "add", "--", file }, .cwd = dir });
    try proc.run(ctx, .{ .argv = &.{ "git", "commit", "--quiet", "--message", message, "--", file }, .cwd = dir });
}

/// Fetches and integrates upstream changes.
pub fn pull(ctx: *const Context, dir: []const u8) !void {
    try proc.run(ctx, .{ .argv = &.{ "git", "pull" }, .cwd = dir });
}

/// Publishes local commits upstream.
pub fn push(ctx: *const Context, dir: []const u8) !void {
    try proc.run(ctx, .{ .argv = &.{ "git", "push" }, .cwd = dir });
}
