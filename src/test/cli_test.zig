//! End-to-end tests that drive whole command lines against a temporary home.

const std = @import("std");
const build_options = @import("build_options");
const cli = @import("../cli.zig");
const run = cli.run;

const Fixture = @import("Fixture.zig");
const files = @import("../files.zig");
const proc = @import("../proc.zig");

/// Runs a command line in the fixture and returns its standard output.
fn exec(fx: *Fixture, argv: []const []const u8) ![]const u8 {
    try run(&fx.ctx, argv);
    return fx.takeOut();
}

/// Creates `<work>/<name>` and returns its absolute path.
fn makeProject(fx: *Fixture, name: []const u8) ![]const u8 {
    const root = try fx.ctx.absolute(name);
    try files.makeDir(&fx.ctx, root);
    return root;
}

/// Creates `<work>/<name>` as a git repository that can commit without global configuration.
fn makeRepo(fx: *Fixture, name: []const u8) ![]const u8 {
    const root = try makeProject(fx, name);
    const setup = [_][]const []const u8{
        &.{ "git", "init", "--quiet" },
        &.{ "git", "config", "user.name", "Test" },
        &.{ "git", "config", "user.email", "test@example.invalid" },
        &.{ "git", "config", "commit.gpgsign", "false" },
    };
    for (setup) |argv| _ = try git(fx, root, argv);
    return root;
}

/// Runs a git command line in `root` and returns its output.
fn git(fx: *Fixture, root: []const u8, argv: []const []const u8) ![]const u8 {
    return proc.capture(&fx.ctx, .{ .argv = argv, .cwd = root });
}

test "global options print usage and version" {
    const fx = try Fixture.init();
    defer fx.deinit();

    const usage = try exec(fx, &.{"--help"});
    const subcommands = [_][]const u8{ "list", "at", "get", "sync", "init", "add", "remove", "modify", "ok", "export", "config" };
    for (subcommands) |name| {
        const line = try std.fmt.allocPrint(fx.ctx.arena, "\n  {s} ", .{name});
        try std.testing.expect(std.mem.find(u8, usage, line) != null);
    }
    try std.testing.expectEqualStrings("reportools " ++ build_options.version ++ "\n", try exec(fx, &.{"--version"}));
    try std.testing.expect(std.mem.startsWith(u8, try exec(fx, &.{ "modify", "--help" }), "usage: reportools modify"));
}

test "--env emits an alias, and completion only for zsh" {
    const fx = try Fixture.init();
    defer fx.deinit();

    try std.testing.expectEqualStrings("alias rt=reportools\n", try exec(fx, &.{ "--env", "bash" }));
    const zsh = try exec(fx, &.{ "--env", "zsh" });
    try std.testing.expect(std.mem.startsWith(u8, zsh, "alias rt=reportools\n"));
    try std.testing.expect(std.mem.find(u8, zsh, "compdef _reportools reportools rt") != null);
    try std.testing.expectError(error.Reported, run(&fx.ctx, &.{ "--env", "fish" }));
}

test "bad command lines are reported" {
    const fx = try Fixture.init();
    defer fx.deinit();

    try std.testing.expectError(error.Reported, run(&fx.ctx, &.{}));
    try std.testing.expectError(error.Reported, run(&fx.ctx, &.{"nope"}));
    try std.testing.expectError(error.Reported, run(&fx.ctx, &.{ "list", "--nope" }));
    try std.testing.expect(std.mem.find(u8, try fx.takeErr(), "--nope: unknown option") != null);
    try std.testing.expectError(error.Reported, run(&fx.ctx, &.{ "at", "--state", "x", "--deadline=1" }));
}

test "config sets, prints and lists settings" {
    const fx = try Fixture.init();
    defer fx.deinit();

    try std.testing.expectError(error.Reported, run(&fx.ctx, &.{ "config", "release.title" }));
    try std.testing.expectError(error.Reported, run(&fx.ctx, &.{ "config", "title", "x" }));
    try std.testing.expectError(error.Reported, run(&fx.ctx, &.{ "config", "release.title", "a b" }));

    _ = try exec(fx, &.{ "config", "release.title", "12345_氏名" });
    _ = try exec(fx, &.{ "config", "init.style", "latex" });
    try std.testing.expectEqualStrings("12345_氏名\n", try exec(fx, &.{ "config", "release.title" }));
    try std.testing.expectEqualStrings("release.title=12345_氏名\ninit.style=latex\n", try exec(fx, &.{ "config", "--list" }));
}

test "init refuses to create anything until release.title is set" {
    const fx = try Fixture.init();
    defer fx.deinit();

    try std.testing.expectError(error.Reported, run(&fx.ctx, &.{ "init", "algo1" }));
    const message = try fx.takeErr();
    try std.testing.expect(std.mem.find(u8, message, "release.title is not set") != null);
    try std.testing.expect(std.mem.find(u8, message, "reportools config release.title <name>") != null);
    try std.testing.expect(!files.exists(&fx.ctx, try fx.ctx.absolute("algo1")));
}

