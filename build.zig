const std = @import("std");

pub fn build(b: *std.Build) !void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    const sdl_dep = b.dependency("sdl", .{ .target = target, .optimize = optimize });
    const nanovg_dep = b.dependency("nanovg", .{ .target = target, .optimize = optimize });

    const exe = b.addExecutable(.{
        .name = "nanovg-example",
        .root_source_file = .{ .path = "src/main.zig" },
        .target = target,
        .optimize = optimize,
    });
    exe.root_module.addImport("nanovg", nanovg_dep.module("nanovg"));

    exe.addIncludePath(.{ .path = "lib/gl2/include" });
    exe.addCSourceFile(.{ .file = .{ .path = "lib/gl2/src/glad.c" }, .flags = &.{} });
    exe.linkLibrary(sdl_dep.artifact("SDL2"));

    // Link OpenGL
    switch (target.result.os.tag) {
        .windows => exe.linkSystemLibrary("opengl32"),
        .linux => exe.linkSystemLibrary("GL"),
        .macos => exe.linkFramework("OpenGL"),
        else => @panic("add OpenGL library for unknown OS"),
    }

    b.installArtifact(exe);
}
