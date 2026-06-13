const Transform = @import("../components/transform.zig").Transform;
const Vec2 = @import("../math/vec2.zig").Vec2;

pub const Camera = struct {
    transform: Transform = .{},
    zoom: f32 = 1.0,

    /// Converts a screen-space point (pixels, origin top-left) to world space,
    /// given the screen dimensions. Inverse of the 2D camera transform applied
    /// during rendering (offset to screen center, then rotate and zoom about
    /// the camera target).
    pub fn screenToWorld(self: Camera, screen: Vec2, screen_w: f32, screen_h: f32) Vec2 {
        const offset = Vec2{ .x = screen_w / 2, .y = screen_h / 2 };
        const centered = screen.sub(offset).scale(1.0 / self.zoom);
        const cos = @cos(-self.transform.rotation);
        const sin = @sin(-self.transform.rotation);
        const rotated = Vec2{
            .x = centered.x * cos - centered.y * sin,
            .y = centered.x * sin + centered.y * cos,
        };
        return rotated.add(self.transform.position);
    }
};
