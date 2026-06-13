const std = @import("std");
const raylib = @import("../raylib.zig");

const Transform = @import("../components/transform.zig").Transform;
const Sprite = @import("../components/sprite.zig").Sprite;
const Collider = @import("../components/collider.zig").Collider;
const FillShape = @import("../components/fill_shape.zig").FillShape;
const Vec2 = @import("../math/vec2.zig").Vec2;
const Color = @import("../renderer/color.zig").Color;
const renderer = @import("../renderer/renderer.zig");
const Assets = @import("../assets/assets.zig").Assets;
const Camera = @import("camera.zig").Camera;
const input = @import("../input/input.zig");
const SparseSet = @import("../core/sparse_set.zig").SparseSet;
const Entity = @import("../ecs/world.zig").Entity;
const debug = @import("../debug/debug.zig");

// Upper bound on a single frame's delta. Without it, one long frame (a window
// drag, a breakpoint, a disk stall) would queue many fixed steps that take
// longer than real time to run, spiralling the accumulator away forever.
const MAX_FRAME_TIME: f32 = 0.25;

pub const GameConfig = struct {
    title: [:0]const u8,
    width: i32,
    height: i32,
    fixed_step_rate: f32 = 60,
};

fn containsType(comptime types: []const type, comptime T: type) bool {
    inline for (types) |U| {
        if (U == T) return true;
    }
    return false;
}

fn componentTypes(comptime user_components: anytype) []const type {
    const fields = std.meta.fields(@TypeOf(user_components));
    comptime var buf: [fields.len + 1]type = undefined;
    comptime var n: usize = 1;
    buf[0] = Transform;
    inline for (fields) |field| {
        const T = @field(user_components, field.name);
        if (!containsType(buf[0..n], T)) {
            buf[n] = T;
            n += 1;
        }
    }
    const final = buf[0..n].*;
    return &final;
}

