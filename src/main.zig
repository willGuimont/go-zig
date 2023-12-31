const std = @import("std");
const r = @cImport(@cInclude("raylib.h"));
const go = @import("game.zig");

const allocator = std.heap.page_allocator;
const win_width = 800;
const win_height = 800;
const board_width = 600;
const board_height = 600;
const board_offset_x = @divTrunc((win_width - board_width), 2);
const board_offset_y = @divTrunc((win_height - board_height), 2);
const stone_size = board_width / board_dim / 2;
const font_size = 40;
const board_dim = 9;
var game_status = GameStatus.playing;
var removed_stones = std.AutoHashMap(std.meta.Tuple(&.{ usize, usize }), void).init(allocator);
var territory: ?go.Territory = null;

const GameStatus = enum(u8) {
    playing,
    removing_dead_stones,
    score,
};

fn squarePositionToScreen(x: c_int, y: c_int) std.meta.Tuple(&.{ c_int, c_int }) {
    return .{
        board_offset_x + x * @divTrunc(board_width, board_dim - 1),
        board_offset_y + y * @divTrunc(board_height, board_dim - 1),
    };
}

fn screenToSquarePosition(x: f32, y: f32) std.meta.Tuple(&.{ c_int, c_int }) {
    const mouse_x: i32 = @intFromFloat(x + stone_size);
    const mouse_y: i32 = @intFromFloat(y + stone_size);
    return .{
        @divTrunc(mouse_x - board_offset_x, @divTrunc(board_width, board_dim - 1)),
        @divTrunc(mouse_y - board_offset_y, @divTrunc(board_height, board_dim - 1)),
    };
}

fn drawGame(game: *const go.Game) !void {
    drawLines();
    drawStones(game);
    drawMouseOver(game);
    drawScore(game);
    drawInstructions();
    try drawTerritory(game);
}

fn drawLines() void {
    for (0..board_dim) |i| {
        const ii: c_int = @intCast(i);

        const start_horizontal = squarePositionToScreen(0, ii);
        const end_horizontal = squarePositionToScreen(board_dim - 1, ii);
        r.DrawLine(start_horizontal[0], start_horizontal[1], end_horizontal[0], end_horizontal[1], r.BLACK);

        const start_vertical = squarePositionToScreen(ii, 0);
        const end_vertical = squarePositionToScreen(ii, board_dim - 1);
        r.DrawLine(start_vertical[0], start_vertical[1], end_vertical[0], end_vertical[1], r.BLACK);
    }
}

fn drawStone(x: c_int, y: c_int, color: r.Color) void {
    const pos = squarePositionToScreen(x, y);
    r.DrawCircle(pos[0], pos[1], stone_size + 2, r.BLACK);
    r.DrawCircle(pos[0], pos[1], stone_size, color);
}

fn drawSquare(x: c_int, y: c_int, color: r.Color) void {
    const pos = squarePositionToScreen(x, y);
    const bigger_size = stone_size + 4;
    r.DrawRectangle(pos[0] - bigger_size / 2, pos[1] - bigger_size / 2, bigger_size, bigger_size, r.BLACK);
    r.DrawRectangle(pos[0] - stone_size / 2, pos[1] - stone_size / 2, stone_size, stone_size, color);
}

fn stoneColorToColor(color: go.StoneColor) r.Color {
    return if (color == go.StoneColor.black)
        r.BLACK
    else
        r.WHITE;
}

fn turnToColor(game: *const go.Game) r.Color {
    const turn = game.getTurn();
    return stoneColorToColor(turn);
}

fn drawStones(game: *const go.Game) void {
    for (0..board_dim) |x| {
        const xx: c_int = @intCast(x);
        for (0..board_dim) |y| {
            const yy: c_int = @intCast(y);
            const stone = game.getStone(x, y);
            if (stone) |s| {
                var color = stoneColorToColor(s);
                if (removed_stones.contains(.{ x, y })) {
                    drawSquare(xx, yy, color);
                } else {
                    drawStone(xx, yy, color);
                }
            }
        }
    }
}

fn drawMouseOver(game: *const go.Game) void {
    if (game_status != GameStatus.playing) {
        return;
    }
    const mouse_pos = r.GetMousePosition();
    const mouse_x: i32 = @intFromFloat(mouse_pos.x + stone_size);
    const mouse_y: i32 = @intFromFloat(mouse_pos.y + stone_size);
    const stone_x = @divTrunc(mouse_x - board_offset_x, @divTrunc(board_width, board_dim - 1));
    const stone_y = @divTrunc(mouse_y - board_offset_y, @divTrunc(board_height, board_dim - 1));
    if (stone_x >= 0 and stone_x < board_dim and stone_y >= 0 and stone_y < board_dim) {
        const stone_xx: usize = @intCast(stone_x);
        const stone_yy: usize = @intCast(stone_y);
        const is_occupied = game.getStone(stone_xx, stone_yy) != null;
        if (is_occupied) {
            return;
        }
        var color = turnToColor(game);
        drawSquare(stone_x, stone_y, color);
    }
}

