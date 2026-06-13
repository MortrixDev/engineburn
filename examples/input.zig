const std = @import("std");
const engineburn = @import("engineburn");
const Game = engineburn.Game;
const Sprite = engineburn.Sprite;
const Transform = engineburn.Transform;

const SPEED: f32 = 200;

const MyGame = Game(.{Sprite});

fn fixed(game: *MyGame, dt: f32) void {
    var iter = game.world.query(.{Transform});
    while (iter.next()) |r| {
        if (game.input.isKeyDown(.right)) r.Transform.position.x += SPEED * dt;
        if (game.input.isKeyDown(.left)) r.Transform.position.x -= SPEED * dt;
        if (game.input.isKeyDown(.down)) r.Transform.position.y += SPEED * dt;
        if (game.input.isKeyDown(.up)) r.Transform.position.y -= SPEED * dt;
    }
}

pub fn main(init: std.process.Init) !void {
    var game = MyGame.init(init.gpa, .{
        .title = "input",
        .width = 800,
        .height = 600,
    });
    defer game.deinit();

    const tex = try game.assets.textures.load(init.io, "examples/assets/player.png");
    _ = try game.world.spawn(.{
        Sprite{ .texture = tex, .src = .{ .x = 0, .y = 0, .w = 16, .h = 16 } },
        Transform{
            .position = .{ .x = -32, .y = -32 },
            .scale = .{ .x = 4, .y = 4 },
        },
    });

    try game.addFixed(fixed);
    game.run(init.io);
}
