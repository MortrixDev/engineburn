const Vec2 = @import("../math/vec2.zig").Vec2;
const raylib = @import("../raylib.zig");

pub const Key = enum(i32) {
    space = 32,
    apostrophe = 39,
    comma = 44,
    minus = 45,
    period = 46,
    slash = 47,
    zero = 48,
    one = 49,
    two = 50,
    three = 51,
    four = 52,
    five = 53,
    six = 54,
    seven = 55,
    eight = 56,
    nine = 57,
    semicolon = 59,
    equal = 61,
    a = 65,
    b = 66,
    c = 67,
    d = 68,
    e = 69,
    f = 70,
    g = 71,
    h = 72,
    i = 73,
    j = 74,
    k = 75,
    l = 76,
    m = 77,
    n = 78,
    o = 79,
    p = 80,
    q = 81,
    r = 82,
    s = 83,
    t = 84,
    u = 85,
    v = 86,
    w = 87,
    x = 88,
    y = 89,
    z = 90,
    escape = 256,
    enter = 257,
    tab = 258,
    backspace = 259,
    insert = 260,
    delete = 261,
    right = 262,
    left = 263,
    down = 264,
    up = 265,
    page_up = 266,
    page_down = 267,
    home = 268,
    end = 269,
    caps_lock = 280,
    f1 = 290,
    f2 = 291,
    f3 = 292,
    f4 = 293,
    f5 = 294,
    f6 = 295,
    f7 = 296,
    f8 = 297,
    f9 = 298,
    f10 = 299,
    f11 = 300,
    f12 = 301,
    left_shift = 340,
    left_ctrl = 341,
    left_alt = 342,
    right_shift = 344,
    right_ctrl = 345,
    right_alt = 346,
};

pub const MouseButton = enum(i32) {
    left = 0,
    right = 1,
    middle = 2,
};

pub fn isKeyDown(key: Key) bool {
    return raylib.isKeyDown(@intFromEnum(key));
}

pub fn isKeyPressed(key: Key) bool {
    return raylib.isKeyPressed(@intFromEnum(key));
}

pub fn isKeyReleased(key: Key) bool {
    return raylib.isKeyReleased(@intFromEnum(key));
}

pub fn isMouseDown(button: MouseButton) bool {
    return raylib.isMouseButtonDown(@intFromEnum(button));
}

pub fn isMousePressed(button: MouseButton) bool {
    return raylib.isMouseButtonPressed(@intFromEnum(button));
}

pub fn isMouseReleased(button: MouseButton) bool {
    return raylib.isMouseButtonReleased(@intFromEnum(button));
}

pub fn mousePos() Vec2 {
    return raylib.getMousePosition();
}

pub fn mouseDelta() Vec2 {
    return raylib.getMouseDelta();
}

pub fn mouseWheel() f32 {
    return raylib.getMouseWheelMove();
}
