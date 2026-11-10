//! Runs external programs such as `git` and `gh`.

const std = @import("std");
const Context = @import("Context.zig");

pub const Command = struct {
    argv: []const []const u8,
    cwd: ?[]const u8 = null,

    /// Renders the command line for messages.
    fn text(cmd: Command, ctx: *const Context) ![]const u8 {
        return std.mem.join(ctx.arena, " ", cmd.argv);
    }

    /// Maps the optional directory onto the spawn option.
    fn childCwd(cmd: Command) std.process.Child.Cwd {
        return if (cmd.cwd) |path| .{ .path = path } else .inherit;
    }
};

/// Runs a command attached to the terminal and fails if it does not exit with 0.
pub fn run(ctx: *const Context, cmd: Command) !void {
    try ctx.out.flush();
    var child = std.process.spawn(ctx.io, .{ .argv = cmd.argv, .cwd = cmd.childCwd() }) catch |e|
        return spawnFailure(ctx, cmd, e);
    const term = try child.wait(ctx.io);
    if (!term.success()) return ctx.fail("command failed: {s}", .{try cmd.text(ctx)});
}

/// Runs a command and returns its standard output without surrounding whitespace.
pub fn capture(ctx: *const Context, cmd: Command) ![]const u8 {
    const result = try collect(ctx, cmd);
    if (!result.term.success()) {
        const reason = std.mem.trim(u8, result.stderr, " \t\r\n");
        return ctx.fail("command failed: {s}\n{s}", .{ try cmd.text(ctx), reason });
    }
    return std.mem.trim(u8, result.stdout, " \t\r\n");
}

/// Like `capture`, but a non-zero exit yields null instead of an error message.
pub fn query(ctx: *const Context, cmd: Command) !?[]const u8 {
    const result = try collect(ctx, cmd);
    if (!result.term.success()) return null;
    return std.mem.trim(u8, result.stdout, " \t\r\n");
}

/// Runs a command to completion with its output captured.
fn collect(ctx: *const Context, cmd: Command) !std.process.RunResult {
    return std.process.run(ctx.arena, ctx.io, .{ .argv = cmd.argv, .cwd = cmd.childCwd() }) catch |e|
        return spawnFailure(ctx, cmd, e);
}

/// Reports why a program could not be started.
fn spawnFailure(ctx: *const Context, cmd: Command, err: anyerror) error{Reported} {
    return switch (err) {
        error.FileNotFound => ctx.fail("{s}: command not found", .{cmd.argv[0]}),
        else => ctx.fail("cannot run {s}: {s}", .{ cmd.argv[0], @errorName(err) }),
    };
}
