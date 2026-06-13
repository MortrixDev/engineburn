const std = @import("std");
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

const KEY_COUNT = blk: {
    var max: comptime_int = 0;
    for (std.meta.fields(Key)) |field| {
        if (field.value > max) max = field.value;
    }
    break :blk max + 1;
};
const BUTTON_COUNT = std.meta.fields(MouseButton).len;

const KeySet = std.StaticBitSet(KEY_COUNT);
const ButtonSet = std.StaticBitSet(BUTTON_COUNT);

pub const Input = struct {
    keys_down: KeySet = KeySet.initEmpty(),
    keys_pressed: KeySet = KeySet.initEmpty(),
    keys_released: KeySet = KeySet.initEmpty(),
    buttons_down: ButtonSet = ButtonSet.initEmpty(),
    buttons_pressed: ButtonSet = ButtonSet.initEmpty(),
    buttons_released: ButtonSet = ButtonSet.initEmpty(),
    mouse_position: Vec2 = Vec2.zero,
    mouse_delta: Vec2 = Vec2.zero,
    wheel: f32 = 0,

    pub fn isKeyDown(self: *const Input, key: Key) bool {
        return self.keys_down.isSet(@intCast(@intFromEnum(key)));
    }

    pub fn isKeyPressed(self: *const Input, key: Key) bool {
        return self.keys_pressed.isSet(@intCast(@intFromEnum(key)));
    }

    pub fn isKeyReleased(self: *const Input, key: Key) bool {
        return self.keys_released.isSet(@intCast(@intFromEnum(key)));
    }

    pub fn isMouseDown(self: *const Input, button: MouseButton) bool {
        return self.buttons_down.isSet(@intCast(@intFromEnum(button)));
    }

    pub fn isMousePressed(self: *const Input, button: MouseButton) bool {
        return self.buttons_pressed.isSet(@intCast(@intFromEnum(button)));
    }

    pub fn isMouseReleased(self: *const Input, button: MouseButton) bool {
        return self.buttons_released.isSet(@intCast(@intFromEnum(button)));
    }

    pub fn mousePos(self: *const Input) Vec2 {
        return self.mouse_position;
    }

    pub fn mouseDelta(self: *const Input) Vec2 {
        return self.mouse_delta;
    }

    pub fn mouseWheel(self: *const Input) f32 {
        return self.wheel;
    }
};

pub const Accumulator = struct {
    keys_down: KeySet = KeySet.initEmpty(),
    keys_pressed: KeySet = KeySet.initEmpty(),
    keys_released: KeySet = KeySet.initEmpty(),
    buttons_down: ButtonSet = ButtonSet.initEmpty(),
    buttons_pressed: ButtonSet = ButtonSet.initEmpty(),
    buttons_released: ButtonSet = ButtonSet.initEmpty(),
    mouse_position: Vec2 = Vec2.zero,
    wheel: f32 = 0,

    pub fn poll(self: *Accumulator) void {
        inline for (std.meta.fields(Key)) |field| {
            self.keys_down.setValue(field.value, raylib.isKeyDown(field.value));
            if (raylib.isKeyPressed(field.value)) self.keys_pressed.set(field.value);
            if (raylib.isKeyReleased(field.value)) self.keys_released.set(field.value);
        }
        inline for (std.meta.fields(MouseButton)) |field| {
            self.buttons_down.setValue(field.value, raylib.isMouseButtonDown(field.value));
            if (raylib.isMouseButtonPressed(field.value)) self.buttons_pressed.set(field.value);
            if (raylib.isMouseButtonReleased(field.value)) self.buttons_released.set(field.value);
        }
        self.mouse_position = raylib.getMousePosition();
        self.wheel += raylib.getMouseWheelMove();
    }

    pub fn consume(self: *Accumulator, last_mouse: Vec2) Input {
        const snapshot = Input{
            .keys_down = self.keys_down.unionWith(self.keys_pressed),
            .keys_pressed = self.keys_pressed,
            .keys_released = self.keys_released,
            .buttons_down = self.buttons_down.unionWith(self.buttons_pressed),
            .buttons_pressed = self.buttons_pressed,
            .buttons_released = self.buttons_released,
            .mouse_position = self.mouse_position,
            .mouse_delta = self.mouse_position.sub(last_mouse),
            .wheel = self.wheel,
        };
        self.keys_pressed = KeySet.initEmpty();
        self.keys_released = KeySet.initEmpty();
        self.buttons_pressed = ButtonSet.initEmpty();
        self.buttons_released = ButtonSet.initEmpty();
        self.wheel = 0;
        return snapshot;
    }
};
