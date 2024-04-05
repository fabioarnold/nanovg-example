const std = @import("std");
const nvg = @import("nanovg");
const c = @cImport({
    @cInclude("glad/glad.h");
    @cInclude("SDL2/SDL.h");
});

var vg: nvg = undefined;

const window_width = 1000;
const window_height = 600;

const ts = 32;
const ncols = 15;
const nrows = 12;
const nzrows = 5;

const ball_r = 100;
var ball_x: f32 = 0;
var ball_y: f32 = 0;
var ball_vx: f32 = 100;
var ball_vy: f32 = 200;
var ball_a: f32 = 0;
var ball_va: f32 = 1;

const max_x = persp(ts * ncols / 2, nzrows / 2) - ball_r;
const max_y = persp(ts * nrows / 2, nzrows / 2) - ball_r;

fn persp(x: f32, z: f32) f32 {
    const w = 1 - z * 0.04;
    return x / w;
}

fn drawGrid() void {
    const th = 1;

    vg.save();
    defer vg.restore();

    vg.strokeWidth(2 * th);
    vg.strokeColor(nvg.rgb(0x9B, 0x1E, 0xA4));

    { // wall
        vg.save();
        defer vg.restore();
        vg.beginPath();
        vg.translate(-0.5 * ts * ncols, -0.5 * ts * nrows);
        vg.rect(0, 0, ts * ncols, ts * nrows);
        vg.translate(ts, 0);
        for (1..ncols) |_| {
            vg.moveTo(0, 0);
            vg.lineTo(0, ts * nrows);
            vg.translate(ts, 0);
        }
        vg.translate(-ts * ncols, 0);
        vg.translate(0, ts);
        for (1..nrows) |_| {
            vg.moveTo(0, 0);
            vg.lineTo(ts * ncols, 0);
            vg.translate(0, ts);
        }
        vg.stroke();
    }

    { // floor
        vg.beginPath();
        for (0..nzrows + 1) |zi| {
            const z: f32 = @floatFromInt(zi);
            const x = persp(0.5 * ts * ncols, z);
            const y = persp(0.5 * ts * nrows, z);
            vg.moveTo(-x, y);
            vg.lineTo(x, y);
        }
        for (0..ncols + 1) |xi| {
            const xf: f32 = @floatFromInt(xi);
            const x = xf * ts - 0.5 * ts * ncols;
            const y = 0.5 * ts * nrows;
            vg.moveTo(x, y);
            vg.lineTo(persp(x, nzrows), persp(y, nzrows));
        }
        vg.stroke();
    }
}

fn drawBall(r: f32, t: f32) void {
    const w = 16;
    const h = 8;

    for (0..h) |yi| {
        const theta0 = @as(f32, @floatFromInt(yi)) / h * std.math.pi;
        const theta1 = @as(f32, @floatFromInt(yi + 1)) / h * std.math.pi;
        const y0 = @cos(theta0) * r;
        const y1 = @cos(theta1) * r;
        const r0 = @sin(theta0) * r;
        const r1 = @sin(theta1) * r;
        for (0..w) |xi| {
            const s0 = @sin(@as(f32, @floatFromInt(xi)) / w * 2 * std.math.pi + t);
            const s1 = @sin(@as(f32, @floatFromInt(xi + 1)) / w * 2 * std.math.pi + t);
            if (s0 >= s1) continue;
            vg.beginPath();
            vg.moveTo(s0 * r0, y0);
            vg.lineTo(s1 * r0, y0);
            vg.lineTo(s1 * r1, y1);
            vg.lineTo(s0 * r1, y1);
            vg.closePath();
            vg.fillColor(if ((xi + yi) % 2 == 0) nvg.rgbf(1, 0, 0) else nvg.rgbf(1, 1, 1));
            vg.fill();
        }
    }
}

fn drawBallShadow(r: f32) void {
    const n = 16;
    vg.beginPath();
    vg.moveTo(r, 0);
    for (1..n) |i| {
        const alpha = @as(f32, @floatFromInt(i)) / n * 2 * std.math.pi;
        vg.lineTo(r * @cos(alpha), r * @sin(alpha));
    }
    vg.closePath();
    vg.fillColor(nvg.rgbaf(0, 0, 0, 0.3));
    vg.fill();
}

