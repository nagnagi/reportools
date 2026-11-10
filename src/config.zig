//! The user's settings in `config.ini`.

const std = @import("std");
const Context = @import("Context.zig");
const files = @import("files.zig");
const ini = @import("ini.zig");
const Style = @import("report.zig").Style;

pub const Key = enum {
    release_title,
    init_style,
    github_user,

    pub const all = std.enums.values(Key);

    /// Returns the dotted name used on the command line.
    pub fn name(key: Key) []const u8 {
        return switch (key) {
            .release_title => "release.title",
            .init_style => "init.style",
            .github_user => "github.user",
        };
    }

    /// Finds the key with the given dotted name.
    pub fn parse(text: []const u8) ?Key {
        for (all) |key| {
            if (std.mem.eql(u8, key.name(), text)) return key;
        }
        return null;
    }

    /// Splits the dotted name into its ini section and entry.
    fn location(key: Key) struct { []const u8, []const u8 } {
        return std.mem.cutScalar(u8, key.name(), '.').?;
    }
};

pub const SetError = error{ InvalidTitle, InvalidStyle, InvalidUser };

pub const Config = struct {
    doc: ini.Document = .{},

    /// Loads the config file; a missing file is an empty config.
    pub fn load(ctx: *const Context) !Config {
        const path = try ctx.configPath();
        const text = try files.read(ctx, path) orelse return .{};
        var line: usize = 0;
        const doc = ini.Document.parse(ctx.arena, text, &line) catch |e| switch (e) {
            error.InvalidLine => return ctx.fail("{s}:{d}: not a valid ini line", .{ path, line }),
            error.OutOfMemory => return e,
        };
        return .{ .doc = doc };
    }

    /// Returns the value of `key`, treating an empty value as unset.
    pub fn get(self: *const Config, key: Key) ?[]const u8 {
        const section, const entry = key.location();
        const value = self.doc.get(section, entry) orelse return null;
        return if (value.len == 0) null else value;
    }

    /// Validates and stores `value`, which the config borrows.
    pub fn set(self: *Config, gpa: std.mem.Allocator, key: Key, value: []const u8) (SetError || std.mem.Allocator.Error)!void {
        switch (key) {
            .release_title => if (!isFileStem(value)) return error.InvalidTitle,
            .init_style => if (std.meta.stringToEnum(Style, value) == null) return error.InvalidStyle,
            .github_user => if (!isFileStem(value)) return error.InvalidUser,
        }
        const section, const entry = key.location();
        try self.doc.set(gpa, section, entry, value);
    }

    /// Writes the config file.
    pub fn save(self: *const Config, ctx: *const Context) !void {
        try files.replace(ctx, try ctx.configPath(), try self.doc.render(ctx.arena));
    }

    /// Returns the style `init` uses when none is given.
    pub fn defaultStyle(self: *const Config) Style {
        const text = self.get(.init_style) orelse return .typst;
        return std.meta.stringToEnum(Style, text) orelse .typst;
    }
};

/// Explains a `SetError` for the user.
pub fn explain(err: SetError) []const u8 {
    return switch (err) {
        error.InvalidTitle => "release.title must be a file name without spaces or shell and make metacharacters",
        error.InvalidStyle => "init.style must be one of: typst, latex",
        error.InvalidUser => "github.user must be a GitHub login",
    };
}

/// Reports whether `text` can be pasted unquoted into a Makefile recipe and a gitignore pattern.
fn isFileStem(text: []const u8) bool {
    if (text.len == 0 or text[0] == '-' or text[0] == '.') return false;
    for (text) |byte| {
        if (byte <= 0x20 or byte == 0x7f) return false;
        if (std.mem.findScalar(u8, "/\\$#%:;'\"`*?|&<>()[]{}!~=", byte) != null) return false;
    }
    return true;
}

const Fixture = @import("Fixture.zig");

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
    try config.save(&fx.ctx);

    const again = try Config.load(&fx.ctx);
    try std.testing.expectEqualStrings("12345_氏名", again.get(.release_title).?);
    try std.testing.expectEqual(Style.latex, again.defaultStyle());
}

test "Key.parse accepts exactly the dotted names" {
    try std.testing.expectEqual(Key.github_user, Key.parse("github.user").?);
    try std.testing.expectEqual(null, Key.parse("title"));
}
