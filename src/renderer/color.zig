const std = @import("std");

pub const Color = struct {
    r: u8,
    g: u8,
    b: u8,
    a: u8 = 255,

    pub fn rgb(r: u8, g: u8, b: u8) Color {
        return .{ .r = r, .g = g, .b = b };
    }

    pub fn rgba(r: u8, g: u8, b: u8, a: u8) Color {
        return .{ .r = r, .g = g, .b = b, .a = a };
    }

    // 0xRRGGBB
    pub fn hex(hex_color: u24) Color {
        return .{
            .r = @intCast((hex_color >> 16) & 0xFF),
            .g = @intCast((hex_color >> 8) & 0xFF),
            .b = @intCast(hex_color & 0xFF),
        };
    }

    // 0xRRGGBBAA
    pub fn hexa(hex_color: u32) Color {
        return .{
            .r = @intCast((hex_color >> 24) & 0xFF),
            .g = @intCast((hex_color >> 16) & 0xFF),
            .b = @intCast((hex_color >> 8) & 0xFF),
            .a = @intCast(hex_color & 0xFF),
        };
    }

    pub fn norm(r: f32, g: f32, b: f32, a: f32) Color {
        return .{
            .r = @intFromFloat(@round(std.math.clamp(r, 0, 1) * 255)),
            .g = @intFromFloat(@round(std.math.clamp(g, 0, 1) * 255)),
            .b = @intFromFloat(@round(std.math.clamp(b, 0, 1) * 255)),
            .a = @intFromFloat(@round(std.math.clamp(a, 0, 1) * 255)),
        };
    }

    pub const white = Color.hex(0xFFFFFF);
    pub const black = Color.hex(0x000000);
    pub const red = Color.hex(0xFF0000);
    pub const green = Color.hex(0x00FF00);
    pub const blue = Color.hex(0x0000FF);
    pub const magenta = Color.hex(0xFF00FF);
    pub const transparent = Color.hexa(0x00000000);
};
