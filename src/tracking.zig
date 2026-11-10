//! Keeps the metafile committed, or tells the user when it is not.

const Config = @import("config.zig").Config;
const Context = @import("Context.zig");
const git = @import("git.zig");
const metafile = @import("metafile.zig");

pub const Notice = enum { warn, quiet };

/// Call after writing the metafile in `root`. With `commit.auto` it is committed under
/// `message`; otherwise `notice` decides whether the user is told it is uncommitted.
pub fn settle(ctx: *const Context, root: []const u8, message: []const u8, notice: Notice) !void {
    if (try git.fileStatus(ctx, root, metafile.name) != .dirty) return;
    const config = try Config.load(ctx);
    if (config.autoCommit()) return git.commitFile(ctx, root, metafile.name, message);
    if (notice == .warn) ctx.warn(
        "{s} in {s} is not committed\ncommit it yourself, or let reportools do it: reportools config commit.auto true",
        .{ metafile.name, root },
    );
}
