const std = @import("std");
const Io = std.Io;
const cli = @import("cli.zig");
const Context = @import("Context.zig");

/// Entry point: builds the runtime context, runs the command line and maps errors to an exit code.
pub fn main(init: std.process.Init) u8 {
    var out_buffer: [4096]u8 = undefined;
    var out: Io.File.Writer = .init(.stdout(), init.io, &out_buffer);
    var err: Io.File.Writer = .init(.stderr(), init.io, &.{});

    const succeeded = if (start(init, &out.interface, &err.interface)) true else |e| blk: {
        switch (e) {
            error.Reported, error.WriteFailed => {},
            else => err.interface.print("reportools: {s}\n", .{@errorName(e)}) catch {},
        }
        break :blk false;
    };
    out.interface.flush() catch return 1;
    return if (succeeded) 0 else 1;
}

/// Gathers the process environment into a context and hands over to the command line.
fn start(init: std.process.Init, out: *Io.Writer, err: *Io.Writer) !void {
    const arena = init.arena.allocator();
    var ctx: Context = .{
        .arena = arena,
        .io = init.io,
        .out = out,
        .err = err,
        .home = "",
        .cwd = try std.process.currentPathAlloc(init.io, arena),
    };
    ctx.home = init.environ_map.get("HOME") orelse return ctx.fail("HOME is not set", .{});

    const raw_args = try init.minimal.args.toSlice(arena);
    const argv = try arena.alloc([]const u8, raw_args.len);
    for (raw_args, argv) |raw, *arg| arg.* = raw;
    try cli.run(&ctx, argv[@min(1, argv.len)..]);
}

test {
    _ = @import("cli_test.zig");
    _ = @import("args.zig");
    _ = @import("config.zig");
    _ = @import("deadline.zig");
    _ = @import("files.zig");
    _ = @import("ini.zig");
    _ = @import("metafile.zig");
    _ = @import("proc.zig");
    _ = @import("registry.zig");
    _ = @import("report.zig");
    _ = @import("scaffold.zig");
    _ = @import("table.zig");
}
