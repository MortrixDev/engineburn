const Vec2 = @import("../math/vec2.zig").Vec2;

pub const Shape = union(enum) {
    circle: f32,
    rect: Vec2,
    polygon: []const Vec2,
};
