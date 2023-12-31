const std = @import("std");
const board = @import("board.zig");

pub const StoneColor = board.Board.StoneColor;
pub const Score = board.Board.Score;
pub const Territory = board.Board.Territory;

pub const Game = struct {
    const This = @This();
    pub const GoGameError = error{
        Ko,
    };

    go_board: board.Board,
    last_board: ?board.Board,
    turn: StoneColor,
    num_passes: u32,

    pub fn init(size: usize, allocator: std.mem.Allocator) !This {
        return .{
            .go_board = try board.Board.init(size, size, allocator),
            .last_board = null,
            .turn = StoneColor.black,
            .num_passes = 0,
        };
    }

    pub fn deinit(this: *This) void {
        this.go_board.deinit();
        if (this.last_board != null) {
            this.last_board.?.deinit();
        }
    }

    pub fn createSquare(this: *This) !void {
        try this.go_board.createSquareBoard();
    }

    pub fn getTurn(this: *const This) StoneColor {
        return this.turn;
    }

    pub fn getScore(this: *const This) Score {
        return this.go_board.score;
    }

    pub fn getStone(this: *const This, x: usize, y: usize) ?StoneColor {
        return this.go_board.getStone(x, y);
    }

    pub fn putStone(this: *This, x: usize, y: usize) !void {
        var next_board = try this.go_board.clone();
        defer next_board.deinit();

        try next_board.putStone(x, y, this.turn);

        if (this.last_board != null and next_board.eql_board(&this.last_board.?)) {
            return error.Ko;
        }
        this.turn = StoneColor.opposite(this.turn);
        this.num_passes = 0;
        try this.updateLastBoard(this.go_board);
        try this.updateBoard(next_board);
    }

    pub fn pass(this: *This) !void {
        this.turn = StoneColor.opposite(this.turn);
        this.num_passes += 1;
        try this.updateLastBoard(this.go_board);
    }

    fn updateBoard(this: *This, new_board: board.Board) !void {
        this.go_board.deinit();
        this.go_board = try new_board.clone();
    }

    fn updateLastBoard(this: *This, new_board: board.Board) !void {
        if (this.last_board != null) {
            this.last_board.?.deinit();
        }
        this.last_board = try new_board.clone();
    }

    pub fn isFinished(this: *const This) bool {
        return this.num_passes >= 2;
    }

    pub fn removeStone(this: *This, x: usize, y: usize) !void {
        try this.go_board.removeStone(x, y);
    }

    pub fn getTerritory(this: *const This) !Territory {
        return try this.go_board.getTerritory();
    }

    pub fn addTerritoryScore(this: *This, territory: *const Territory) void {
        this.go_board.addTerritoryScore(territory);
    }
};

test "game" {
    var game = try Game.init(9, std.testing.allocator);
    defer game.deinit();
    try game.createSquare();

    // Putting stone
    try std.testing.expectEqual(game.turn, .black);
    try game.putStone(8, 8);
    try std.testing.expectEqual(game.getStone(8, 8), .black);
    try std.testing.expectEqual(game.turn, .white);

    // Capture and pass
    try game.putStone(7, 8);
    try game.pass();
    try std.testing.expectEqual(game.num_passes, 1);
    try game.putStone(8, 7);
    try std.testing.expectEqual(game.num_passes, 0);
    try std.testing.expectEqual(game.getStone(8, 8), null);

    // Ko rule
    try game.putStone(1, 0);
    try game.putStone(2, 0);
    try game.putStone(0, 1);
    try game.putStone(3, 1);
    try game.putStone(1, 2);
    try game.putStone(2, 2);
    try game.putStone(2, 1);
    try game.putStone(1, 1);

    var err_ko = game.putStone(2, 1);
    try std.testing.expectError(error.Ko, err_ko);
    try std.testing.expectEqual(game.turn, .black);

    // Finish game
    try game.pass();
    try game.pass();
    try std.testing.expect(game.isFinished());
}
