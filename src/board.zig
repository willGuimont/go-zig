const std = @import("std");
const graph = @import("graph.zig");

pub const Board = struct {
    const This = @This();
    pub const StoneColor = enum(u1) {
        black,
        white,

        pub fn opposite(this: StoneColor) StoneColor {
            if (this == .black) {
                return .white;
            }
            return .black;
        }
    };
    const BoardGraph = graph.Graph(usize, ?StoneColor);
    const Group = struct {
        stones: BoardGraph.NodeSet,
        liberties: usize,

        fn deinit(this: *Group) void {
            this.stones.deinit();
        }
    };
    pub const Score = struct {
        black: f32,
        white: f32,
    };
    pub const GoError = error{
        InvalidMove,
        Suicide,
    };

    board_graph: BoardGraph,
    width: usize,
    height: usize,
    score: Score,
    allocator: std.mem.Allocator,

    pub fn init(width: usize, height: usize, allocator: std.mem.Allocator) !This {
        var g = BoardGraph.init(allocator);
        return .{
            .board_graph = g,
            .width = width,
            .height = height,
            .score = .{ .black = 0, .white = 6.5 },
            .allocator = allocator,
        };
    }

    pub fn deinit(this: *This) void {
        this.board_graph.deinit();
    }

    pub fn clone(this: *const This) !This {
        return .{
            .board_graph = try this.board_graph.clone(),
            .width = this.width,
            .height = this.height,
            .score = this.score,
            .allocator = this.allocator,
        };
    }

    pub fn eql_board(this: *This, other: *This) bool {
        return this.board_graph.eql(&other.board_graph);
    }

    fn positionToIndex(this: *const This, x: usize, y: usize) usize {
        return x + y * this.width;
    }

    fn indexToPosition(this: *const This, i: usize) std.meta.Tuple(&.{ usize, usize }) {
        return .{ i % this.width, i / this.width };
    }

    fn const_true(_: usize) bool {
        return true;
    }

    fn is_black(c: ?StoneColor) bool {
        return c == .black;
    }

    fn is_white(c: ?StoneColor) bool {
        return c == .white;
    }

    fn is_empty(c: ?StoneColor) bool {
        return c == null;
    }

    pub fn createSquareBoard(this: *This) !void {
        for (0..this.width) |i| {
            for (0..this.height) |j| {
                const p = this.positionToIndex(i, j);
                try this.board_graph.setNode(p, null);
            }
        }
        for (0..this.width) |i| {
            for (0..this.height) |j| {
                const p = this.positionToIndex(i, j);
                if (i > 0) {
                    const prev_i = this.positionToIndex(i - 1, j);
                    try this.board_graph.addEdge(p, prev_i);
                    try this.board_graph.addEdge(prev_i, p);
                }
                if (j > 0) {
                    const prev_j = this.positionToIndex(i, j - 1);
                    try this.board_graph.addEdge(p, prev_j);
                    try this.board_graph.addEdge(prev_j, p);
                }
            }
        }
    }

    pub fn getStone(this: *const This, x: usize, y: usize) ?StoneColor {
        const p = this.positionToIndex(x, y);
        const sc = this.board_graph.getNode(p);
        if (sc) |c| {
            return c;
        }
        return null;
    }

    pub fn putStone(this: *This, x: usize, y: usize, color: StoneColor) !void {
        const p = this.positionToIndex(x, y);
        const is_empty_pos = this.board_graph.getNode(p).? == null;
        if (!is_empty_pos) {
            return error.InvalidMove;
        }

        var next_board = try this.clone();
        defer next_board.deinit();

        try next_board.board_graph.setNode(p, color);
        try next_board.updateAround(x, y);

        var group = try next_board.getGroupLiberty(x, y);
        defer group.deinit();
        if (group.liberties == 0) {
            return error.Suicide;
        }

        try this.board_graph.setNode(p, color);
        try this.updateAround(x, y);
    }

    fn updateAround(this: *This, x: usize, y: usize) !void {
        const neighbors = this.getNeighbors(x, y).?;
        for (neighbors.keys()) |k| {
            const xy = this.indexToPosition(k);
            try this.killGroupIfNoLiberty(xy[0], xy[1]);
        }
    }

    fn getGroupLiberty(this: *const This, x: usize, y: usize) !Group {
        const p = this.positionToIndex(x, y);
        const stone = this.getStone(x, y);

        if (stone == null) {
            return Group{ .stones = BoardGraph.NodeSet.init(this.allocator), .liberties = 0 };
        }

        var search = if (stone == .black)
            try this.board_graph.seach(p, const_true, is_black)
        else
            try this.board_graph.seach(p, const_true, is_white);
        defer search.deinit();

        var liberties: usize = 0;
        for (search.seen.keys()) |k| {
            if (this.board_graph.getNode(k).? == null) {
                liberties += 1;
            }
        }
        return .{ .stones = try search.visited.clone(), .liberties = liberties };
    }

    fn killGroupIfNoLiberty(this: *This, x: usize, y: usize) !void {
        var group = try this.getGroupLiberty(x, y);
        defer group.deinit();
        if (group.liberties == 0) {
            const color = this.getStone(x, y);
            if (color == .black) {
                this.score.white += @floatFromInt(group.stones.count());
            } else {
                this.score.black += @floatFromInt(group.stones.count());
            }

            for (group.stones.keys()) |k| {
                try this.board_graph.setNode(k, null);
            }
        }
    }

    pub fn getNeighbors(this: *const This, x: usize, y: usize) ?BoardGraph.NodeSet {
        const p = this.positionToIndex(x, y);
        return this.board_graph.getNeighbors(p);
    }

    pub fn removeStone(this: *This, x: usize, y: usize) !void {
        const p = this.positionToIndex(x, y);
        try this.board_graph.setNode(p, null);
    }

    pub fn scoreTerritory(this: *const This) Score {
        _ = this;
        // TODO
        return .{ 0, 0 };
    }
};

