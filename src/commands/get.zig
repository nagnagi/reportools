const std = @import("std");
const args = @import("../args.zig");
const Config = @import("../config.zig").Config;
const Context = @import("../Context.zig");
const files = @import("../files.zig");
const github = @import("../github.zig");
const metafile = @import("../metafile.zig");
const Registry = @import("../registry.zig").Registry;
const report_mod = @import("../report.zig");

pub const summary = "clone an existing report repository and register it";
pub const usage =
    \\get <short>
    \\
    \\Clones <user>/<short> into ./<short>.
;
pub const spec: args.Spec = .{};

/// Clones a report repository into the working directory and registers it.
pub fn run(ctx: *Context, parsed: args.Parsed) !void {
    if (parsed.positionals.len != 1) return ctx.fail("get takes exactly one <short>", .{});
    const short = parsed.positionals[0];
    if (!report_mod.isValidShort(short)) {
        return ctx.fail("{s}: {s}", .{ short, report_mod.explain(error.InvalidShort) });
    }

    var registry = try Registry.load(ctx);
    if (registry.find(short)) |item| {
        return ctx.fail("{s} is already registered at {s}", .{ item.short, item.path });
    }
    const root = try ctx.absolute(short);
    if (files.exists(ctx, root)) return ctx.fail("{s} already exists", .{root});

    const config = try Config.load(ctx);
    const repo: github.Repo = .{ .owner = try github.resolveUser(ctx, &config), .name = short };
    try github.clone(ctx, repo, root);

    const report = try loadOrCreate(ctx, root, .{ .short = short, .style = config.defaultStyle() });
    try registry.register(ctx, .{ .short = report.short, .path = root });
    try ctx.out.print("got {s} in {s}\n", .{ report.short, root });
}

/// Loads the cloned metafile, writing `fallback` if the repository has none.
fn loadOrCreate(ctx: *Context, root: []const u8, fallback: report_mod.Report) !report_mod.Report {
    return metafile.load(ctx, root) catch |e| switch (e) {
        error.MetafileNotFound => {
            try metafile.save(ctx, root, fallback);
            ctx.warn("the repository had no {s}; created one, commit it to keep it", .{metafile.name});
            return fallback;
        },
        else => return e,
    };
}
