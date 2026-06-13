const Vec2 = @import("../math/vec2.zig").Vec2;

/// A collider's shape in local space, before the entity Transform and the
/// collider's own `offset` are applied.
pub const Shape = union(enum) {
    /// Radius.
    circle: f32,
    /// Half-extents (half width, half height), centered on the collider origin.
    rect: Vec2,
    /// Convex hull vertices in local space, wound counter-clockwise.
    polygon: []const Vec2,
};

pub const Collider = struct {
    shape: Shape,
    offset: Vec2 = Vec2.zero,
};
