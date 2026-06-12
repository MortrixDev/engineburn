# Engineburn

A small 2D game engine written in Zig, with [raylib](https://www.raylib.com/) as a backend for rendering and platform specifics.

Engineburn gives you a comptime-generic entity-component-system, a fixed/variable
timestep game loop, sprite rendering, a 2D camera, an asset cache with hot-reload,
and thin input and drawing wrappers. The design favours minimal abstraction: most
of the engine is generated at compile time from the component types you declare.

## Requirements

- [Zig](https://ziglang.org/) (0.16)
- raylib 6.0 is pulled in automatically as a build dependency

On Linux the build links against Wayland and OpenGL system libraries (use flake.nix).
Other platforms have not been tested.

## Getting started

Run one of the bundled examples:

```sh
zig build run -- examples/{example.zig}
```
