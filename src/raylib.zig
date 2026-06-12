const c = @cImport({
    @cInclude("raylib.h");
});

const Vec2 = @import("math/vec2.zig").Vec2;
const Rect = @import("math/rect.zig").Rect;
const Color = @import("renderer/color.zig").Color;

pub const RawTexture = c.Texture2D;

fn rlColor(color: Color) c.Color {
    return .{ .r = color.r, .g = color.g, .b = color.b, .a = color.a };
}

fn rlRect(rect: Rect) c.Rectangle {
    return .{ .x = rect.x, .y = rect.y, .width = rect.w, .height = rect.h };
}

fn rlVec2(v: Vec2) c.Vector2 {
    return .{ .x = v.x, .y = v.y };
}

pub fn initWindow(width: i32, height: i32, title: [:0]const u8) void {
    c.InitWindow(width, height, title);
}

pub fn closeWindow() void {
    c.CloseWindow();
}

pub fn windowShouldClose() bool {
    return c.WindowShouldClose();
}

pub fn getFrameTime() f32 {
    return c.GetFrameTime();
}

pub fn beginDrawing() void {
    c.BeginDrawing();
}

pub fn endDrawing() void {
    c.EndDrawing();
}

pub fn clearBackground(color: Color) void {
    c.ClearBackground(rlColor(color));
}

pub fn loadTexture(path: [:0]const u8) RawTexture {
    const handle = c.LoadTexture(path);
    c.SetTextureFilter(handle, c.TEXTURE_FILTER_POINT);
    return handle;
}

pub fn unloadTexture(texture: RawTexture) void {
    c.UnloadTexture(texture);
}

pub fn drawRect(rect: Rect, color: Color) void {
    c.DrawRectangleRec(rlRect(rect), rlColor(color));
}

pub fn drawRectOutline(rect: Rect, thickness: f32, color: Color) void {
    c.DrawRectangleLinesEx(rlRect(rect), thickness, rlColor(color));
}

pub fn drawCircle(center: Vec2, radius: f32, color: Color) void {
    c.DrawCircleV(rlVec2(center), radius, rlColor(color));
}

pub fn drawCircleOutline(center: Vec2, radius: f32, color: Color) void {
    c.DrawCircleLinesV(rlVec2(center), radius, rlColor(color));
}

pub fn drawLine(a: Vec2, b: Vec2, thickness: f32, color: Color) void {
    c.DrawLineEx(rlVec2(a), rlVec2(b), thickness, rlColor(color));
}

pub fn drawTexture(texture: RawTexture, src: Rect, dst: Rect, origin: Vec2, rotation: f32, tint: Color) void {
    c.DrawTexturePro(texture, rlRect(src), rlRect(dst), rlVec2(origin), rotation, rlColor(tint));
}

pub fn isKeyDown(key: i32) bool {
    return c.IsKeyDown(key);
}

pub fn isKeyPressed(key: i32) bool {
    return c.IsKeyPressed(key);
}

pub fn isKeyReleased(key: i32) bool {
    return c.IsKeyReleased(key);
}

pub fn isMouseButtonDown(button: i32) bool {
    return c.IsMouseButtonDown(button);
}

pub fn isMouseButtonPressed(button: i32) bool {
    return c.IsMouseButtonPressed(button);
}

pub fn isMouseButtonReleased(button: i32) bool {
    return c.IsMouseButtonReleased(button);
}

pub fn getMousePosition() Vec2 {
    const v = c.GetMousePosition();
    return .{ .x = v.x, .y = v.y };
}

pub fn getMouseDelta() Vec2 {
    const v = c.GetMouseDelta();
    return .{ .x = v.x, .y = v.y };
}

pub fn getMouseWheelMove() f32 {
    return c.GetMouseWheelMove();
}

pub fn beginCamera2D(target: Vec2, rotation: f32, zoom: f32, screen_w: f32, screen_h: f32) void {
    c.BeginMode2D(.{
        .offset = .{ .x = screen_w / 2.0, .y = screen_h / 2.0 },
        .target = rlVec2(target),
        .rotation = rotation,
        .zoom = zoom,
    });
}

pub fn endCamera2D() void {
    c.EndMode2D();
}
