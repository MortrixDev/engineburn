const Shape = @import("shape.zig").Shape;
const Color = @import("../renderer/color.zig").Color;

pub const FillShape = struct {
    shape: Shape,
    color: Color,
    z: i32 = 0,
    visible: bool = true,
};
