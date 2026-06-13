const std = @import("std");
const raylib = @import("../raylib.zig");

const Transform = @import("../components/transform.zig").Transform;
const Sprite = @import("../components/sprite.zig").Sprite;
const Vec2 = @import("../math/vec2.zig").Vec2;
const Color = @import("../renderer/color.zig").Color;
const renderer = @import("../renderer/renderer.zig");
const Assets = @import("../assets/assets.zig").Assets;
const Camera = @import("camera.zig").Camera;
const input = @import("../input/input.zig");
const SparseSet = @import("../core/sparse_set.zig").SparseSet;
const Entity = @import("../ecs/world.zig").Entity;

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

pub fn Game(comptime user_components: anytype) type {
    const components = comptime blk: {
        // Transform is always present; append user components, skipping any
        // duplicate (including an explicitly-listed Transform) so the generated
        // store struct never gets two fields with the same key.
        const ufields = std.meta.fields(@TypeOf(user_components));
        var list: [ufields.len + 1]type = undefined;
        list[0] = Transform;
        var n: usize = 1;
        for (ufields) |field| {
            const T = @field(user_components, field.name);
            var found = false;
            for (list[0..n]) |existing| {
                if (existing == T) {
                    found = true;
                    break;
                }
            }
            if (!found) {
                list[n] = T;
                n += 1;
            }
        }
        const final = list[0..n].*;
        break :blk &final;
    };
    const has_sprite = comptime blk: {
        for (std.meta.fields(@TypeOf(user_components))) |field| {
            if (@field(user_components, field.name) == Sprite) break :blk true;
        }
        break :blk false;
    };
    const WorldType = @import("../ecs/world.zig").World(components);

    return struct {
        const Self = @This();
        pub const World = WorldType;
        pub const Handler = *const fn (*Self, f32) void;

        const SpriteEntry = struct { sprite: *Sprite, transform: Transform };

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

        fn renderSprites(self: *Self) void {
            self.sprite_buffer.clearRetainingCapacity();

            var iter = self.world.query(.{ Sprite, Transform });
            while (iter.next()) |r| {
                if (!r.Sprite.visible) continue;
                const xf = self.interpolate(r.entity, r.Transform.*);
                self.sprite_buffer.append(self.allocator, .{ .sprite = r.Sprite, .transform = xf }) catch continue;
            }

            std.mem.sort(SpriteEntry, self.sprite_buffer.items, {}, struct {
                fn lt(_: void, a: SpriteEntry, b: SpriteEntry) bool {
                    return a.sprite.z < b.sprite.z;
                }
            }.lt);

            for (self.sprite_buffer.items) |e| {
                const half = Vec2{ .x = e.sprite.src.w / 2.0, .y = e.sprite.src.h / 2.0 };
                renderer.drawTexture(
                    self.assets.textures.get(e.sprite.texture).*,
                    e.sprite.src,
                    half,
                    e.transform,
                    e.sprite.tint,
                );
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
        sprite_buffer: std.ArrayListUnmanaged(SpriteEntry) = .empty,
        prev_transforms: SparseSet(Transform) = .{},

        pub fn init(allocator: std.mem.Allocator, config: GameConfig) Self {
            raylib.initWindow(config.width, config.height, config.title);
            return .{
                .world = World.init(allocator),
                .assets = Assets.init(allocator),
                .config = config,
                .allocator = allocator,
            };
        }

        pub fn deinit(self: *Self) void {
            self.world.deinit();
            self.assets.deinit();
            self.on_fixed.deinit(self.allocator);
            self.on_update.deinit(self.allocator);
            self.on_render.deinit(self.allocator);
            self.sprite_buffer.deinit(self.allocator);
            self.prev_transforms.deinit(self.allocator);
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
                if (has_sprite) self.renderSprites();
                for (self.on_render.items) |handler| {
                    handler(self, frame_time);
                }
                raylib.endCamera2D();
                raylib.endDrawing();
            }
        }
    };
}
