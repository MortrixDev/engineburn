pub const TimerMode = enum { once, repeat };

pub const Timer = struct {
    duration: f32,
    elapsed: f32 = 0,
    mode: TimerMode = .once,
    paused: bool = false,
    just_finished: bool = false,

    pub fn init(duration: f32) Timer {
        return .{ .duration = duration };
    }

    pub fn initRepeat(duration: f32) Timer {
        return .{ .duration = duration, .mode = .repeat };
    }

    pub fn tick(self: *Timer, dt: f32) void {
        self.just_finished = false;
        if (self.paused) return;
        if (self.duration <= 0) {
            self.just_finished = true;
            return;
        }
        if (self.mode == .once and self.elapsed >= self.duration) return;
        self.elapsed += dt;
        if (self.elapsed >= self.duration) {
            self.just_finished = true;
            if (self.mode == .repeat) {
                self.elapsed = @mod(self.elapsed, self.duration);
            } else {
                self.elapsed = self.duration;
            }
        }
    }

    pub fn finished(self: *const Timer) bool {
        return self.elapsed >= self.duration;
    }

    pub fn fraction(self: *const Timer) f32 {
        if (self.duration <= 0) return 1.0;
        return @min(self.elapsed / self.duration, 1.0);
    }

    pub fn remaining(self: *const Timer) f32 {
        return @max(self.duration - self.elapsed, 0.0);
    }

    pub fn reset(self: *Timer) void {
        self.elapsed = 0;
        self.just_finished = false;
    }

    pub fn pause(self: *Timer) void {
        self.paused = true;
    }

    pub fn @"resume"(self: *Timer) void {
        self.paused = false;
    }

    pub fn toggle(self: *Timer) void {
        self.paused = !self.paused;
    }
};
