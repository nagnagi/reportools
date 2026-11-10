const std = @import("std");
const args = @import("../args.zig");
const config_mod = @import("../config.zig");
const Context = @import("../Context.zig");

pub const summary = "read or change settings in config.ini";
pub const usage =
    \\config <key>            print a setting
    \\config <key> <value>    change a setting
    \\config --list           print every setting that is set
    \\
    \\Keys:
    \\  release.title   file name of the released PDF, without ".pdf" (required by init)
    \\  init.style      default project style: typst or latex
    \\  github.user     repository owner (default: the account gh is logged in to)
    \\  commit.auto     true to commit .reportools whenever reportools rewrites it
    \\                  (default: false)
;
pub const spec: args.Spec = .{ .flags = &.{.list} };

/// Lists, prints or changes settings depending on the arguments.
pub fn run(ctx: *Context, parsed: args.Parsed) !void {
    var config = try config_mod.Config.load(ctx);
    const words = parsed.positionals;
    if (parsed.has(.list)) {
        if (words.len != 0) return ctx.fail("--list takes no arguments", .{});
        return list(ctx, &config);
    }
    if (words.len == 0 or words.len > 2) return ctx.fail("expected <key> [value]; see `reportools config --help`", .{});
    const key = config_mod.Key.parse(words[0]) orelse
        return ctx.fail("{s}: unknown key; see `reportools config --help`", .{words[0]});

    if (words.len == 1) {
        const value = config.get(key) orelse return ctx.fail("{s} is not set", .{key.name()});
        return ctx.out.print("{s}\n", .{value});
    }
    config.set(ctx.arena, key, words[1]) catch |e| switch (e) {
        error.OutOfMemory => return e,
        else => |invalid| return ctx.fail("{s}", .{config_mod.explain(invalid)}),
    };
    try config.save(ctx);
}

/// Prints every setting that has a value as `key=value`.
fn list(ctx: *Context, config: *const config_mod.Config) !void {
    for (config_mod.Key.all) |key| {
        if (config.get(key)) |value| try ctx.out.print("{s}={s}\n", .{ key.name(), value });
    }
}
