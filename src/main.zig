const rl = @import("raylib");
const std = @import("std");

const rnd = std.crypto.random;
const print = std.debug.print;
const Vec2 = rl.Vector2;

const WIDTH = 1000;
const HEIGHT = WIDTH;
const AGENTS = WIDTH * 5;
const EVAPORATION = SPEED;

const SPEED = 8;

const Start = enum {
    Center,
    Random,
    Border,
};

const Vec2i = struct {
    x: i32,
    y: i32,
};

const Agent = struct {
    pos: Vec2,
    vel: Vec2,
    rotation: f32,
};

fn newAgent(start: Start) Agent {
    var alpha: f32 = @as(f32, @floatFromInt(rnd.intRangeAtMost(i32, 0, 359))) + rnd.float(f32);
    var vel = Vec2.init(SPEED * std.math.cos(alpha), SPEED * std.math.sin(alpha));
    if (start == Start.Random) {
        const x: f32 = @floatFromInt(rnd.intRangeAtMost(i32, 0, WIDTH));
        const y: f32 = @floatFromInt(rnd.intRangeAtMost(i32, 0, HEIGHT));
        return .{ .pos = Vec2.init(x, y), .vel = vel, .rotation = alpha };
    } else if (start == Start.Center) {
        return .{ .pos = Vec2.init(WIDTH / 2, HEIGHT / 2), .vel = vel, .rotation = alpha };
    } else if (start == Start.Border) {
        var pos = Vec2.init(std.math.cos(@mod(alpha, 90)) + WIDTH / 2, std.math.sin(@mod(alpha, 90)) + WIDTH / 2);
        if (alpha >= 180) {
            alpha -= 180;
        } else alpha += 180;
        vel = Vec2.init(SPEED * std.math.cos(alpha), SPEED * std.math.sin(alpha));
        if (vel.x < 0) {
            pos.x += -pos.x;
        } else {
            pos.x += pos.x;
        }
        pos.x -= pos.x / vel.x;
        pos.y -= pos.y / vel.y;
        return .{ .pos = pos, .vel = vel, .rotation = alpha };
    } else {
        unreachable;
    }
}

fn moveAgents(agents: *[]Agent, field: *std.AutoArrayHashMap(Vec2i, u8)) !void {
    var agent: *Agent = undefined;
    for (0..agents.len) |i| {
        agent = &agents.*[i];
        try field.put(.{ .x = @intFromFloat(agent.pos.x), .y = @intFromFloat(agent.pos.y) }, 255);

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

fn sensor(agents: *[]Agent) !void {
    var agent: *Agent = undefined;
    var t: Vec2 = undefined;
    var r: [3]i32 = undefined;
    var vel: Vec2 = undefined;
    const img = rl.loadImageFromScreen();
    for (0..agents.len) |i| {
        var j: usize = 0;
        agent = &agents.*[i];
        t = rl.math.vector2Add(agent.pos, rl.math.vector2Scale(agent.vel, SPEED * 2));
        var x: i32 = 0;
        var y: i32 = 0;
        var pix: rl.Color = undefined;
        for (0..3) |k| {
            for (0..3) |l| {
                x = @intFromFloat(t.x + @as(f32, @floatFromInt(k)) - 2);
                y = @intFromFloat(t.y + @as(f32, @floatFromInt(l)) - 2);
                if (x > -1 and x < WIDTH and y > -1 and y < HEIGHT) {
                    pix = rl.getImageColor(img, x, y);
                    if (pix.b != 0) {
                        r[j] += @intCast(rl.getImageColor(img, x, y).b);
                    }
                }
            }
        }
        r[j] = @divTrunc(r[j], 9);
        j += 1;
        vel = Vec2.init(SPEED * std.math.cos(agent.rotation + 30), SPEED * std.math.sin(agent.rotation + 30));
        t = rl.math.vector2Add(agent.pos, rl.math.vector2Scale(vel, 2));
        for (0..3) |k| {
            for (0..3) |l| {
                x = @intFromFloat(t.x + @as(f32, @floatFromInt(k)) - 1);
                y = @intFromFloat(t.y + @as(f32, @floatFromInt(l)) - 1);
                if (x > -1 and x < WIDTH and y > -1 and y < HEIGHT) {
                    pix = rl.getImageColor(img, x, y);
                    if (pix.b != 0) {
                        r[j] += @intCast(rl.getImageColor(img, x, y).a);
                    }
                }
            }
        }

        r[j] = @divTrunc(r[j], 9);
        j += 1;
        vel = Vec2.init(SPEED * std.math.cos(agent.rotation - 30), SPEED * std.math.sin(agent.rotation - 30));
        t = rl.math.vector2Add(agent.pos, rl.math.vector2Scale(vel, 2));
        for (0..3) |k| {
            for (0..3) |l| {
                x = @intFromFloat(t.x + @as(f32, @floatFromInt(k)) - 1);
                y = @intFromFloat(t.y + @as(f32, @floatFromInt(l)) - 1);
                if (x > -1 and x < WIDTH and y > -1 and y < HEIGHT) {
                    pix = rl.getImageColor(img, x, y);
                    if (pix.b != 0) {
                        r[j] += @intCast(rl.getImageColor(img, x, y).b);
                    }
                }
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

fn processField(field: *std.AutoArrayHashMap(Vec2i, u8), pix: rl.Texture2D) void {
    var primary = rl.Color.black;
    var it = field.*.iterator();
    for (0..field.count()) |_| {
        const v = it.next();
        if (v != null) {
            const t = v.?;
            primary.b = t.value_ptr.*;
            pix.drawV(Vec2.init(@floatFromInt(t.key_ptr.*.x), @floatFromInt(t.key_ptr.*.y)), primary);
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
        a[i] = newAgent(Start.Border);
    }

    var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    defer arena.deinit();
    const allocator = arena.allocator();
    var field = std.AutoArrayHashMap(Vec2i, u8).init(allocator);
    defer field.deinit();
    var agents: []Agent = a[0..];
    rl.initWindow(WIDTH, HEIGHT, "Slime");
    rl.setTargetFPS(60);
    const image = rl.genImageColor(SPEED, SPEED, .{ .r = 0, .g = 0, .b = 255, .a = 255 });
    const pix = rl.loadTextureFromImage(image);
    while (!rl.windowShouldClose()) {
        rl.beginDrawing();
        defer rl.endDrawing();
        rl.drawFPS(10, 10);
        rl.clearBackground(rl.Color.black);
        try moveAgents(&agents, &field);
        processField(&field, pix);
        try sensor(&agents);
    }
}
