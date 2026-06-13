const std = @import("std");
const Transform = @import("../components/transform.zig").Transform;
const Collider = @import("../components/collider.zig").Collider;
const Vec2 = @import("../math/vec2.zig").Vec2;

pub const Manifold = struct { normal: Vec2, depth: f32 };
pub const Hit = struct { index: usize, manifold: Manifold };

pub const Body = struct { transform: Transform, collider: Collider };

pub fn IsColliding(a: Body, b: Body) ?Manifold {
    if (a.collider.shape == .circle and b.collider.shape == .circle) {
        return circleCircle(a, b);
    }

    var extra_axis: ?Vec2 = null;
    if (a.collider.shape == .circle or b.collider.shape == .circle) {
        const circle_body = if (a.collider.shape == .circle) a else b;
        const poly_body = if (a.collider.shape == .circle) b else a;
        extra_axis = nearestVertexAxis(circle_body, poly_body);
    }

    return sat(a, b, extra_axis);
}

pub fn IsCollidingMany(a: Body, others: []const Body) ?Hit {
    var best: ?Hit = null;
    for (others, 0..) |b, i| {
        if (IsColliding(a, b)) |m| {
            if (best == null or m.depth > best.?.manifold.depth)
                best = .{ .index = i, .manifold = m };
        }
    }
    return best;
}

fn toWorld(body: Body, p: Vec2) Vec2 {
    const xf = body.transform;
    return xf.position.add(body.collider.offset.add(p).mul(xf.scale).rotate(xf.rotation));
}

/// Number of separating axes a shape contributes to SAT. Circles contribute
/// none of their own; the relevant circle axis is supplied separately via
/// `nearestVertexAxis`.
fn axisCount(body: Body) usize {
    return switch (body.collider.shape) {
        .circle => 0,
        .rect => 2,
        .polygon => |verts| verts.len,
    };
}

/// The `i`th separating axis of `body`, in world space. `i` must be less than
/// `axisCount(body)`. Computing axes on demand keeps SAT free of any fixed cap
/// on polygon vertex count.
fn axisAt(body: Body, i: usize) Vec2 {
    switch (body.collider.shape) {
        .circle => unreachable,
        .rect => {
            const r = body.transform.rotation;
            return if (i == 0) Vec2.right.rotate(r) else Vec2.down.rotate(r);
        },
        .polygon => |verts| {
            const a = toWorld(body, verts[i]);
            const b = toWorld(body, verts[(i + 1) % verts.len]);
            const edge = b.sub(a);
            return (Vec2{ .x = edge.y, .y = -edge.x }).normalize();
        },
    }
}

fn project(body: Body, axis: Vec2) [2]f32 {
    switch (body.collider.shape) {
        .circle => |radius| {
            const center = toWorld(body, Vec2.zero).dot(axis);
            const r = radius * body.transform.scale.x;
            return .{ center - r, center + r };
        },
        .rect => |half| {
            const corners = [_]Vec2{
                .{ .x = -half.x, .y = -half.y },
                .{ .x = half.x, .y = -half.y },
                .{ .x = half.x, .y = half.y },
                .{ .x = -half.x, .y = half.y },
            };
            return projectPoints(body, &corners, axis);
        },
        .polygon => |verts| return projectPoints(body, verts, axis),
    }
}

fn projectPoints(body: Body, points: []const Vec2, axis: Vec2) [2]f32 {
    var lo: f32 = std.math.inf(f32);
    var hi: f32 = -std.math.inf(f32);
    for (points) |p| {
        const d = toWorld(body, p).dot(axis);
        lo = @min(lo, d);
        hi = @max(hi, d);
    }
    return .{ lo, hi };
}

const Sat = struct {
    a: Body,
    b: Body,
    center_a: Vec2,
    center_b: Vec2,
    min_depth: f32 = std.math.inf(f32),
    min_normal: Vec2 = Vec2.zero,

    /// Tests one axis. Returns false if it is a separating axis (no overlap),
    /// in which case the shapes do not collide and SAT can stop early.
    fn testAxis(self: *Sat, axis: Vec2) bool {
        const pa = project(self.a, axis);
        const pb = project(self.b, axis);

        if (pa[1] < pb[0] or pb[1] < pa[0]) return false;

        const depth = @min(pa[1], pb[1]) - @max(pa[0], pb[0]);
        if (depth < self.min_depth) {
            self.min_depth = depth;
            self.min_normal = if (self.center_b.sub(self.center_a).dot(axis) < 0) axis.negate() else axis;
        }
        return true;
    }
};

fn sat(a: Body, b: Body, extra_axis: ?Vec2) ?Manifold {
    var s = Sat{
        .a = a,
        .b = b,
        .center_a = toWorld(a, Vec2.zero),
        .center_b = toWorld(b, Vec2.zero),
    };

    for (0..axisCount(a)) |i| {
        if (!s.testAxis(axisAt(a, i))) return null;
    }
    for (0..axisCount(b)) |i| {
        if (!s.testAxis(axisAt(b, i))) return null;
    }
    if (extra_axis) |axis| {
        if (!s.testAxis(axis)) return null;
    }

    return .{ .normal = s.min_normal, .depth = s.min_depth };
}

fn circleCircle(a: Body, b: Body) ?Manifold {
    const ra = a.collider.shape.circle * a.transform.scale.x;
    const rb = b.collider.shape.circle * b.transform.scale.x;
    const ca = toWorld(a, Vec2.zero);
    const cb = toWorld(b, Vec2.zero);
    const diff = cb.sub(ca);
    const dist2 = diff.lengthSquared();
    const radii = ra + rb;
    if (dist2 >= radii * radii) return null;
    const dist = @sqrt(dist2);
    const normal = if (dist > 0) diff.scale(1.0 / dist) else Vec2.up;
    return .{ .normal = normal, .depth = radii - dist };
}

fn nearestVertexAxis(circle: Body, poly: Body) Vec2 {
    const center = toWorld(circle, Vec2.zero);
    const verts: []const Vec2 = switch (poly.collider.shape) {
        .rect => |half| &[_]Vec2{
            .{ .x = -half.x, .y = -half.y },
            .{ .x = half.x, .y = -half.y },
            .{ .x = half.x, .y = half.y },
            .{ .x = -half.x, .y = half.y },
        },
        .polygon => |v| v,
        .circle => unreachable,
    };

    var best_dist2: f32 = std.math.inf(f32);
    var best: Vec2 = Vec2.zero;
    for (verts) |v| {
        const w = toWorld(poly, v);
        const d2 = center.distanceSquared(w);
        if (d2 < best_dist2) {
            best_dist2 = d2;
            best = w;
        }
    }
    return center.sub(best).normalize();
}