test "a report goes from add through the submit cycle to remove" {
    const fx = try Fixture.init();
    defer fx.deinit();
    const root = try makeProject(fx, "algo1");

    _ = try exec(fx, &.{ "add", "algo1", "-l", "第1回 レポート", "-j", "アルゴリズム論", "-d", "2026-11-30 23:59" });
    try std.testing.expectEqualStrings("draft\n", try exec(fx, &.{ "at", "algo1", "--state" }));

    const cycle = [_][]const u8{ "submit", "resub", "submit", "ok" };
    for (cycle) |state| {
        _ = try exec(fx, &.{ "modify", "algo1", "--state", state });
        try std.testing.expectEqualStrings(state, std.mem.trim(u8, try exec(fx, &.{ "at", "algo1", "-s" }), "\n"));
    }
    try std.testing.expectEqualStrings(
        "2026-11-30 23:59\nアルゴリズム論\n",
        try exec(fx, &.{ "at", "algo1", "--deadline", "--subject" }),
    );

    try std.testing.expect(std.mem.find(u8, try exec(fx, &.{ "remove", "algo1" }), root) != null);
    try std.testing.expectError(error.Reported, run(&fx.ctx, &.{ "at", "algo1" }));
    try std.testing.expect(files.isDir(&fx.ctx, root));
}

test "modify validates values and never changes short" {
    const fx = try Fixture.init();
    defer fx.deinit();
    _ = try makeProject(fx, "a");
    _ = try exec(fx, &.{ "add", "a" });

    try std.testing.expectError(error.Reported, run(&fx.ctx, &.{ "modify", "a", "--state", "done" }));
    try std.testing.expectError(error.Reported, run(&fx.ctx, &.{ "modify", "a", "--deadline", "2026-11-30" }));
    try std.testing.expectError(error.Reported, run(&fx.ctx, &.{ "modify", "a", "--short", "b" }));
    try std.testing.expectError(error.Reported, run(&fx.ctx, &.{ "modify", "a" }));
    try std.testing.expectEqualStrings("draft\n\n", try exec(fx, &.{ "at", "a", "--state", "--deadline" }));
}

test "ok finishes a report by name or from inside its project" {
    const fx = try Fixture.init();
    defer fx.deinit();
    const named = try makeProject(fx, "named");
    _ = try makeProject(fx, "other");
    _ = try exec(fx, &.{ "add", "named", "--state", "submit" });
    _ = try exec(fx, &.{ "add", "other" });

    _ = try exec(fx, &.{ "ok", "other" });
    try std.testing.expectEqualStrings("ok\n", try exec(fx, &.{ "at", "other", "--state" }));
    try std.testing.expectEqualStrings("submit\n", try exec(fx, &.{ "at", "named", "--state" }));

    fx.ctx.cwd = named;
    _ = try exec(fx, &.{"ok"});
    try std.testing.expectEqualStrings("ok\n", try exec(fx, &.{ "at", "--state" }));
    try std.testing.expectError(error.Reported, run(&fx.ctx, &.{ "ok", "missing" }));
}

test "short may be omitted inside a project" {
    const fx = try Fixture.init();
    defer fx.deinit();
    const root = try makeProject(fx, "inside");
    _ = try exec(fx, &.{ "add", "inside" });
    const work = fx.ctx.cwd;

    fx.ctx.cwd = try std.fs.path.join(fx.ctx.arena, &.{ root, "src" });
    try files.makeDir(&fx.ctx, fx.ctx.cwd);
    _ = try exec(fx, &.{ "modify", "--state", "submit" });
    try std.testing.expectEqualStrings("inside\nsubmit\n", try exec(fx, &.{ "at", "--short", "--state" }));

    fx.ctx.cwd = work;
    try std.testing.expectError(error.Reported, run(&fx.ctx, &.{ "at", "--state" }));
}

test "list sorts by deadline, and export dumps every field" {
    const fx = try Fixture.init();
    defer fx.deinit();
    const late = try makeProject(fx, "late");
    const soon = try makeProject(fx, "soon");
    _ = try makeProject(fx, "undated");
    _ = try exec(fx, &.{ "add", "undated" });
    _ = try exec(fx, &.{ "add", "late", "-d", "2026-12-24 17:00", "-j", "数学" });
    _ = try exec(fx, &.{ "add", "soon", "-d", "2026-11-12 09:00", "-l", "T" });

    try std.testing.expectEqualStrings("soon\nlate\nundated\n", try exec(fx, &.{ "list", "--short" }));
    try std.testing.expectEqualStrings(
        "SHORT    SUBJECT  DEADLINE          STATE  TITLE\n" ++
            "soon              2026-11-12 09:00  draft  T\n" ++
            "late     数学     2026-12-24 17:00  draft  \n" ++
            "undated                             draft  \n",
        try exec(fx, &.{"list"}),
    );

    const dump = try exec(fx, &.{"export"});
    var lines = std.mem.splitScalar(u8, dump, '\n');
    try std.testing.expectEqualStrings("short\ttitle\tsubject\tdeadline\tstate\tstyle\tpath", lines.next().?);
    try std.testing.expectEqualStrings(
        try std.fmt.allocPrint(fx.ctx.arena, "soon\tT\t\t2026-11-12 09:00\tdraft\ttypst\t{s}", .{soon}),
        lines.next().?,
    );
    try std.testing.expectEqualStrings(
        try std.fmt.allocPrint(fx.ctx.arena, "late\t\t数学\t2026-12-24 17:00\tdraft\ttypst\t{s}", .{late}),
        lines.next().?,
    );
}

