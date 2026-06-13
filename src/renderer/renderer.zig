const Vec2 = @import("../math/vec2.zig").Vec2;
const Rect = @import("../math/rect.zig").Rect;
const Transform = @import("../components/transform.zig").Transform;
const Color = @import("color.zig").Color;
const Texture = @import("texture.zig").Texture;
const raylib = @import("../raylib.zig");

pub fn drawRect(half: Vec2, transform: Transform, color: Color) void {
    raylib.drawRect(half, transform, color);
}

pub fn drawRectOutline(half: Vec2, transform: Transform, thickness: f32, color: Color) void {
    raylib.drawRectOutline(half, transform, thickness, color);
}

pub fn drawCircle(radius: f32, transform: Transform, color: Color) void {
    raylib.drawCircle(radius, transform, color);
}

pub fn drawCircleOutline(radius: f32, transform: Transform, color: Color) void {
    raylib.drawCircleOutline(radius, transform, color);
}

pub fn drawLine(a: Vec2, b: Vec2, thickness: f32, color: Color) void {
    raylib.drawLine(a, b, thickness, color);
}

/// Draws `texture` from `src` into a rect of half-extents `half` at
/// `transform.position`, scaled by `transform.scale` and rotated by
/// `transform.rotation` (radians) about the center.
pub fn drawTexture(texture: Texture, src: Rect, half: Vec2, transform: Transform, tint: Color) void {
    raylib.drawTexture(texture.handle, src, half, transform, tint);
}
