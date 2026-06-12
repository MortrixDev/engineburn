const Texture = @import("../renderer/texture.zig").Texture;
const Handle = @import("../assets/assets.zig").Handle;
const Color = @import("../renderer/color.zig").Color;
const Rect = @import("../math/rect.zig").Rect;

pub const Sprite = struct {
    texture: Handle(Texture),
    src: Rect,
    tint: Color = Color.white,
    z: i32 = 0,
    visible: bool = true,
};
