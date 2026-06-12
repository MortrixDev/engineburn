const std = @import("std");
const engineburn = @import("engineburn");
const Game = engineburn.game.Game;
const Sprite = engineburn.components.Sprite;
const Transform = engineburn.components.Transform;
const Color = engineburn.renderer.Color;

const MyGame = Game(.{Sprite});

pub fn main(init: std.process.Init) !void {
    var game = MyGame.init(init.gpa, .{
        .title = "sprites",
        .width = 800,
        .height = 600,
    });
    defer game.deinit();

    const tex = try game.assets.textures.load(init.io, "examples/assets/bricks.png");
    _ = try game.world.spawn(.{
        Sprite{ .texture = tex, .src = .{ .x = 0, .y = 0, .w = 16, .h = 16 } },
        Transform{
            .position = .{ .x = -32, .y = -32 },
            .scale = .{ .x = 4, .y = 4 },
        },
    });

    game.run(init.io);
}
