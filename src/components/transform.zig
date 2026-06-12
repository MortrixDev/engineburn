const Vec2 = @import("../math/vec2.zig").Vec2;

pub const Transform = struct {
    position: Vec2 = Vec2.zero,
    rotation: f32 = 0,
    scale: Vec2 = Vec2.one,
};
