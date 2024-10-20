const rl = @import("raylib");
const std = @import("std");

const rnd = std.crypto.random;
const Vec2 = rl.Vector2;

const WIDTH = 800;
const HEIGHT = 800;
const AGENTS = 600;
const EVAPORATION = 3;

const SPEED = 3;

const Vec2i = struct {
    x: i32,
    y: i32,
};

const Agent = struct {
    pos: Vec2,
    vel: Vec2,
    rotation: f32,
};

const Pix = struct {
    pos: Vec2,
    intesity: u8,
};

fn newAgent() Agent {
    const alpha: f32 = @floatFromInt(rnd.intRangeAtMost(i32, 0, 359));
    const vel = Vec2.init(SPEED * std.math.cos(alpha), SPEED * std.math.sin(alpha));
    return .{ .pos = Vec2.init(WIDTH / 2, HEIGHT / 2), .vel = vel, .rotation = alpha };
}

fn moveAgents(agents: *[]Agent, field: *std.AutoArrayHashMap(Vec2i, u8)) !void {
    var agent: *Agent = undefined;
    const offset = 1;
    for (0..agents.len) |i| {
        agent = &agents.*[i];
        for (0..3) |x| {
            for (0..3) |y| {
                try field.put(Vec2i{ .x = @intFromFloat(agent.pos.x + @as(f32, @floatFromInt(x)) - offset), .y = @intFromFloat(agent.pos.y + @as(f32, @floatFromInt(y)) - offset) }, 255);
            }
        }
        agent.pos = rl.math.vector2Add(agent.pos, agent.vel);
        if (agent.pos.x < 0 or agent.pos.x > WIDTH) {
            agent.vel.x *= -1;
        }
        if (agent.pos.y < 0 or agent.pos.y > HEIGHT) {
            agent.vel.y *= -1;
        }
        agent.rotation = std.math.radiansToDegrees(std.math.atan2(agent.vel.y, agent.vel.x)) + 90;
    }
}

fn sensor(agents: *[]Agent, field: std.AutoArrayHashMap(Vec2i, u8)) void {
    var agent: *Agent = undefined;
    var t: Vec2 = undefined;
    var r: [3]i32 = undefined;
    var vel: Vec2 = undefined;
    for (0..agents.len) |i| {
        var j: usize = 0;
        agent = &agents.*[i];
        t = rl.math.vector2Add(agent.pos, rl.math.vector2Scale(agent.vel, 2));
        r[j] = field.get(Vec2i{ .x = @intFromFloat(t.x), .y = @intFromFloat(t.y) }) orelse 0;
        for (0..3) |k| {
            for (0..3) |l| {
                r[j] += field.get(Vec2i{ .x = @intFromFloat(t.x + @as(f32, @floatFromInt(k)) - 1), .y = @intFromFloat(t.y + @as(f32, @floatFromInt(l)) - 1) }) orelse 0;
            }
        }
        r[j] = @divTrunc(r[j], 9);
        j += 1;
        vel = Vec2.init(SPEED * std.math.cos(agent.rotation + 30), SPEED * std.math.sin(agent.rotation + 30));
        t = rl.math.vector2Add(agent.pos, rl.math.vector2Scale(vel, 2));
        r[j] = field.get(Vec2i{ .x = @intFromFloat(t.x), .y = @intFromFloat(t.y) }) orelse 0;
        for (0..3) |k| {
            for (0..3) |l| {
                r[j] += field.get(Vec2i{ .x = @intFromFloat(t.x + @as(f32, @floatFromInt(k)) - 1), .y = @intFromFloat(t.y + @as(f32, @floatFromInt(l)) - 1) }) orelse 0;
            }
        }

        r[j] = @divTrunc(r[j], 9);
        j += 1;
        vel = Vec2.init(SPEED * std.math.cos(agent.rotation - 30), SPEED * std.math.sin(agent.rotation - 30));
        t = rl.math.vector2Add(agent.pos, rl.math.vector2Scale(vel, 2));
        r[j] = field.get(Vec2i{ .x = @intFromFloat(t.x), .y = @intFromFloat(t.y) }) orelse 0;
        for (0..3) |k| {
            for (0..3) |l| {
                r[j] += field.get(Vec2i{ .x = @intFromFloat(t.x + @as(f32, @floatFromInt(k)) - 1), .y = @intFromFloat(t.y + @as(f32, @floatFromInt(l)) - 1) }) orelse 0;
            }
        }
        r[j] = @divTrunc(r[j], 9);
        j += 1;
        var max_val: i32 = r[0];
        var max_ix: usize = 0;
        for (1..3) |k| {
            if (r[k] > max_val) {
                max_val = r[k];
                max_ix = k;
            }
        }

        switch (max_ix) {
            0 => {},
            1 => {
                agent.rotation += 30;
                agent.vel = Vec2.init(SPEED * std.math.cos(agent.rotation), SPEED * std.math.sin(agent.rotation));
            },
            2 => {
                agent.rotation -= 30;
                agent.vel = Vec2.init(SPEED * std.math.cos(agent.rotation), SPEED * std.math.sin(agent.rotation));
            },
            else => {},
        }
    }
}

fn newPix() Pix {
    return .{ .pos = Vec2.init(0, 0), .intesity = 0 };
}

fn processField(field: *std.AutoArrayHashMap(Vec2i, u8)) void {
    var white = rl.Color.white;
    var it = field.*.iterator();
    for (0..field.count()) |_| {
        const v = it.next();
        if (v != null) {
            const t = v.?;
            white.a = t.value_ptr.*;
            rl.drawPixelV(Vec2.init(@floatFromInt(t.key_ptr.*.x), @floatFromInt(t.key_ptr.*.y)), white);

            if (@as(i32, t.value_ptr.*) - EVAPORATION < 0) {
                _ = field.swapRemove(t.key_ptr.*);
            } else {
                t.value_ptr.* -= EVAPORATION;
            }
        }
    }
}

pub fn main() !void {
    var a: [AGENTS]Agent = undefined;
    for (0..AGENTS) |i| {
        a[i] = newAgent();
    }
    var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    defer arena.deinit();
    const allocator = arena.allocator();
    var field = std.AutoArrayHashMap(Vec2i, u8).init(allocator);
    defer field.deinit();
    var agents: []Agent = a[0..];
    rl.initWindow(WIDTH, HEIGHT, "Slime");
    rl.setTargetFPS(60);
    while (!rl.windowShouldClose()) {
        rl.beginDrawing();
        defer rl.endDrawing();
        rl.drawFPS(10, 10);
        rl.clearBackground(rl.Color.black);
        try moveAgents(&agents, &field);
        processField(&field);
        sensor(&agents, field);
    }
}