pub fn Game(comptime user_components: anytype) type {
    const components = comptime componentTypes(user_components);
    const has_sprite = comptime containsType(components, Sprite);
    const has_collider = comptime containsType(components, Collider);
    const has_fill_shape = comptime containsType(components, FillShape);
    const WorldType = @import("../ecs/world.zig").World(components);

    return struct {
        const Self = @This();
        pub const World = WorldType;
        pub const Handler = *const fn (*Self, f32) void;

        const RenderItem = struct {
            z: i32,
            transform: Transform,
            payload: union(enum) {
                sprite: *Sprite,
                fill_shape: *FillShape,
            },
        };

        /// Records the current transform of every renderable entity so the next
        /// render can interpolate from it. Called once per fixed tick, before
        /// the handlers mutate state, so the snapshot is the tick's start state.
        fn snapshotTransforms(self: *Self) void {
            var iter = self.world.query(.{Transform});
            while (iter.next()) |r| {
                self.prev_transforms.add(self.allocator, r.entity, r.Transform.*) catch {};
            }
        }

        /// Blends `current` with the entity's transform at the start of the most
        /// recent fixed tick, by `self.interpolation`, to produce the transform
        /// to render this frame. Entities with no recorded previous state (never
        /// ticked, or not renderable) fall back to `current`.
        pub fn interpolate(self: *Self, entity: Entity, current: Transform) Transform {
            const prev = self.prev_transforms.get(entity) orelse return current;
            return prev.lerp(current, self.interpolation);
        }

        fn renderEntities(self: *Self) void {
            self.render_buffer.clearRetainingCapacity();

            if (comptime has_sprite) {
                var iter = self.world.query(.{ Sprite, Transform });
                while (iter.next()) |r| {
                    if (!r.Sprite.visible) continue;
                    self.render_buffer.append(self.allocator, .{
                        .z = r.Sprite.z,
                        .transform = self.interpolate(r.entity, r.Transform.*),
                        .payload = .{ .sprite = r.Sprite },
                    }) catch continue;
                }
            }

            if (comptime has_fill_shape) {
                var iter = self.world.query(.{ FillShape, Transform });
                while (iter.next()) |r| {
                    if (!r.FillShape.visible) continue;
                    self.render_buffer.append(self.allocator, .{
                        .z = r.FillShape.z,
                        .transform = self.interpolate(r.entity, r.Transform.*),
                        .payload = .{ .fill_shape = r.FillShape },
                    }) catch continue;
                }
            }

            std.mem.sort(RenderItem, self.render_buffer.items, {}, struct {
                fn lt(_: void, a: RenderItem, b: RenderItem) bool {
                    return a.z < b.z;
                }
            }.lt);

            for (self.render_buffer.items) |item| {
                switch (item.payload) {
                    .sprite => |s| {
                        const half = Vec2{ .x = s.src.w / 2.0, .y = s.src.h / 2.0 };
                        renderer.drawTexture(self.assets.textures.get(s.texture).*, s.src, half, item.transform, s.tint);
                    },
                    .fill_shape => |f| switch (f.shape) {
                        .rect => |half| renderer.drawRect(half, item.transform, f.color),
                        .circle => |radius| renderer.drawCircle(radius, item.transform, f.color),
                        .polygon => |verts| renderer.drawPolygon(verts, item.transform, f.color),
                    },
                }
            }
        }

        world: World,
        assets: Assets,
        config: GameConfig,
        allocator: std.mem.Allocator,
        camera: Camera = .{},
        input: input.Input = .{},
        interpolation: f32 = 0,
        on_fixed: std.ArrayListUnmanaged(Handler) = .empty,
        on_update: std.ArrayListUnmanaged(Handler) = .empty,
        on_render: std.ArrayListUnmanaged(Handler) = .empty,
        render_buffer: std.ArrayListUnmanaged(RenderItem) = .empty,
        prev_transforms: SparseSet(Transform) = .{},
        debug: debug.Debug,

        pub fn init(allocator: std.mem.Allocator, config: GameConfig) Self {
            raylib.initWindow(config.width, config.height, config.title);
            return .{
                .world = World.init(allocator),
                .assets = Assets.init(allocator),
                .config = config,
                .allocator = allocator,
                .debug = debug.Debug.init(allocator),
            };
        }

        pub fn deinit(self: *Self) void {
            self.world.deinit();
            self.assets.deinit();
            self.on_fixed.deinit(self.allocator);
            self.on_update.deinit(self.allocator);
            self.on_render.deinit(self.allocator);
            self.render_buffer.deinit(self.allocator);
            self.prev_transforms.deinit(self.allocator);
            self.debug.deinit();
            raylib.closeWindow();
        }

        /// Converts a screen-space point (pixels, origin top-left) to world space
        /// using the active camera and the configured window size. Handy for
        /// turning the mouse position into world coordinates.
        pub fn screenToWorld(self: *Self, screen: Vec2) Vec2 {
            return self.camera.screenToWorld(
                screen,
                @floatFromInt(self.config.width),
                @floatFromInt(self.config.height),
            );
        }

        pub fn addFixed(self: *Self, handler: Handler) !void {
            try self.on_fixed.append(self.allocator, handler);
        }

        pub fn addUpdate(self: *Self, handler: Handler) !void {
            try self.on_update.append(self.allocator, handler);
        }

        pub fn addRender(self: *Self, handler: Handler) !void {
            try self.on_render.append(self.allocator, handler);
        }

        /// Advances the simulation by exactly one fixed tick. Deterministic: it
        /// reads only `self.world`, `self.input`, and the registered fixed
        /// handlers, never raylib or wall-clock time, so it can be driven
        /// headlessly for replays and determinism tests. `self.input` must hold
        /// the tick's input snapshot before calling.
        pub fn stepFixed(self: *Self) void {
            const fixed_dt = 1.0 / self.config.fixed_step_rate;
            for (self.on_fixed.items) |handler| {
                handler(self, fixed_dt);
            }
        }

        pub fn run(self: *Self, io: std.Io) void {
            const fixed_dt = 1.0 / self.config.fixed_step_rate;
            var accumulator: f32 = 0;
            var inputs = input.Accumulator{};
            var last_mouse = Vec2.zero;

            while (!raylib.windowShouldClose()) {
                self.assets.pollReloads(io);

                inputs.poll();
                const frame_time = @min(raylib.getFrameTime(), MAX_FRAME_TIME);
                accumulator += frame_time;

                while (accumulator >= fixed_dt) {
                    self.input = inputs.consume(last_mouse);
                    last_mouse = self.input.mouse_position;
                    self.debug.pollToggles(&self.input);
                    self.snapshotTransforms();
                    self.stepFixed();
                    accumulator -= fixed_dt;
                }
                self.interpolation = accumulator / fixed_dt;

                for (self.on_update.items) |handler| {
                    handler(self, frame_time);
                }

                raylib.beginDrawing();
                raylib.clearBackground(Color.black);
                raylib.beginCamera2D(
                    self.camera.transform.position,
                    self.camera.transform.rotation * (180.0 / std.math.pi),
                    self.camera.zoom,
                    @floatFromInt(self.config.width),
                    @floatFromInt(self.config.height),
                );
                if (comptime has_sprite or has_fill_shape) self.renderEntities();
                for (self.on_render.items) |handler| {
                    handler(self, frame_time);
                }
                if (comptime debug.enabled) {
                    if (comptime has_collider) {
                        if (self.debug.draw_colliders) {
                            var it = self.world.query(.{ Collider, Transform });
                            while (it.next()) |r| debug.drawCollider(r.Collider.*, r.Transform.*, self.debug.collider_color);
                        }
                    }
                    if (self.debug.draw_transforms) {
                        const length = debug.gizmoLength(@floatFromInt(self.config.height), self.camera.zoom);
                        var it = self.world.query(.{Transform});
                        while (it.next()) |r| debug.drawTransform(r.Transform.*, length);
                    }
                    self.debug.flush();
                }
                raylib.endCamera2D();
                raylib.endDrawing();
            }
        }
    };
}