test "go" {
    var board = try Board.init(9, 9, std.testing.allocator);
    defer board.deinit();
    try board.createSquareBoard();

    // Capturing
    try board.putStone(0, 0, .black);
    try board.putStone(1, 0, .white);
    try board.putStone(0, 1, .white);

    try std.testing.expectEqual(board.getStone(0, 0), null);
    try std.testing.expectEqual(board.getStone(1, 0), .white);
    try std.testing.expectEqual(board.getStone(0, 1), .white);
    try std.testing.expectEqual(board.score.white, 7.5);

    // Already occupied
    const err_occupied = board.putStone(1, 0, .black);
    try std.testing.expectError(error.InvalidMove, err_occupied);

    // Suicide
    const err_suicide = board.putStone(0, 0, .black);
    try std.testing.expectError(error.Suicide, err_suicide);

    // Clone
    var cloned = try board.clone();
    defer cloned.deinit();

    try cloned.putStone(4, 4, .black);

    try std.testing.expectEqual(cloned.getStone(4, 4), .black);
    try std.testing.expectEqual(board.getStone(4, 4), null);

    // TODO test scoreTerritory
}

test "go capture in closed space" {
    var board = try Board.init(9, 9, std.testing.allocator);
    defer board.deinit();
    try board.createSquareBoard();

    try board.putStone(1, 0, .black);
    try board.putStone(2, 0, .white);
    try board.putStone(0, 1, .black);
    try board.putStone(3, 1, .white);
    try board.putStone(1, 2, .black);
    try board.putStone(2, 2, .white);
    try board.putStone(2, 1, .black);

    try board.putStone(1, 1, .white);

    try std.testing.expectEqual(board.getStone(1, 1), .white);
    try std.testing.expectEqual(board.getStone(2, 1), null);
}
