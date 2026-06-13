const Vec2 = @import("../math/vec2.zig").Vec2;
const Shape = @import("shape.zig").Shape;

pub const Collider = struct {
    shape: Shape,
    offset: Vec2 = Vec2.zero,
};
