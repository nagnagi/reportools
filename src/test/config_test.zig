//! Unit tests for `config.zig`.

const std = @import("std");
const config_mod = @import("../config.zig");
const Config = config_mod.Config;
const Key = config_mod.Key;
const Fixture = @import("Fixture.zig");
const Style = @import("../report.zig").Style;

test "set validates, and save then load round-trips" {
    const fx = try Fixture.init();
    defer fx.deinit();
    var config = try Config.load(&fx.ctx);
    try std.testing.expectEqual(null, config.get(.release_title));
    try std.testing.expectEqual(Style.typst, config.defaultStyle());

    try config.set(fx.ctx.arena, .release_title, "12345_氏名");
    try config.set(fx.ctx.arena, .init_style, "latex");
    try std.testing.expectError(error.InvalidTitle, config.set(fx.ctx.arena, .release_title, "a b"));
    try std.testing.expectError(error.InvalidTitle, config.set(fx.ctx.arena, .release_title, "a/$(b)"));
    try std.testing.expectError(error.InvalidStyle, config.set(fx.ctx.arena, .init_style, "word"));
    try std.testing.expect(!config.autoCommit());
    try std.testing.expectError(error.InvalidBool, config.set(fx.ctx.arena, .commit_auto, "yes"));
    try config.set(fx.ctx.arena, .commit_auto, "true");
    try config.save(&fx.ctx);

    const again = try Config.load(&fx.ctx);
    try std.testing.expectEqualStrings("12345_氏名", again.get(.release_title).?);
    try std.testing.expectEqual(Style.latex, again.defaultStyle());
    try std.testing.expect(again.autoCommit());
}

test "Key.parse accepts exactly the dotted names" {
    try std.testing.expectEqual(Key.github_user, Key.parse("github.user").?);
    try std.testing.expectEqual(null, Key.parse("title"));
}
