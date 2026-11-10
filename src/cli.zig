//! Top-level command line: global options and subcommand dispatch.

const std = @import("std");
const build_options = @import("build_options");
const args = @import("args.zig");
const Context = @import("Context.zig");
const shellenv = @import("shellenv.zig");

const Command = struct {
    name: []const u8,
    summary: []const u8,
    usage: []const u8,
    spec: args.Spec,
    run: *const fn (*Context, args.Parsed) anyerror!void,

    /// Describes the subcommand implemented by `module`.
    fn from(comptime name: []const u8, comptime module: type) Command {
        return .{
            .name = name,
            .summary = module.summary,
            .usage = module.usage,
            .spec = module.spec,
            .run = module.run,
        };
    }
};

const commands = [_]Command{
    .from("list", @import("commands/list.zig")),
    .from("at", @import("commands/at.zig")),
    .from("get", @import("commands/get.zig")),
    .from("sync", @import("commands/sync.zig")),
    .from("init", @import("commands/init.zig")),
    .from("add", @import("commands/add.zig")),
    .from("remove", @import("commands/remove.zig")),
    .from("modify", @import("commands/modify.zig")),
    .from("export", @import("commands/export.zig")),
    .from("config", @import("commands/config.zig")),
};

const usage_head =
    \\usage: reportools <subcommand> [-<options>] [--<long option>, ...] <arguments>
    \\       reportools --help | --version | --env <zsh|bash>
    \\
    \\subcommands:
    \\
;
const usage_tail =
    \\
    \\Run `reportools <subcommand> --help` for details.
    \\`rt` is short for `reportools` after: eval "$(reportools --env zsh)"
    \\
;

/// Interprets the arguments that follow the program name.
pub fn run(ctx: *Context, argv: []const []const u8) !void {
    if (argv.len == 0) {
        try writeUsage(ctx.err);
        return error.Reported;
    }
    const first = argv[0];
    if (isAny(first, &.{ "--help", "-h" })) return writeUsage(ctx.out);
    if (std.mem.eql(u8, first, "--version")) return ctx.out.print("reportools {s}\n", .{build_options.version});
    if (std.mem.eql(u8, first, "--env")) {
        if (argv.len != 2) return ctx.fail("--env takes exactly one shell name (zsh, bash)", .{});
        return shellenv.print(ctx, argv[1]);
    }
    const command = find(first) orelse
        return ctx.fail("{s}: unknown subcommand; see `reportools --help`", .{first});
    try dispatch(ctx, command, argv[1..]);
}

/// Parses a subcommand's arguments and runs it, or prints its usage for `--help`.
fn dispatch(ctx: *Context, command: *const Command, argv: []const []const u8) !void {
    var culprit: []const u8 = "";
    const parsed = args.parse(ctx.arena, command.spec, argv, &culprit) catch |e| {
        const problem = switch (e) {
            error.OutOfMemory => return e,
            error.UnknownOption => "unknown option",
            error.MissingValue => "option needs a value",
            error.UnexpectedValue => "option takes no value",
        };
        return ctx.fail("{s}: {s}: {s}; see `reportools {s} --help`", .{ command.name, culprit, problem, command.name });
    };
    if (parsed.has(.help)) return ctx.out.print("usage: reportools {s}\n", .{command.usage});
    try command.run(ctx, parsed);
}

/// Finds a subcommand by name.
fn find(name: []const u8) ?*const Command {
    for (&commands) |*command| {
        if (std.mem.eql(u8, command.name, name)) return command;
    }
    return null;
}

/// Reports whether `text` equals one of `candidates`.
fn isAny(text: []const u8, candidates: []const []const u8) bool {
    for (candidates) |candidate| {
        if (std.mem.eql(u8, text, candidate)) return true;
    }
    return false;
}

/// Prints the global usage.
fn writeUsage(w: *std.Io.Writer) !void {
    try w.writeAll(usage_head);
    for (commands) |command| try w.print("  {s:<8}{s}\n", .{ command.name, command.summary });
    try w.writeAll(usage_tail);
}
