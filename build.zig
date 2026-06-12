const std = @import("std");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    const mod = b.addModule("engineburn", .{
        .root_source_file = b.path("src/root.zig"),
        .target = target,
        .link_libc = true,
    });

    const raylib_dep = b.dependency("raylib", .{
        .target = target,
        .optimize = optimize,
        .linux_display_backend = .Wayland,
    });
    const raylib_lib = raylib_dep.artifact("raylib");
    mod.linkLibrary(raylib_lib);
    linkPlatform(mod, target);

    const run_step = b.step("run", "Run an example: zig build run -- examples/sprites.zig");
    addExamples(b, target, optimize, mod, raylib_lib, run_step, extractExampleArg(b));

    const doc_lib = b.addLibrary(.{
        .name = "engineburn",
        .root_module = mod,
        .linkage = .static,
    });
    const docs = b.addInstallDirectory(.{
        .source_dir = doc_lib.getEmittedDocs(),
        .install_dir = .prefix,
        .install_subdir = "docs",
    });
    const docs_step = b.step("docs", "Generate documentation");
    docs_step.dependOn(&docs.step);

    const mod_tests = b.addTest(.{ .root_module = mod });
    const run_mod_tests = b.addRunArtifact(mod_tests);
    const test_step = b.step("test", "Run tests");
    test_step.dependOn(&run_mod_tests.step);
}

fn extractExampleArg(b: *std.Build) ?[]const u8 {
    const args = b.args orelse return null;
    if (args.len == 0) return null;
    const arg = args[0];
    if (!std.mem.startsWith(u8, arg, "examples/")) return null;
    if (!std.mem.endsWith(u8, arg, ".zig")) return null;
    return arg["examples/".len .. arg.len - ".zig".len];
}

fn addExamples(
    b: *std.Build,
    target: std.Build.ResolvedTarget,
    optimize: std.builtin.OptimizeMode,
    mod: *std.Build.Module,
    raylib_lib: *std.Build.Step.Compile,
    run_step: *std.Build.Step,
    run_example: ?[]const u8,
) void {
    var dir = b.build_root.handle.openDir(b.graph.io, "examples", .{ .iterate = true }) catch return;
    defer dir.close(b.graph.io);
    var it = dir.iterate();
    while (it.next(b.graph.io) catch return) |entry| {
        if (entry.kind != .file) continue;
        if (!std.mem.endsWith(u8, entry.name, ".zig")) continue;
        const stem = b.dupe(entry.name[0 .. entry.name.len - 4]);
        const run_cmd = addExample(b, stem, target, optimize, mod, raylib_lib);
        if (run_example) |name| {
            if (std.mem.eql(u8, name, stem)) {
                run_step.dependOn(&run_cmd.step);
                if (b.args) |args| if (args.len > 1) run_cmd.addArgs(args[1..]);
            }
        }
    }
}

fn addExample(
    b: *std.Build,
    name: []const u8,
    target: std.Build.ResolvedTarget,
    optimize: std.builtin.OptimizeMode,
    mod: *std.Build.Module,
    raylib_lib: *std.Build.Step.Compile,
) *std.Build.Step.Run {
    const exe = b.addExecutable(.{
        .name = name,
        .root_module = b.createModule(.{
            .root_source_file = b.path(b.fmt("examples/{s}.zig", .{name})),
            .target = target,
            .optimize = optimize,
            .link_libc = true,
            .imports = &.{
                .{ .name = "engineburn", .module = mod },
            },
        }),
    });
    exe.root_module.linkLibrary(raylib_lib);
    linkPlatform(exe.root_module, target);

    const run_cmd = b.addRunArtifact(exe);
    return run_cmd;
}

fn linkPlatform(module: *std.Build.Module, target: std.Build.ResolvedTarget) void {
    switch (target.result.os.tag) {
        .linux => {
            module.linkSystemLibrary("wayland-client", .{});
            module.linkSystemLibrary("wayland-cursor", .{});
            module.linkSystemLibrary("wayland-egl", .{});
            module.linkSystemLibrary("xkbcommon", .{});
            module.linkSystemLibrary("GL", .{});
        },
        .macos => {
            module.linkFramework("Cocoa", .{});
            module.linkFramework("OpenGL", .{});
            module.linkFramework("IOKit", .{});
        },
        .windows => {
            module.linkSystemLibrary("winmm", .{});
            module.linkSystemLibrary("gdi32", .{});
            module.linkSystemLibrary("opengl32", .{});
        },
        else => {},
    }
}
