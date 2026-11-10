//! Runtime shared by every command: allocator, I/O handles and base paths.

const std = @import("std");
const Io = std.Io;

const Context = @This();

/// Lives until the process exits; nothing allocated from it is freed earlier.
arena: std.mem.Allocator,
io: Io,
out: *Io.Writer,
err: *Io.Writer,
home: []const u8,
cwd: []const u8,

/// Prints an error message to stderr and returns `error.Reported`.
pub fn fail(ctx: *const Context, comptime fmt: []const u8, args: anytype) error{Reported} {
    ctx.err.print("reportools: " ++ fmt ++ "\n", args) catch {};
    return error.Reported;
}

/// Prints a warning to stderr.
pub fn warn(ctx: *const Context, comptime fmt: []const u8, args: anytype) void {
    ctx.err.print("reportools: warning: " ++ fmt ++ "\n", args) catch {};
}

/// Returns the path of the config file.
pub fn configPath(ctx: *const Context) ![]const u8 {
    return std.fs.path.join(ctx.arena, &.{ ctx.home, ".config", "reportools", "config.ini" });
}

/// Returns the path of the path list.
pub fn registryPath(ctx: *const Context) ![]const u8 {
    return std.fs.path.join(ctx.arena, &.{ ctx.home, ".local", "share", "reportools", "reports.tsv" });
}

/// Resolves `path` against the working directory into a normalized absolute path.
pub fn absolute(ctx: *const Context, path: []const u8) ![]const u8 {
    return std.fs.path.resolveAlloc(ctx.arena, &.{ ctx.cwd, path });
}
