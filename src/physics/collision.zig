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

    var buf: [MAX_POLY * 2]Vec2 = undefined;
    var n: usize = 0;
    n += getAxes(a, buf[n..]).len;
    n += getAxes(b, buf[n..]).len;

    if (a.collider.shape == .circle or b.collider.shape == .circle) {
        const circle_body = if (a.collider.shape == .circle) a else b;
        const poly_body = if (a.collider.shape == .circle) b else a;
        buf[n] = nearestVertexAxis(circle_body, poly_body);
        n += 1;
    }

    return sat(a, b, buf[0..n]);
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

fn getAxes(body: Body, buf: []Vec2) []Vec2 {
    switch (body.collider.shape) {
        .circle => return buf[0..0],
        .rect => {
            const r = body.transform.rotation;
            buf[0] = Vec2.right.rotate(r);
            buf[1] = Vec2.down.rotate(r);
            return buf[0..2];
        },
        .polygon => |verts| {
            std.debug.assert(verts.len <= buf.len);
            for (verts, 0..) |v, i| {
                const a = toWorld(body, v);
                const b = toWorld(body, verts[(i + 1) % verts.len]);
                const edge = b.sub(a);
                buf[i] = (Vec2{ .x = edge.y, .y = -edge.x }).normalize();
            }
            return buf[0..verts.len];
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

const MAX_POLY = 32;

fn sat(a: Body, b: Body, axes: []const Vec2) ?Manifold {
    var min_depth: f32 = std.math.inf(f32);
    var min_normal: Vec2 = Vec2.zero;

    for (axes) |axis| {
        const pa = project(a, axis);
        const pb = project(b, axis);

        if (pa[1] < pb[0] or pb[1] < pa[0]) return null;

        const depth = @min(pa[1], pb[1]) - @max(pa[0], pb[0]);
        if (depth < min_depth) {
            min_depth = depth;
            const center_a = toWorld(a, Vec2.zero);
            const center_b = toWorld(b, Vec2.zero);
            min_normal = if (center_b.sub(center_a).dot(axis) < 0) axis.negate() else axis;
        }
    }

    return .{ .normal = min_normal, .depth = min_depth };
}

fn circleCircle(a: Body, b: Body) ?Manifold {
    const ra = a.collider.shape.circle * a.transform.scale.x;
    const rb = b.collider.shape.circle * b.transform.scale.x;
    const ca = toWorld(a, Vec2.zero);
    const cb = toWorld(b, Vec2.zero);
    const diff = ca.sub(cb);
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
