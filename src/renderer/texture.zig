const raylib = @import("../raylib.zig");

pub const Texture = struct {
    width: u32,
    height: u32,
    handle: raylib.RawTexture,

    pub fn load(path: [:0]const u8) Texture {
        const handle = raylib.loadTexture(path);
        return .{
            .width = @intCast(handle.width),
            .height = @intCast(handle.height),
            .handle = handle,
        };
    }

    pub fn unload(self: Texture) void {
        raylib.unloadTexture(self.handle);
    }
};
