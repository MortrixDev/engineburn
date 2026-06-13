const std = @import("std");
const engineburn = @import("engineburn");
const Game = engineburn.Game;
const Transform = engineburn.Transform;
const Collider = engineburn.Collider;
const Vec2 = engineburn.Vec2;
const Color = engineburn.Color;
const renderer = engineburn.renderer;
const collision = engineburn.physics;

const SPEED: f32 = 250;
const SPIN: f32 = 1.5;

const Player = struct {};

const MyGame = Game(.{ Collider, Player });

const initial_obstacles = [_]collision.Body{
    .{
        .transform = .{ .position = .{ .x = 200, .y = 150 } },
        .collider = .{ .shape = .{ .rect = .{ .x = 40, .y = 40 } } },
    },
    .{
        .transform = .{ .position = .{ .x = -100, .y = 80 } },
        .collider = .{ .shape = .{ .rect = .{ .x = 60, .y = 25 } } },
    },
    .{
        .transform = .{ .position = .{ .x = 50, .y = -180 } },
        .collider = .{ .shape = .{ .rect = .{ .x = 30, .y = 60 } } },
    },
};

var obstacles = initial_obstacles;
var prev_obstacles = initial_obstacles;

fn fixed(game: *MyGame, dt: f32) void {
    prev_obstacles = obstacles;
    obstacles[0].transform.rotation += SPIN * dt;

    var iter = game.world.query(.{ Transform, Collider, Player });
    while (iter.next()) |r| {
        if (game.input.isKeyDown(.right)) r.Transform.position.x += SPEED * dt;
        if (game.input.isKeyDown(.left)) r.Transform.position.x -= SPEED * dt;
        if (game.input.isKeyDown(.down)) r.Transform.position.y += SPEED * dt;
        if (game.input.isKeyDown(.up)) r.Transform.position.y -= SPEED * dt;
    }
}

fn render(game: *MyGame, _: f32) void {
    var touching_index: ?usize = null;
    var iter = game.world.query(.{ Transform, Collider, Player });
    if (iter.next()) |r| {
        const body = collision.Body{ .transform = r.Transform.*, .collider = r.Collider.* };
        if (collision.IsCollidingMany(body, &obstacles)) |hit| touching_index = hit.index;
    }

    for (obstacles, 0..) |obs, i| {
        const color = if (touching_index == i) Color.green else Color.red;
        const xf = prev_obstacles[i].transform.lerp(obs.transform, game.interpolation);
        renderer.drawRect(obs.collider.shape.rect, xf, color);
    }

    var iter2 = game.world.query(.{ Transform, Collider, Player });
    while (iter2.next()) |r| {
        renderer.drawRect(r.Collider.shape.rect, game.interpolate(r.entity, r.Transform.*), Color.white);
    }
}

pub fn main(init: std.process.Init) !void {
    var game = MyGame.init(init.gpa, .{
        .title = "collision",
        .width = 800,
        .height = 600,
        .fixed_step_rate = 10,
    });
    defer game.deinit();

    _ = try game.world.spawn(.{
        Transform{ .position = .{ .x = 0, .y = 0 } },
        Collider{ .shape = .{ .rect = .{ .x = 32, .y = 32 } } },
        Player{},
    });

    try game.addFixed(fixed);
    try game.addRender(render);
    game.run(init.io);
}
