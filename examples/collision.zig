const std = @import("std");
const engineburn = @import("engineburn");
const Game = engineburn.Game;
const Transform = engineburn.Transform;
const Collider = engineburn.Collider;
const FillShape = engineburn.FillShape;
const Color = engineburn.Color;
const collision = engineburn.physics;

const SPEED: f32 = 250;
const SPIN: f32 = 1.5;

const default_color = Color.hex(0xcf7a76);
const touch_color = Color.hex(0x76cf77);

pub const Player = struct {
    pub const is_component = {};
};
pub const Obstacle = struct {
    pub const is_component = {};
};

const MyGame = Game(.{});

fn fixed(game: *MyGame, dt: f32) void {
    var player_body: ?collision.Body = null;
    var players = game.world.query(.{ Transform, Collider, Player });
    while (players.next()) |r| {
        if (game.input.isKeyDown(.right)) r.Transform.position.x += SPEED * dt;
        if (game.input.isKeyDown(.left)) r.Transform.position.x -= SPEED * dt;
        if (game.input.isKeyDown(.down)) r.Transform.position.y += SPEED * dt;
        if (game.input.isKeyDown(.up)) r.Transform.position.y -= SPEED * dt;
        player_body = .{ .transform = r.Transform.*, .collider = r.Collider.* };
    }

    var obstacles = game.world.query(.{ Transform, Collider, FillShape, Obstacle });
    while (obstacles.next()) |r| {
        r.Transform.rotation += SPIN * dt;
        const body = collision.Body{ .transform = r.Transform.*, .collider = r.Collider.* };
        const touching = if (player_body) |pb| collision.IsColliding(pb, body) != null else false;
        r.FillShape.color = if (touching) touch_color else default_color;
    }
}

fn spawnBox(game: *MyGame, x: f32, y: f32, hw: f32, hh: f32, color: Color, marker: anytype) !void {
    _ = try game.world.spawn(.{
        Transform{ .position = .{ .x = x, .y = y } },
        Collider{ .shape = .{ .rect = .{ .x = hw, .y = hh } } },
        FillShape{ .shape = .{ .rect = .{ .x = hw, .y = hh } }, .color = color },
        marker,
    });
}

pub fn main(init: std.process.Init) !void {
    var game = MyGame.init(init.gpa, .{
        .title = "collision",
        .width = 800,
        .height = 600,
        .fixed_step_rate = 10,
    });
    defer game.deinit();

    try spawnBox(&game, 200, 150, 40, 40, default_color, Obstacle{});
    try spawnBox(&game, -100, 80, 60, 25, default_color, Obstacle{});
    try spawnBox(&game, 50, -180, 30, 60, default_color, Obstacle{});
    try spawnBox(&game, 0, 0, 32, 32, Color.hex(0x68a6cc), Player{});

    try game.addFixed(fixed);
    game.run(init.io);
}
