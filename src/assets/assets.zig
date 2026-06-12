const std = @import("std");
const builtin = @import("builtin");

const Texture = @import("../renderer/texture.zig").Texture;

pub fn Handle(comptime T: type) type {
    _ = T;
    return struct { id: u32 };
}

pub fn AssetCache(comptime T: type) type {
    return struct {
        const Self = @This();

        const Entry = struct {
            asset: T,
            path: [:0]const u8,
            mtime: i128,
        };

        entries: std.ArrayListUnmanaged(Entry) = .empty,
        map: std.StringHashMapUnmanaged(Handle(T)) = .empty,
        allocator: std.mem.Allocator,

        pub fn init(allocator: std.mem.Allocator) Self {
            return .{ .allocator = allocator };
        }

        pub fn deinit(self: *Self) void {
            for (self.entries.items) |entry| {
                entry.asset.unload();
                self.allocator.free(entry.path);
            }
            self.entries.deinit(self.allocator);
            self.map.deinit(self.allocator);
        }

        pub fn load(self: *Self, io: std.Io, path: []const u8) !Handle(T) {
            if (self.map.get(path)) |handle| return handle;

            const path_owned = try self.allocator.dupeZ(u8, path);
            errdefer self.allocator.free(path_owned);

            const asset = T.load(path_owned);
            errdefer asset.unload();
            const mtime = statMtime(io, path_owned) catch 0;
            const handle = Handle(T){ .id = @intCast(self.entries.items.len) };

            // Insert into the map first; the entries list takes ownership of
            // path_owned only once its append succeeds. If the append fails the
            // errdefers undo the map insert, unload the asset, and free the path
            // exactly once, so deinit never double-frees the path.
            try self.map.put(self.allocator, path_owned, handle);
            errdefer _ = self.map.remove(path_owned);
            try self.entries.append(self.allocator, .{ .asset = asset, .path = path_owned, .mtime = mtime });

            return handle;
        }

        /// Returns a pointer to the asset behind `handle`. The pointer is into
        /// the entries list and is invalidated by a later `load`, so do not hold
        /// it across one.
        pub fn get(self: *Self, handle: Handle(T)) *T {
            return &self.entries.items[handle.id].asset;
        }

        pub fn pollReloads(self: *Self, io: std.Io) void {
            if (comptime builtin.mode != .Debug) return;
            for (self.entries.items) |*entry| {
                const mtime = statMtime(io, entry.path) catch continue;
                if (mtime == entry.mtime) continue;
                entry.asset.unload();
                entry.asset = T.load(entry.path);
                entry.mtime = mtime;
            }
        }
    };
}

pub const Assets = struct {
    textures: AssetCache(Texture),

    pub fn init(allocator: std.mem.Allocator) Assets {
        return .{ .textures = AssetCache(Texture).init(allocator) };
    }

    pub fn deinit(self: *Assets) void {
        self.textures.deinit();
    }

    pub fn pollReloads(self: *Assets, io: std.Io) void {
        self.textures.pollReloads(io);
    }
};

fn statMtime(io: std.Io, path: []const u8) !i128 {
    const stat = try std.Io.Dir.cwd().statFile(io, path, .{});
    return @as(i128, stat.mtime.nanoseconds);
}
