const std = @import("std");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    const falco_libs = b.dependency("falco-libs", .{});

    const module = b.addModule("falco-sdk", .{
        .root_source_file = b.path("src/root.zig"),
        .link_libc = true,
    });
    module.addIncludePath(falco_libs.path("userspace"));

    const strl_config = b.addConfigHeader(.{
        .style = .{ .cmake = falco_libs.path("userspace/libscap/scap_strl_config.h.in") },
        .include_path = "libscap/scap_strl_config.h",
    }, .{
        .HAVE_STRLCPY = 0,
        .HAVE_STRLCAT = 0,
    });

    const check_symbols = b.addExecutable(.{
        .name = "check-symbols",
        .root_source_file = b.path("src/check_symbols.zig"),
        .target = b.host,
        .optimize = optimize,
        .link_libc = true,
    });
    check_symbols.addIncludePath(falco_libs.path("userspace"));
    check_symbols.addCSourceFile(.{
        .file = falco_libs.path("userspace/plugin/plugin_loader.c"),
    });
    check_symbols.addConfigHeader(strl_config);

    const check_symbols_run = b.addRunArtifact(check_symbols);
    const check_symbols_step = b.step("check-symbols", "");
    check_symbols_step.dependOn(&check_symbols_run.step);

    const unit_tests = b.addTest(.{
        .root_source_file = b.path("src/root.zig"),
        .link_libc = true,
    });
    unit_tests.addIncludePath(falco_libs.path("userspace"));

    const unit_tests_run = b.addRunArtifact(unit_tests);
    const test_step = b.step("test", "Run unit tests");
    test_step.dependOn(&unit_tests_run.step);

    const example = b.addSharedLibrary(.{
        .name = "example_plugin",
        .root_source_file = b.path("src/example.zig"),
        .target = target,
        .optimize = optimize,
        .link_libc = true,
    });
    example.root_module.addImport("falco", module);
    b.installArtifact(example);
}
