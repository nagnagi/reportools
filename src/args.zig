//! Command-line option parsing shared by every subcommand.

const std = @import("std");
const Allocator = std.mem.Allocator;

pub const Opt = enum {
    help,
    all,
    list,
    style,
    short,
    title,
    subject,
    deadline,
    state,
    path,

    /// Returns the spellings accepted for this option, preferred one first.
    pub fn names(opt: Opt) []const []const u8 {
        return switch (opt) {
            .help => &.{ "--help", "-h" },
            .all => &.{ "--all", "-a" },
            .list => &.{"--list"},
            .style => &.{"--style"},
            .short => &.{ "--short", "-t" },
            .title => &.{ "--title", "--long", "-l" },
            .subject => &.{ "--subject", "--subj", "-j" },
            .deadline => &.{ "--deadline", "--in", "-d" },
            .state => &.{ "--state", "-s" },
            .path => &.{ "--path", "-p" },
        };
    }

    /// Finds the option spelled `name`.
    fn named(name: []const u8) ?Opt {
        for (std.enums.values(Opt)) |opt| {
            for (opt.names()) |candidate| {
                if (std.mem.eql(u8, candidate, name)) return opt;
            }
        }
        return null;
    }
};

/// The options a subcommand accepts. `--help` is always accepted.
pub const Spec = struct {
    flags: []const Opt = &.{},
    values: []const Opt = &.{},

    const Kind = enum { flag, value };

    /// Returns how `opt` is used by this subcommand, or null if it is not accepted.
    fn kind(spec: Spec, opt: Opt) ?Kind {
        if (opt == .help) return .flag;
        if (std.mem.findScalar(Opt, spec.flags, opt) != null) return .flag;
        if (std.mem.findScalar(Opt, spec.values, opt) != null) return .value;
        return null;
    }
};

pub const Parsed = struct {
    /// Options in the order they first appeared.
    seen: []const Opt = &.{},
    values: std.EnumMap(Opt, []const u8) = .{},
    positionals: []const []const u8 = &.{},

    /// Reports whether `opt` was given.
    pub fn has(self: *const Parsed, opt: Opt) bool {
        return std.mem.findScalar(Opt, self.seen, opt) != null;
    }

    /// Returns the value given to `opt`.
    pub fn value(self: *const Parsed, opt: Opt) ?[]const u8 {
        return self.values.get(opt);
    }
};

pub const ParseError = error{ UnknownOption, MissingValue, UnexpectedValue } || Allocator.Error;

const Parser = struct {
    gpa: Allocator,
    spec: Spec,
    argv: []const []const u8,
    index: usize = 0,
    seen: std.ArrayList(Opt) = .empty,
    values: std.EnumMap(Opt, []const u8) = .{},
    positionals: std.ArrayList([]const u8) = .empty,

    /// Consumes every argument.
    fn run(p: *Parser, culprit: *[]const u8) ParseError!void {
        var options_ended = false;
        while (p.index < p.argv.len) {
            const arg = p.argv[p.index];
            p.index += 1;
            culprit.* = arg;
            if (options_ended or arg.len < 2 or arg[0] != '-') {
                try p.positionals.append(p.gpa, arg);
            } else if (std.mem.eql(u8, arg, "--")) {
                options_ended = true;
            } else if (arg[1] == '-') {
                try p.long(arg);
            } else {
                try p.cluster(arg);
            }
        }
    }

    /// Handles `--name`, `--name value` and `--name=value`.
    fn long(p: *Parser, arg: []const u8) ParseError!void {
        var name = arg;
        var inline_value: ?[]const u8 = null;
        if (std.mem.cutScalar(u8, arg, '=')) |parts| {
            name = parts[0];
            inline_value = parts[1];
        }
        const opt = Opt.named(name) orelse return error.UnknownOption;
        switch (p.spec.kind(opt) orelse return error.UnknownOption) {
            .flag => if (inline_value != null) return error.UnexpectedValue,
            .value => p.values.put(opt, inline_value orelse try p.next()),
        }
        try p.mark(opt);
    }

    /// Handles `-a`, `-ab`, `-s value` and `-svalue`.
    fn cluster(p: *Parser, arg: []const u8) ParseError!void {
        for (arg[1..], 1..) |letter, position| {
            const opt = Opt.named(&.{ '-', letter }) orelse return error.UnknownOption;
            try p.mark(opt);
            switch (p.spec.kind(opt) orelse return error.UnknownOption) {
                .flag => {},
                .value => {
                    const rest = arg[position + 1 ..];
                    p.values.put(opt, if (rest.len != 0) rest else try p.next());
                    return;
                },
            }
        }
    }

    /// Takes the next argument as an option value.
    fn next(p: *Parser) ParseError![]const u8 {
        if (p.index >= p.argv.len) return error.MissingValue;
        defer p.index += 1;
        return p.argv[p.index];
    }

    /// Records that `opt` appeared.
    fn mark(p: *Parser, opt: Opt) Allocator.Error!void {
        if (std.mem.findScalar(Opt, p.seen.items, opt) == null) try p.seen.append(p.gpa, opt);
    }
};

/// Parses `argv` against `spec`. On failure, `culprit` is the argument at fault.
pub fn parse(gpa: Allocator, spec: Spec, argv: []const []const u8, culprit: *[]const u8) ParseError!Parsed {
    var parser: Parser = .{ .gpa = gpa, .spec = spec, .argv = argv };
    try parser.run(culprit);
    return .{
        .seen = try parser.seen.toOwnedSlice(gpa),
        .values = parser.values,
        .positionals = try parser.positionals.toOwnedSlice(gpa),
    };
}
