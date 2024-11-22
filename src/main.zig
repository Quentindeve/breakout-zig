const std = @import("std");
const print = std.debug.print;
const raylib = @cImport(@cInclude("raylib.h"));
const ArrayList = std.ArrayList;

const BRICK_WIDTH = 50;
const SPACE_BETWEEN = 10;
const BRICK_ROWS = 3;
const BRICK_HEIGHT = 30;

const BRICKS_COUNT = WINDOW_WIDTH / (BRICK_WIDTH + (SPACE_BETWEEN * 2)) * BRICK_ROWS;
const BRICKS_PER_LINE = BRICKS_COUNT / BRICK_ROWS;
const BRICKS_START_X = (WINDOW_WIDTH - (BRICKS_PER_LINE * BRICK_WIDTH + SPACE_BETWEEN * 2 + BRICK_WIDTH)) / 2;

const BALL_WIDTH = 20;
const WINDOW_WIDTH = 600;

const Rect = struct {
    pos_x: i32,
    pos_y: i32,
    width: i32,
    height: i32,
    color: raylib.Color,

    pub fn draw(self: *const Rect) void {
        raylib.DrawRectangle(@intCast(self.pos_x), @intCast(self.pos_y), @intCast(self.width), @intCast(self.height), self.color);
    }
};

const Ball = struct {
    pos_x: i32,
    pos_y: i32,
    width: i32,
    height: i32,
    x_direction: i32,
    y_direction: i32,
    color: raylib.Color,

    pub fn update_position(ball: *Ball) void {
        ball.pos_x +|= @intCast(ball.x_direction);
        ball.pos_y +|= @intCast(ball.y_direction);
    }

    pub fn draw(self: *const Ball) void {
        raylib.DrawRectangle(@intCast(self.pos_x), @intCast(self.pos_y), @intCast(self.width), @intCast(self.height), self.color);
    }

    pub fn oob_bounce(self: *Ball) void {
        if (self.pos_x - @divFloor(self.width, 2) <= 0) {
            self.x_direction = 3;
        }

        if (self.pos_x + @divFloor(self.width, 2) >= WINDOW_WIDTH) {
            self.x_direction = -3;
        }

        if (self.pos_y <= 0) {
            self.y_direction = 3;
        }
    }

    pub fn bounce(self: *Ball, rect: *const Rect) void {
        self.x_direction = switch (self.pos_x >= rect.pos_x + @divFloor(rect.width, 2)) {
            // at the right of the rect
            true => 3,
            // at the left of the rect
            false => -3,
        };

        self.y_direction = switch (self.pos_y >= rect.pos_y + @divFloor(rect.height, 2)) {
            // at the bottom of the rect
            true => 3,
            // at the top of the rect
            false => -3,
        };
    }
};

pub fn check_collision_rect_to_ball(brick: *const Rect, ball: *const Ball) bool {
    return brick.pos_x < ball.pos_x +| ball.width and
        brick.pos_x +| brick.width > ball.pos_x and
        brick.pos_y < ball.pos_y +| ball.width and
        brick.height +| brick.pos_y > ball.pos_y;
}

pub fn main() !void {
    var ball: Ball = .{ .pos_x = WINDOW_WIDTH / 2 - BALL_WIDTH, .pos_y = WINDOW_WIDTH / 2, .width = BALL_WIDTH, .height = BALL_WIDTH, .color = .{ .a = 255, .r = 64, .g = 128, .b = 255 }, .x_direction = 3, .y_direction = 3 };
    var platform: Rect = .{ .pos_x = WINDOW_WIDTH / 8, .pos_y = WINDOW_WIDTH * 0.9, .width = 150, .height = 20, .color = raylib.RED };

    var bricks: [BRICKS_COUNT]?Rect = initBricks();
    var stop = false;
    var score: usize = 0;

    raylib.InitWindow(WINDOW_WIDTH, WINDOW_WIDTH, "Casse-cul");
    raylib.SetTargetFPS(60);

    while (!raylib.WindowShouldClose()) {
        raylib.BeginDrawing();
        raylib.ClearBackground(raylib.BLACK);

        stop = ball.pos_y >= WINDOW_WIDTH or score == BRICKS_COUNT;

        if (!stop) {
            for (bricks, 0..) |maybeBrick, idx| {
                if (maybeBrick == null) continue;

                var brick = maybeBrick.?;
                brick.draw();

                if (check_collision_rect_to_ball(&brick, &ball) or check_collision_rect_to_ball(&platform, &ball)) {
                    const rect = switch (check_collision_rect_to_ball(&platform, &ball)) {
                        true => platform,
                        false => brick,
                    };

                    if (!std.meta.eql(rect, platform)) {
                        score += 1;
                        bricks[idx] = null;
                    }

                    ball.bounce(&rect);
                }
            }

            ball.draw();

            if (raylib.IsKeyDown(raylib.KEY_LEFT)) {
                if (platform.pos_x - 20 <= 0) {
                    platform.pos_x = 0;
                } else {
                    platform.pos_x -= 20;
                }
            }

            if (raylib.IsKeyDown(raylib.KEY_RIGHT)) {
                if (platform.pos_x + platform.width + 20 < WINDOW_WIDTH) {
                    platform.pos_x += 20;
                } else {
                    platform.pos_x = WINDOW_WIDTH - platform.width;
                }
            }

            ball.update_position();
            ball.oob_bounce();
            platform.draw();

            // std.debug.print("Platform.pos_x = {}\n", .{platform.pos_x + platform.width});
        } else {
            drawEndScreen(score);
        }

        raylib.EndDrawing();
    }
}

fn drawEndScreen(score: usize) void {
    const string = switch (score == BRICKS_COUNT) {
        // win
        true => "YOU WIN  ",
        // lose
        false => "YOU LOSE",
    };

    const color = switch (score == BRICKS_COUNT) {
        // win
        true => raylib.GREEN,
        // lose
        false => raylib.RED,
    };

    var measure_x = raylib.MeasureText(string, 32);
    raylib.DrawText(string, WINDOW_WIDTH / 2 - @divFloor(measure_x, 2), WINDOW_WIDTH / 2, 32, color);

    const score_print = std.fmt.allocPrint(std.heap.c_allocator, "Score: {}", .{score}) catch "Buy more ram";
    defer std.heap.c_allocator.free(score_print);

    measure_x = raylib.MeasureText(score_print.ptr, 18);
    raylib.DrawText(score_print.ptr, WINDOW_WIDTH / 2 - @divFloor(measure_x, 2), WINDOW_WIDTH / 2 + 64, 18, color);
}

fn initBricks() [BRICKS_COUNT]?Rect {
    var buffer: [BRICKS_COUNT]?Rect = std.mem.zeroes(@TypeOf(initBricks()));
    var x: i32 = BRICKS_START_X;
    var y: i32 = SPACE_BETWEEN;

    for (1..(BRICKS_COUNT + 1)) |idx| {
        const brick = Rect{ .pos_x = x, .pos_y = y, .width = BRICK_WIDTH, .height = BRICK_HEIGHT, .color = .{ .a = 255, .r = 255, .g = 128, .b = 64 } };
        buffer[idx - 1] = brick;

        x += BRICK_WIDTH + SPACE_BETWEEN;
        if (idx % BRICKS_PER_LINE == 0) {
            y += BRICK_HEIGHT + SPACE_BETWEEN;
            x = BRICKS_START_X;
        }
    }

    return buffer;
}
