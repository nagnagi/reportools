//! Whole-file helpers on absolute paths.

const std = @import("std");
const Io = std.Io;
const Context = @import("Context.zig");

const max_size: Io.Limit = .limited(1 << 20);

/// Reads a file, or returns null if it does not exist.
pub fn read(ctx: *const Context, path: []const u8) !?[]const u8 {
    return Io.Dir.cwd().readFileAlloc(ctx.io, path, ctx.arena, max_size) catch |e| switch (e) {
        error.FileNotFound => null,
        else => e,
    };
}

/// Writes a file, creating parent directories as needed.
pub fn write(ctx: *const Context, path: []const u8, data: []const u8) !void {
    try makeParent(ctx, path);
    try Io.Dir.cwd().writeFile(ctx.io, .{ .sub_path = path, .data = data });
}

/// Replaces a file through a temporary sibling, so a crash never leaves it half written.
pub fn replace(ctx: *const Context, path: []const u8, data: []const u8) !void {
    const tmp = try std.fmt.allocPrint(ctx.arena, "{s}.tmp", .{path});
    try write(ctx, tmp, data);
    try Io.Dir.renameAbsolute(tmp, path, ctx.io);
}

/// Reports whether anything exists at `path`.
pub fn exists(ctx: *const Context, path: []const u8) bool {
    Io.Dir.cwd().access(ctx.io, path, .{}) catch return false;
    return true;
}

/// Reports whether `path` is a directory.
pub fn isDir(ctx: *const Context, path: []const u8) bool {
    var dir = Io.Dir.cwd().openDir(ctx.io, path, .{}) catch return false;
    dir.close(ctx.io);
    return true;
}

/// Creates a directory and its missing parents.
pub fn makeDir(ctx: *const Context, path: []const u8) !void {
    try Io.Dir.cwd().createDirPath(ctx.io, path);
}

/// Creates the directory that will contain `path`.
fn makeParent(ctx: *const Context, path: []const u8) !void {
    if (std.fs.path.dirname(path)) |parent| try makeDir(ctx, parent);
}
