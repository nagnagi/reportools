//! The `gh` operations reportools performs on GitHub.

const std = @import("std");
const Context = @import("Context.zig");
const Config = @import("config.zig").Config;
const proc = @import("proc.zig");

pub const Repo = struct {
    owner: []const u8,
    name: []const u8,

    /// Returns `owner/name`.
    pub fn slug(repo: Repo, ctx: *const Context) ![]const u8 {
        return std.fmt.allocPrint(ctx.arena, "{s}/{s}", .{ repo.owner, repo.name });
    }
};

/// Returns the repository owner: `github.user` if set, otherwise the account `gh` is logged in to.
pub fn resolveUser(ctx: *const Context, config: *const Config) ![]const u8 {
    if (config.get(.github_user)) |user| return user;
    const login = try proc.capture(ctx, .{ .argv = &.{ "gh", "api", "user", "--jq", ".login" } });
    if (login.len == 0) return ctx.fail("gh did not report a login; set github.user with `reportools config`", .{});
    return login;
}

/// Creates `repo` as a private repository from the project in `dir` and pushes it.
pub fn createPrivate(ctx: *const Context, repo: Repo, dir: []const u8) !void {
    try proc.run(ctx, .{ .argv = &.{
        "gh",        "repo",     "create", try repo.slug(ctx),
        "--private", "--source", dir,      "--remote",
        "origin",    "--push",
    } });
}

/// Clones `repo` into `dest`.
pub fn clone(ctx: *const Context, repo: Repo, dest: []const u8) !void {
    try proc.run(ctx, .{ .argv = &.{ "gh", "repo", "clone", try repo.slug(ctx), dest } });
}
