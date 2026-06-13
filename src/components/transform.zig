const std = @import("std");
const Vec2 = @import("../math/vec2.zig").Vec2;

pub const Transform = struct {
    position: Vec2 = Vec2.zero,
    rotation: f32 = 0,
    scale: Vec2 = Vec2.one,

    pub fn lerp(self: Transform, other: Transform, t: f32) Transform {
        const delta = @mod(other.rotation - self.rotation + std.math.pi, 2.0 * std.math.pi) - std.math.pi;
        return .{
            .position = self.position.lerp(other.position, t),
            .rotation = self.rotation + delta * t,
            .scale = self.scale.lerp(other.scale, t),
        };
    }
};
