const Vec2 = @import("../math/vec2.zig").Vec2;
const Rect = @import("../math/rect.zig").Rect;
const Color = @import("color.zig").Color;
const Texture = @import("texture.zig").Texture;
const raylib = @import("../raylib.zig");

pub fn drawRect(rect: Rect, color: Color) void {
    raylib.drawRect(rect, color);
}

pub fn drawRectOutline(rect: Rect, thickness: f32, color: Color) void {
    raylib.drawRectOutline(rect, thickness, color);
}

pub fn drawCircle(center: Vec2, radius: f32, color: Color) void {
    raylib.drawCircle(center, radius, color);
}

pub fn drawCircleOutline(center: Vec2, radius: f32, color: Color) void {
    raylib.drawCircleOutline(center, radius, color);
}

pub fn drawLine(a: Vec2, b: Vec2, thickness: f32, color: Color) void {
    raylib.drawLine(a, b, thickness, color);
}

/// Draws `texture` from `src` into `dst`. `origin` is the pivot, expressed in
/// `dst` (post-scale) coordinates relative to its top-left; `rotation` is in
/// degrees about that pivot.
pub fn drawTexture(texture: Texture, src: Rect, dst: Rect, origin: Vec2, rotation: f32, tint: Color) void {
    raylib.drawTexture(texture.handle, src, dst, origin, rotation, tint);
}
