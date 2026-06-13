const std = @import("std");
const raylib = @import("../raylib.zig");

const Transform = @import("../components/transform.zig").Transform;
const Sprite = @import("../components/sprite.zig").Sprite;
const Vec2 = @import("../math/vec2.zig").Vec2;
const Color = @import("../renderer/color.zig").Color;
const renderer = @import("../renderer/renderer.zig");
const Assets = @import("../assets/assets.zig").Assets;
const Camera = @import("camera.zig").Camera;

const FIXED_DT: f32 = 1.0 / 60.0;
// Upper bound on a single frame's delta. Without it, one long frame (a window
// drag, a breakpoint, a disk stall) would queue many fixed steps that take
// longer than real time to run, spiralling the accumulator away forever.
const MAX_FRAME_TIME: f32 = 0.25;

pub const GameConfig = struct {
    title: [:0]const u8,
    width: i32,
    height: i32,
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

        const SpriteEntry = struct { sprite: *Sprite, transform: *Transform };

        fn renderSprites(self: *Self) void {
            self.sprite_buffer.clearRetainingCapacity();

            var iter = self.world.query(.{ Sprite, Transform });
            while (iter.next()) |r| {
                if (!r.Sprite.visible) continue;
                self.sprite_buffer.append(self.allocator, .{ .sprite = r.Sprite, .transform = r.Transform }) catch continue;
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
                    e.transform.*,
                    e.sprite.tint,
                );
            }
        }

        world: World,
        assets: Assets,
        config: GameConfig,
        allocator: std.mem.Allocator,
        camera: Camera = .{},
        on_fixed: std.ArrayListUnmanaged(Handler) = .empty,
        on_update: std.ArrayListUnmanaged(Handler) = .empty,
        on_render: std.ArrayListUnmanaged(Handler) = .empty,
        sprite_buffer: std.ArrayListUnmanaged(SpriteEntry) = .empty,

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

        pub fn run(self: *Self, io: std.Io) void {
            var accumulator: f32 = 0;

            while (!raylib.windowShouldClose()) {
                self.assets.pollReloads(io);
                const frame_time = @min(raylib.getFrameTime(), MAX_FRAME_TIME);
                accumulator += frame_time;

                while (accumulator >= FIXED_DT) {
                    for (self.on_fixed.items) |handler| {
                        handler(self, FIXED_DT);
                    }
                    accumulator -= FIXED_DT;
                }

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
