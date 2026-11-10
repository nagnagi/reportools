//! Output of `--env <shell>`, meant to be passed to `eval` from a shell rc file.

const std = @import("std");
const Context = @import("Context.zig");

const Shell = enum { zsh, bash };

const alias = "alias rt=reportools\n";
const zsh_completion = @embedFile("shell/completion.zsh");

/// Prints the alias, plus completion for shells that have one.
pub fn print(ctx: *Context, shell_name: []const u8) !void {
    const shell = std.meta.stringToEnum(Shell, shell_name) orelse
        return ctx.fail("--env: unsupported shell: {s} (zsh, bash)", .{shell_name});
    try ctx.out.writeAll(alias);
    switch (shell) {
        .zsh => try ctx.out.writeAll(zsh_completion),
        .bash => {},
    }
}
