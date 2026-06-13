const std = @import("std");
const builtin = @import("builtin");

const Vec2 = @import("../math/vec2.zig").Vec2;
const Color = @import("../renderer/color.zig").Color;
const Transform = @import("../components/transform.zig").Transform;
const Collider = @import("../components/collider.zig").Collider;
const renderer = @import("../renderer/renderer.zig");
const Input = @import("../input/input.zig").Input;
const Key = @import("../input/input.zig").Key;

pub const enabled = builtin.mode == .Debug;

const Item = struct {
    kind: union(enum) {
        line: struct { a: Vec2, b: Vec2 },
        circle: struct { center: Vec2, radius: f32 },
        rect: struct { half: Vec2, transform: Transform },
    },
    color: Color,
};

pub const Debug = struct {
    draw_colliders: bool = false,
    collider_color: Color = Color.magenta,
    draw_transforms: bool = false,
    allocator: std.mem.Allocator,
    items: std.ArrayListUnmanaged(Item) = .empty,

    pub fn init(allocator: std.mem.Allocator) Debug {
        return .{ .allocator = allocator };
    }

    pub fn deinit(self: *Debug) void {
        self.items.deinit(self.allocator);
    }

    const toggles = [_]struct { key: Key, field: []const u8 }{
        .{ .key = .f1, .field = "draw_colliders" },
        .{ .key = .f2, .field = "draw_transforms" },
    };

    pub fn pollToggles(self: *Debug, in: *const Input) void {
        if (comptime !enabled) return;
        inline for (toggles) |t| {
            if (in.isKeyPressed(t.key)) @field(self, t.field) = !@field(self, t.field);
        }
    }

    pub fn line(self: *Debug, a: Vec2, b: Vec2, color: Color) void {
        if (comptime enabled)
            self.items.append(self.allocator, .{ .kind = .{ .line = .{ .a = a, .b = b } }, .color = color }) catch {};
    }

    pub fn circle(self: *Debug, center: Vec2, radius: f32, color: Color) void {
        if (comptime enabled)
            self.items.append(self.allocator, .{ .kind = .{ .circle = .{ .center = center, .radius = radius } }, .color = color }) catch {};
    }

    pub fn rect(self: *Debug, half: Vec2, transform: Transform, color: Color) void {
        if (comptime enabled)
            self.items.append(self.allocator, .{ .kind = .{ .rect = .{ .half = half, .transform = transform } }, .color = color }) catch {};
    }

    pub fn flush(self: *Debug) void {
        if (comptime !enabled) return;
        for (self.items.items) |item| switch (item.kind) {
            .line => |l| renderer.drawLine(l.a, l.b, 1.0, item.color),
            .circle => |c| renderer.drawCircleOutline(c.radius, .{ .position = c.center }, item.color),
            .rect => |r| renderer.drawRectOutline(r.half, r.transform, 1.0, item.color),
        };
        self.items.clearRetainingCapacity();
    }
};

fn worldPoint(transform: Transform, offset: Vec2, p: Vec2) Vec2 {
    return transform.position.add(offset.add(p).mul(transform.scale).rotate(transform.rotation));
}

const gizmo_screen_fraction = 0.04;

pub fn gizmoLength(screen_height: f32, zoom: f32) f32 {
    return screen_height / zoom * gizmo_screen_fraction;
}

pub fn drawTransform(transform: Transform, length: f32) void {
    if (comptime !enabled) return;
    const origin = transform.position;
    renderer.drawLine(origin, origin.add(Vec2.right.rotate(transform.rotation).scale(length)), 1.0, Color.red);
    renderer.drawLine(origin, origin.add(Vec2.down.rotate(transform.rotation).scale(length)), 1.0, Color.green);
}

pub fn drawCollider(collider: Collider, transform: Transform, color: Color) void {
    if (comptime !enabled) return;
    switch (collider.shape) {
        .circle => |radius| {
            const center = worldPoint(transform, collider.offset, Vec2.zero);
            renderer.drawCircleOutline(radius * transform.scale.x, .{ .position = center }, color);
        },
        .rect => |half| {
            const corners = [_]Vec2{
                worldPoint(transform, collider.offset, .{ .x = -half.x, .y = -half.y }),
                worldPoint(transform, collider.offset, .{ .x = half.x, .y = -half.y }),
                worldPoint(transform, collider.offset, .{ .x = half.x, .y = half.y }),
                worldPoint(transform, collider.offset, .{ .x = -half.x, .y = half.y }),
            };
            for (0..4) |i| renderer.drawLine(corners[i], corners[(i + 1) % 4], 1.0, color);
        },
        .polygon => |verts| {
            for (verts, 0..) |v, i| {
                const a = worldPoint(transform, collider.offset, v);
                const b = worldPoint(transform, collider.offset, verts[(i + 1) % verts.len]);
                renderer.drawLine(a, b, 1.0, color);
            }
        },
    }
}
