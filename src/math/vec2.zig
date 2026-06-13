const std = @import("std");

pub const Vec2 = struct {
    x: f32,
    y: f32,

    pub const zero = Vec2{ .x = 0, .y = 0 };
    pub const one = Vec2{ .x = 1, .y = 1 };
    pub const up = Vec2{ .x = 0, .y = -1 };
    pub const down = Vec2{ .x = 0, .y = 1 };
    pub const left = Vec2{ .x = -1, .y = 0 };
    pub const right = Vec2{ .x = 1, .y = 0 };

    pub fn add(self: Vec2, other: Vec2) Vec2 {
        return .{ .x = self.x + other.x, .y = self.y + other.y };
    }

    pub fn sub(self: Vec2, other: Vec2) Vec2 {
        return .{ .x = self.x - other.x, .y = self.y - other.y };
    }

    pub fn scale(self: Vec2, s: f32) Vec2 {
        return .{ .x = self.x * s, .y = self.y * s };
    }

    pub fn mul(self: Vec2, other: Vec2) Vec2 {
        return .{ .x = self.x * other.x, .y = self.y * other.y };
    }

    pub fn rotate(self: Vec2, radians: f32) Vec2 {
        const c = @cos(radians);
        const s = @sin(radians);
        return .{ .x = self.x * c - self.y * s, .y = self.x * s + self.y * c };
    }

    pub fn negate(self: Vec2) Vec2 {
        return .{ .x = -self.x, .y = -self.y };
    }

    pub fn dot(self: Vec2, other: Vec2) f32 {
        return self.x * other.x + self.y * other.y;
    }

    pub fn lengthSquared(self: Vec2) f32 {
        return self.dot(self);
    }

    pub fn length(self: Vec2) f32 {
        return @sqrt(self.lengthSquared());
    }

    pub fn normalize(self: Vec2) Vec2 {
        const len = self.length();
        if (len == 0) return Vec2.zero;
        return self.scale(1.0 / len);
    }

    pub fn lerp(self: Vec2, other: Vec2, t: f32) Vec2 {
        return self.add(other.sub(self).scale(t));
    }

    pub fn distanceSquared(self: Vec2, other: Vec2) f32 {
        return self.sub(other).lengthSquared();
    }

    pub fn distance(self: Vec2, other: Vec2) f32 {
        return @sqrt(self.distanceSquared(other));
    }

    pub fn eql(self: Vec2, other: Vec2) bool {
        return self.x == other.x and self.y == other.y;
    }
};
