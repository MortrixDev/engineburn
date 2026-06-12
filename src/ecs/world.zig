const std = @import("std");
const SparseSet = @import("../core/sparse_set.zig").SparseSet;

pub const Entity = u32;

/// Fully-qualified type name, used as the per-type store key. Using the full
/// name (not just the last path segment) keeps two distinct component types
/// that share a short name (e.g. `foo.Sprite` and `bar.Sprite`) in separate
/// stores instead of silently aliasing them.
fn storeKey(comptime T: type) [:0]const u8 {
    return @typeName(T);
}

/// Last path segment of a type name, used for the user-facing query result
/// field so you can write `r.Sprite`. As a consequence a single query cannot
/// name two types that share a short name; doing so is a compile error at the
/// query site.
fn shortName(comptime T: type) [:0]const u8 {
    const full = @typeName(T);
    var i = full.len;
    while (i > 0) : (i -= 1) {
        if (full[i - 1] == '.') return full[i..];
    }
    return full;
}

fn typeList(comptime qt: anytype) [std.meta.fields(@TypeOf(qt)).len]type {
    const fields = std.meta.fields(@TypeOf(qt));
    var ts: [fields.len]type = undefined;
    for (fields, 0..) |field, i| ts[i] = @field(qt, field.name);
    return ts;
}

pub fn World(comptime component_types: []const type) type {
    const Stores = comptime blk: {
        var field_names: [component_types.len][:0]const u8 = undefined;
        var field_types: [component_types.len]type = undefined;
        var attrs: [component_types.len]std.builtin.Type.StructField.Attributes = undefined;

        for (component_types, 0..) |T, i| {
            const default: SparseSet(T) = .{};
            field_names[i] = storeKey(T);
            field_types[i] = SparseSet(T);
            attrs[i] = .{ .default_value_ptr = @ptrCast(&default) };
        }

        break :blk @Struct(.auto, null, &field_names, &field_types, &attrs);
    };

    return struct {
        const Self = @This();

        stores: Stores = .{},
        allocator: std.mem.Allocator,
        next_entity: Entity = 0,
        free_list: std.ArrayListUnmanaged(Entity) = .empty,

        /// Initializes the world with the given allocator.
        pub fn init(allocator: std.mem.Allocator) Self {
            return .{ .allocator = allocator };
        }

        /// Frees all component stores. Call this when the world is no longer needed.
        pub fn deinit(self: *Self) void {
            inline for (component_types) |T| {
                self.store(T).deinit(self.allocator);
            }
            self.free_list.deinit(self.allocator);
        }

        /// Creates a new entity and returns its ID. Recycles IDs freed by
        /// `destroyEntity`. IDs are reused without a generation tag, so an
        /// `Entity` value kept after the entity was destroyed may collide with a
        /// later entity; do not hold entity IDs across a `destroyEntity`.
        pub fn createEntity(self: *Self) Entity {
            if (self.free_list.pop()) |id| return id;
            const entity = self.next_entity;
            self.next_entity += 1;
            return entity;
        }

        /// Removes all of an entity's components and recycles its ID.
        /// Returns an error if recording the freed ID fails to allocate.
        pub fn destroyEntity(self: *Self, entity: Entity) !void {
            inline for (component_types) |T| {
                self.store(T).remove(entity);
            }
            try self.free_list.append(self.allocator, entity);
        }

        /// Creates a new entity with an initial set of components.
        /// `initial_components` is a tuple of component values, e.g. `.{ Position{}, Velocity{} }`.
        pub fn spawn(self: *Self, initial_components: anytype) !Entity {
            const entity = self.createEntity();
            inline for (std.meta.fields(@TypeOf(initial_components))) |field| {
                try self.add(entity, @field(initial_components, field.name));
            }
            return entity;
        }

        /// Adds a component to an entity. The component type is inferred from the value.
        /// Returns an error if allocation fails.
        pub fn add(self: *Self, entity: Entity, component: anytype) !void {
            try self.store(@TypeOf(component)).add(self.allocator, entity, component);
        }

        /// Removes a component of type `T` from an entity. No-ops if the entity does not have it.
        pub fn remove(self: *Self, entity: Entity, comptime T: type) void {
            self.store(T).remove(entity);
        }

        /// Returns a pointer to the component of type `T` on an entity, or null if not present.
        /// The pointer is invalidated by any subsequent `add`/`spawn` of the same
        /// component type, so do not hold it across one.
        pub fn get(self: *Self, entity: Entity, comptime T: type) ?*T {
            return self.store(T).get(entity);
        }

        fn store(self: *Self, comptime T: type) *SparseSet(T) {
            return &@field(self.stores, storeKey(T));
        }

        fn QueryResult(comptime qt: anytype) type {
            const types = comptime typeList(qt);

            var field_names: [types.len + 1][:0]const u8 = undefined;
            var field_types: [types.len + 1]type = undefined;
            var attrs: [types.len + 1]std.builtin.Type.StructField.Attributes = undefined;

            field_names[0] = "entity";
            field_types[0] = Entity;
            attrs[0] = .{};

            for (types, 0..) |T, i| {
                field_names[i + 1] = shortName(T);
                field_types[i + 1] = *T;
                attrs[i + 1] = .{};
            }

            return @Struct(.auto, null, &field_names, &field_types, &attrs);
        }

        fn QueryIterator(comptime qt: anytype) type {
            const qt_types = comptime typeList(qt);

            return struct {
                const Iter = @This();

                world: *World(component_types),
                entities: []const usize,
                cursor: usize,

                pub fn next(self: *Iter) ?QueryResult(qt) {
                    while (self.cursor < self.entities.len) {
                        const entity = self.entities[self.cursor];
                        self.cursor += 1;

                        var all_have = true;
                        inline for (qt_types) |T| {
                            if (!self.world.store(T).has(entity)) {
                                all_have = false;
                                break;
                            }
                        }

                        if (!all_have) continue;

                        var result: QueryResult(qt) = undefined;
                        result.entity = @intCast(entity);
                        inline for (qt_types) |T| {
                            @field(result, shortName(T)) = self.world.store(T).get(entity).?;
                        }
                        return result;
                    }

                    return null;
                }
            };
        }

        /// Returns an iterator over all entities that have all of the queried component types.
        /// `qt` is a tuple of types, e.g. `.{ Position, Velocity }`.
        /// Each result exposes an `entity` field and one pointer field per component, named by type.
        /// Iteration is driven off the smallest matching store to minimize membership checks.
        /// Do not add or remove components of the queried types while iterating.
        pub fn query(self: *Self, comptime qt: anytype) QueryIterator(qt) {
            const qt_types = comptime typeList(qt);
            var entities: []const usize = self.store(qt_types[0]).dense_indices.items;
            inline for (qt_types[1..]) |T| {
                const d = self.store(T).dense_indices.items;
                if (d.len < entities.len) entities = d;
            }
            return .{ .world = self, .entities = entities, .cursor = 0 };
        }
    };
}

