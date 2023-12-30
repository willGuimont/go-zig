const std = @import("std");
const go = @import("go.zig");

pub const Game = struct {
    const This = @This();

    go_board: go.Board,
    last_board: ?go.Board,
    turn: go.Board.StoneColor,
    score: go.Board.Score,
    numPasses: u32,

    pub fn init(size: usize, allocator: std.mem.Allocator) !This {
        return .{
            .go_board = try go.Board.init(size, size, allocator),
            .last_board = null,
            .turn = go.Board.StoneColor.black,
            .score = .{ .black = 0, .white = 5.5 },
            .numPasses = 0,
        };
    }

    pub fn createSquare(this: *This) !void {
        try this.go_board.createSquareBoard();
    }

    pub fn getStone(this: *This) ?go.Board.StoneColor {
        return try this.go_board.getStone();
    }

    pub fn putStone(this: *This, x: usize, y: usize) !void {
        try this.go_board.putStone(this.turn, x, y);
        if ((this.last_board == null) or (std.meta.eql(this.go_board, this.last_board))) {
            this.turn = go.Board.StoneColor.opposite(this.turn);
            this.numPasses = 0;
            this.last_board = this.go_board;
        } else {
            this.go_board = this.last_board;
        }
    }

    pub fn pass(this: *This) !void {
        this.turn = go.Board.StoneColor.opposite(this.turn);
        this.numPasses += 1;
        this.last_board = this.go_board;
    }

    pub fn isFinished(this: *This) bool {
        return this.numPasses >= 2;
    }
};