fn drawTerritory(game: *const go.Game) !void {
    if (territory) |t| {
        var blacks = try t.toPosition(&t.black, &game.go_board);
        defer blacks.deinit();
        for (blacks.items) |p| {
            drawSquare(@intCast(p[0]), @intCast(p[1]), r.BLACK);
        }
        var whites = try t.toPosition(&t.white, &game.go_board);
        defer whites.deinit();
        for (whites.items) |p| {
            drawSquare(@intCast(p[0]), @intCast(p[1]), r.WHITE);
        }
    }
}

fn drawScore(game: *const go.Game) void {
    const score = game.getScore();
    const score_str = std.fmt.allocPrint(allocator, "Black:\t{d:3.1}\n\n\nWhite:\t{d:3.1}", .{ score.black, score.white }) catch unreachable;
    r.DrawText(score_str.ptr, 10, win_height - 80, font_size, r.BLACK);
}

fn drawInstructions() void {
    const x = 10;
    const y = 10;
    switch (game_status) {
        GameStatus.playing => {
            r.DrawText("Click to place stone. Space to pass.", x, y, font_size, r.BLACK);
        },
        GameStatus.removing_dead_stones => {
            r.DrawText("Remove dead stones. Space to finish.", x, y, font_size, r.BLACK);
        },
        GameStatus.score => {
            r.DrawText("Game finished.", x, y, font_size, r.BLACK);
        },
    }
}

fn updatePlaying(game: *go.Game) void {
    if (r.IsMouseButtonPressed(r.MOUSE_LEFT_BUTTON)) {
        const mouse_pos = r.GetMousePosition();
        const pos = screenToSquarePosition(mouse_pos.x, mouse_pos.y);
        if (pos[0] >= 0 and pos[0] < board_dim and pos[1] >= 0 and pos[1] < board_dim) {
            const stone_xx: usize = @intCast(pos[0]);
            const stone_yy: usize = @intCast(pos[1]);
            game.putStone(stone_xx, stone_yy) catch |err| {
                std.debug.print("Error: {?}\n", .{err});
            };
        }
    }
    if (r.IsKeyPressed(r.KEY_SPACE)) {
        game.pass() catch unreachable;
    }
}

fn updateRemoveDeadStones(game: *go.Game) !void {
    if (r.IsMouseButtonPressed(r.MOUSE_LEFT_BUTTON)) {
        const mouse_pos = r.GetMousePosition();
        const pos = screenToSquarePosition(mouse_pos.x, mouse_pos.y);
        if (pos[0] >= 0 and pos[0] < board_dim and pos[1] >= 0 and pos[1] < board_dim) {
            const stone_xx: usize = @intCast(pos[0]);
            const stone_yy: usize = @intCast(pos[1]);
            const stone = game.getStone(stone_xx, stone_yy);
            if (stone) |s| {
                _ = s;
                const p = .{ stone_xx, stone_yy };
                if (removed_stones.contains(p)) {
                    _ = removed_stones.remove(p);
                } else {
                    try removed_stones.put(p, {});
                }
            }
        }
    }
}

fn removeDeadStones(game: *go.Game) !void {
    var it = removed_stones.iterator();
    while (it.next()) |item| {
        const stone_xx = item.key_ptr.*[0];
        const stone_yy = item.key_ptr.*[1];
        try game.removeStone(stone_xx, stone_yy);
    }
}

fn update(game: *go.Game) !void {
    switch (game_status) {
        GameStatus.playing => {
            updatePlaying(game);
            if (game.isFinished()) {
                game_status = GameStatus.removing_dead_stones;
            }
        },
        GameStatus.removing_dead_stones => {
            try updateRemoveDeadStones(game);
            if (r.IsKeyPressed(r.KEY_SPACE)) {
                try removeDeadStones(game);
                territory = try game.getTerritory();
                game.addTerritoryScore(&territory.?);
                game_status = GameStatus.score;
            }
        },
        GameStatus.score => {},
    }
}

pub fn main() !void {
    defer removed_stones.deinit();

    // Game
    var game = try go.Game.init(board_dim, allocator);
    defer game.deinit();
    try game.createSquare();

    // Window
    r.SetConfigFlags(r.FLAG_VSYNC_HINT);
    r.InitWindow(win_width, win_height, "Go");
    r.SetTargetFPS(60);
    defer r.CloseWindow();

    // Game loop
    while (!r.WindowShouldClose()) {
        // Draw
        {
            r.BeginDrawing();
            defer r.EndDrawing();

            r.ClearBackground(r.RAYWHITE);
            try drawGame(&game);
        }
        // Input
        try update(&game);
    }
}

test {
    std.testing.refAllDeclsRecursive(go);
}