test "spawn, query, and destroy" {
    const testing = std.testing;
    const Pos = struct { x: f32 };
    const Vel = struct { x: f32 };

    var world = World(&[_]type{ Pos, Vel }).init(testing.allocator);
    defer world.deinit();

    const e = try world.spawn(.{ Pos{ .x = 1 }, Vel{ .x = 2 } });
    _ = try world.spawn(.{Pos{ .x = 3 }}); // Pos only, must not match the Pos+Vel query

    try testing.expectEqual(@as(f32, 1), world.get(e, Pos).?.x);

    var count: usize = 0;
    var it = world.query(.{ Pos, Vel });
    while (it.next()) |r| {
        count += 1;
        try testing.expectEqual(@as(f32, 1), r.Pos.x);
    }
    try testing.expectEqual(@as(usize, 1), count);

    try world.destroyEntity(e);
    try testing.expect(world.get(e, Pos) == null);
    try testing.expect(world.get(e, Vel) == null);
}

test "destroyed entity ids are recycled" {
    const testing = std.testing;
    const Pos = struct { x: f32 };

    var world = World(&[_]type{Pos}).init(testing.allocator);
    defer world.deinit();

    const a = world.createEntity();
    try world.destroyEntity(a);
    const b = world.createEntity();
    try testing.expectEqual(a, b);
}