test "add creates a missing metafile, naming the report after its directory unless --short is given" {
    const fx = try Fixture.init();
    defer fx.deinit();
    const plain = try makeProject(fx, "plain");
    const renamed = try makeProject(fx, "renamed");
    const metafile = @import("../metafile.zig");

    try std.testing.expectError(error.MetafileNotFound, metafile.load(&fx.ctx, plain));
    _ = try exec(fx, &.{ "add", "plain" });
    _ = try exec(fx, &.{ "add", "renamed", "--short", "custom" });

    try std.testing.expectEqualStrings("plain", (try metafile.load(&fx.ctx, plain)).short);
    try std.testing.expectEqualStrings("custom", (try metafile.load(&fx.ctx, renamed)).short);
    try std.testing.expectEqualStrings("custom\nplain\n", try exec(fx, &.{ "list", "--short" }));
}

test "add warns when .reportools is left uncommitted in a repository" {
    const fx = try Fixture.init();
    defer fx.deinit();
    const root = try makeRepo(fx, "repo");
    _ = try makeProject(fx, "plain");

    _ = try exec(fx, &.{ "add", "plain" });
    try std.testing.expectEqualStrings("", try fx.takeErr());

    _ = try exec(fx, &.{ "add", "repo" });
    const warning = try fx.takeErr();
    const expected = try std.fmt.allocPrint(fx.ctx.arena, ".reportools in {s} is not committed", .{root});
    try std.testing.expect(std.mem.find(u8, warning, expected) != null);
    try std.testing.expect(std.mem.find(u8, warning, "reportools config commit.auto true") != null);
    try std.testing.expectEqualStrings("?? .reportools", try git(fx, root, &.{ "git", "status", "--porcelain" }));
}

test "commit.auto commits .reportools alone after add, modify and ok" {
    const fx = try Fixture.init();
    defer fx.deinit();
    const root = try makeRepo(fx, "repo");
    try files.write(&fx.ctx, try std.fs.path.join(fx.ctx.arena, &.{ root, "draft.txt" }), "wip");
    _ = try git(fx, root, &.{ "git", "add", "draft.txt" });
    _ = try exec(fx, &.{ "config", "commit.auto", "true" });

    _ = try exec(fx, &.{ "add", "repo" });
    _ = try exec(fx, &.{ "modify", "repo", "--state", "submit" });
    _ = try exec(fx, &.{ "ok", "repo" });
    _ = try exec(fx, &.{ "ok", "repo" });

    try std.testing.expectEqualStrings("", try fx.takeErr());
    try std.testing.expectEqualStrings(
        "Mark report as ok\nUpdate report details\nAdd .reportools",
        try git(fx, root, &.{ "git", "log", "--format=%s" }),
    );
    try std.testing.expectEqualStrings(".reportools", try git(fx, root, &.{ "git", "ls-tree", "--name-only", "HEAD" }));
    try std.testing.expectEqualStrings("A  draft.txt", try git(fx, root, &.{ "git", "status", "--porcelain" }));
}

test "add reuses an existing metafile and rejects a short registered elsewhere" {
    const fx = try Fixture.init();
    defer fx.deinit();
    const first = try makeProject(fx, "first");
    _ = try makeProject(fx, "second");
    _ = try exec(fx, &.{ "add", "first", "--short", "shared", "--state", "submit" });
    _ = try exec(fx, &.{ "remove", "shared" });

    _ = try exec(fx, &.{ "add", "first" });
    try std.testing.expectEqualStrings("submit\n", try exec(fx, &.{ "at", "shared", "--state" }));
    try std.testing.expectError(error.Reported, run(&fx.ctx, &.{ "add", "second", "--short", "shared" }));
    try std.testing.expect(std.mem.find(u8, try fx.takeErr(), first) != null);
    try std.testing.expectError(error.Reported, run(&fx.ctx, &.{ "add", "missing-dir" }));
}

test "modify --path follows a moved project" {
    const fx = try Fixture.init();
    defer fx.deinit();
    const old = try makeProject(fx, "moved");
    _ = try exec(fx, &.{ "add", "moved" });
    const new = try fx.ctx.absolute("elsewhere");
    try std.Io.Dir.renameAbsolute(old, new, fx.ctx.io);

    try std.testing.expectError(error.Reported, run(&fx.ctx, &.{ "at", "moved" }));
    try std.testing.expectError(error.Reported, run(&fx.ctx, &.{ "modify", "moved", "--path", "nowhere" }));
    _ = try exec(fx, &.{ "modify", "moved", "--path", "elsewhere" });
    try std.testing.expectEqualStrings(
        try std.fmt.allocPrint(fx.ctx.arena, "{s}\n", .{new}),
        try exec(fx, &.{ "at", "moved", "--path" }),
    );
}
