//! Test-only context rooted in a temporary directory, with captured output.

const std = @import("std");
const Io = std.Io;
const Context = @import("Context.zig");

const Fixture = @This();

arena_state: std.heap.ArenaAllocator,
tmp: std.testing.TmpDir,
out: Io.Writer.Allocating,
err: Io.Writer.Allocating,
ctx: Context,

/// Creates a fixture whose home is `<tmp>/home` and working directory is `<tmp>/work`.
pub fn init() !*Fixture {
    const gpa = std.testing.allocator;
    const io = std.testing.io;
    const fx = try gpa.create(Fixture);
    errdefer gpa.destroy(fx);

    fx.arena_state = .init(gpa);
    errdefer fx.arena_state.deinit();
    const arena = fx.arena_state.allocator();

    fx.tmp = std.testing.tmpDir(.{});
    errdefer fx.tmp.cleanup();
    try fx.tmp.dir.createDirPath(io, "home");
    try fx.tmp.dir.createDirPath(io, "work");
    var buffer: [std.fs.max_path_bytes]u8 = undefined;
    const root = buffer[0..try fx.tmp.dir.realPath(io, &buffer)];

    fx.out = .init(arena);
    fx.err = .init(arena);
    fx.ctx = .{
        .arena = arena,
        .io = io,
        .out = &fx.out.writer,
        .err = &fx.err.writer,
        .home = try std.fs.path.join(arena, &.{ root, "home" }),
        .cwd = try std.fs.path.join(arena, &.{ root, "work" }),
    };
    return fx;
}

/// Removes the temporary directory and frees the fixture.
pub fn deinit(fx: *Fixture) void {
    fx.tmp.cleanup();
    fx.arena_state.deinit();
    std.testing.allocator.destroy(fx);
}

/// Returns what was written to stdout so far and clears it.
pub fn takeOut(fx: *Fixture) ![]const u8 {
    return fx.out.toOwnedSlice();
}

/// Returns what was written to stderr so far and clears it.
pub fn takeErr(fx: *Fixture) ![]const u8 {
    return fx.err.toOwnedSlice();
}