pub fn main() !void {
    if (c.SDL_Init(c.SDL_INIT_VIDEO) < 0) {
        return error.SDLInitFailed;
    }
    defer c.SDL_Quit();

    _ = c.SDL_GL_SetAttribute(c.SDL_GL_CONTEXT_MAJOR_VERSION, 2);
    _ = c.SDL_GL_SetAttribute(c.SDL_GL_CONTEXT_MINOR_VERSION, 0);
    _ = c.SDL_GL_SetAttribute(c.SDL_GL_STENCIL_SIZE, 1);
    _ = c.SDL_GL_SetAttribute(c.SDL_GL_MULTISAMPLEBUFFERS, 1);
    _ = c.SDL_GL_SetAttribute(c.SDL_GL_MULTISAMPLESAMPLES, 4);

    const window = c.SDL_CreateWindow(
        "NanoVG",
        c.SDL_WINDOWPOS_UNDEFINED,
        c.SDL_WINDOWPOS_UNDEFINED,
        window_width,
        window_height,
        c.SDL_WINDOW_OPENGL | c.SDL_WINDOW_ALLOW_HIGHDPI,
    );
    if (window == null) {
        return error.SDLCreateWindowFailed;
    }
    defer c.SDL_DestroyWindow(window);

    const context = c.SDL_GL_CreateContext(window);
    if (context == null) {
        return error.SDLGLCreateContextFailed;
    }
    defer c.SDL_GL_DeleteContext(context);

    _ = c.SDL_GL_SetSwapInterval(1);

    if (c.gladLoadGL() == 0) {
        return error.GLADLoadGLFailed;
    }

    const allocator = std.heap.c_allocator;
    vg = try nvg.gl.init(allocator, .{
        .debug = true,
    });
    defer vg.deinit();

    _ = vg.createFontMem("times", @embedFile("fonts/times new roman.ttf"));

    var prevt = std.time.nanoTimestamp();

    var quit = false;
    while (!quit) {
        var event: c.SDL_Event = undefined;
        while (c.SDL_PollEvent(&event) != 0) {
            switch (event.type) {
                c.SDL_QUIT => quit = true,
                c.SDL_KEYDOWN => quit = event.key.keysym.sym == c.SDLK_ESCAPE,
                else => {},
            }
        }

        const t = std.time.nanoTimestamp();
        const dt: f32 = @as(f32, @floatFromInt(t - prevt)) / std.time.ns_per_s;
        prevt = t;

        ball_x += dt * ball_vx;
        ball_y += dt * ball_vy;
        ball_a += dt * ball_va;
        if (ball_x > max_x or ball_x < -max_x) {
            ball_x = std.math.sign(ball_vx) * max_x;
            ball_vx *= -1;
            ball_va *= -1;
        }
        if (ball_y > max_y or ball_y < -max_y) {
            ball_y = std.math.sign(ball_vy) * max_y;
            ball_vy *= -1;
        }
        // map to flight path
        var ball_yy = ball_y / (2 * max_y) + 0.5;
        ball_yy *= ball_yy;
        ball_yy = (ball_yy - 0.5) * 2 * max_y;

        c.glClearColor(0.667, 0.667, 0.667, 1);
        c.glClear(c.GL_COLOR_BUFFER_BIT | c.GL_STENCIL_BUFFER_BIT);

        vg.beginFrame(window_width, window_height, 2);
        vg.translate(0.5 * window_width, 0.5 * window_height);
        drawGrid();

        vg.translate(ball_x, ball_yy);
        {
            vg.save();
            defer vg.restore();
            vg.translate(50, 0);
            vg.rotate(std.math.degreesToRadians(15));
            drawBallShadow(ball_r);
        }
        vg.rotate(std.math.degreesToRadians(15));
        drawBall(ball_r, ball_a);

        vg.resetTransform();
        vg.fontFace("times");
        vg.fontSize(50);
        vg.textAlign(.{ .horizontal = .right, .vertical = .bottom });
        vg.translate(window_width - 20, window_height - 10);
        vg.skewX(-0.25); // poor man's italic
        vg.fillColor(nvg.rgbaf(0, 0, 0, 0.4));
        _ = vg.text(4, 2, "NanoVG");
        vg.fillColor(nvg.rgbf(0, 0, 0));
        _ = vg.text(0, 0, "NanoVG");

        vg.endFrame();
        c.SDL_GL_SwapWindow(window);
    }
}
