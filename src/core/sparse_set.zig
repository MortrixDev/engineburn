const std = @import("std");

pub fn SparseSet(comptime T: type) type {
    return struct {
        const Self = @This();
        const INVALID: usize = std.math.maxInt(usize);

        dense: std.ArrayListUnmanaged(T) = .empty,
        dense_indices: std.ArrayListUnmanaged(usize) = .empty,
        sparse: std.ArrayListUnmanaged(usize) = .empty,

        pub fn deinit(self: *Self, allocator: std.mem.Allocator) void {
            self.dense.deinit(allocator);
            self.dense_indices.deinit(allocator);
            self.sparse.deinit(allocator);
        }

        pub fn add(self: *Self, allocator: std.mem.Allocator, index: usize, value: T) !void {
            if (index >= self.sparse.items.len) {
                const old_len = self.sparse.items.len;
                try self.sparse.resize(allocator, index + 1);
                for (self.sparse.items[old_len..]) |*s| s.* = INVALID;
            }

            // Overwrite in place if the index is already present; appending a
            // second dense entry would orphan the old one and corrupt iteration.
            if (self.sparse.items[index] != INVALID) {
                self.dense.items[self.sparse.items[index]] = value;
                return;
            }

            const dense_idx = self.dense.items.len;
            try self.dense.append(allocator, value);
            try self.dense_indices.append(allocator, index);
            self.sparse.items[index] = dense_idx;
        }

        pub fn remove(self: *Self, index: usize) void {
            if (!self.has(index)) return;

            const dense_idx = self.sparse.items[index];
            const last_idx = self.dense_indices.items[self.dense_indices.items.len - 1];

            self.dense.items[dense_idx] = self.dense.items[self.dense.items.len - 1];
            self.dense_indices.items[dense_idx] = last_idx;
            self.sparse.items[last_idx] = dense_idx;
            self.sparse.items[index] = INVALID;

            _ = self.dense.pop();
            _ = self.dense_indices.pop();
        }

        /// Returns a pointer to the value at `index`, or null if absent.
        /// The pointer is into the dense array and is invalidated by any
        /// subsequent `add`/`remove` on this set, so do not hold it across one.
        pub fn get(self: *Self, index: usize) ?*T {
            if (!self.has(index)) return null;
            return &self.dense.items[self.sparse.items[index]];
        }

        pub fn has(self: *Self, index: usize) bool {
            if (index >= self.sparse.items.len) return false;
            return self.sparse.items[index] != INVALID;
        }
    };
}

test "add/get/has" {
    const testing = std.testing;
    var set: SparseSet(u32) = .{};
    defer set.deinit(testing.allocator);

    try testing.expect(!set.has(5));
    try set.add(testing.allocator, 5, 100);
    try set.add(testing.allocator, 2, 50);

    try testing.expect(set.has(5));
    try testing.expect(set.has(2));
    try testing.expectEqual(@as(u32, 100), set.get(5).?.*);
    try testing.expectEqual(@as(u32, 50), set.get(2).?.*);
    try testing.expect(set.get(99) == null);
}

test "remove swaps the last entry into place" {
    const testing = std.testing;
    var set: SparseSet(u32) = .{};
    defer set.deinit(testing.allocator);

    try set.add(testing.allocator, 5, 100);
    try set.add(testing.allocator, 2, 50);
    set.remove(5);

    try testing.expect(!set.has(5));
    try testing.expect(set.has(2));
    try testing.expectEqual(@as(u32, 50), set.get(2).?.*);
    try testing.expectEqual(@as(usize, 1), set.dense.items.len);
}

test "duplicate add overwrites in place" {
    const testing = std.testing;
    var set: SparseSet(u32) = .{};
    defer set.deinit(testing.allocator);

    try set.add(testing.allocator, 3, 1);
    try set.add(testing.allocator, 3, 2);

    try testing.expectEqual(@as(u32, 2), set.get(3).?.*);
    try testing.expectEqual(@as(usize, 1), set.dense.items.len);
}
