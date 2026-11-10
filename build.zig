const std = @import("std");
const manifest = @import("build.zig.zon");

/// Defines the `install` and `test` steps.
pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    const options = b.addOptions();
    options.addOption([]const u8, "version", manifest.version);

    const root = b.createModule(.{
        .root_source_file = b.path("src/main.zig"),
        .target = target,
        .optimize = optimize,
    });
    root.addOptions("build_options", options);

    const exe = b.addExecutable(.{ .name = "reportools", .root_module = root });
    b.installArtifact(exe);
    b.installFile("man/reportools.1", "share/man/man1/reportools.1");
    b.installFile("man/rt.1", "share/man/man1/rt.1");

    const tests = b.addTest(.{ .root_module = root });
    b.step("test", "Run tests").dependOn(&b.addRunArtifact(tests).step);
}
