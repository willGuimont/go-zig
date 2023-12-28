const std = @import("std");
const graph = @import("graph.zig");
// TODO: remove this
const w4 = @import("wasm4.zig");

pub const Board = struct {
    const This = @This();
    pub const StoneColor = enum(u1) {
        black,
        white,
    };
    const BoardGraph = graph.Graph(usize, ?StoneColor);
    const Group = struct {
        stones: BoardGraph.NodeSet,
        liberties: usize,

        fn deinit(this: *Group) void {
            this.stones.deinit();
        }
    };

    board_graph: BoardGraph,
    width: usize,
    height: usize,
    allocator: std.mem.Allocator,

    pub fn init(width: usize, height: usize, allocator: std.mem.Allocator) !This {
        var g = BoardGraph.init(allocator);
        return .{
            .board_graph = g,
            .width = width,
            .height = height,
            .allocator = allocator,
        };
    }

    fn deinit(this: *This) void {
        this.board_graph.deinit();
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

        try this.board_graph.prune();
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
        try this.board_graph.setNode(p, color);
        const neighbors = this.getNeighbors(x, y).?;
        for (neighbors.keys()) |k| {
            const xy = this.indexToPosition(k);
            try this.killGroupIfNoLiberty(xy[0], xy[1]);
        }
    }

    fn getGroupLiberty(this: *This, x: usize, y: usize) !Group {
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
        w4.tracefs("group: {?} {?}", .{ group.liberties, group.stones.count() }, this.allocator);
        if (group.liberties == 0) {
            for (group.stones.keys()) |k| {
                w4.tracefs("removing stone at {?}", .{k}, this.allocator);
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

    pub fn scoreTerritory(this: *const This) std.meta.Tuple(&.{ usize, usize }) {
        _ = this;
        // TODO
        return .{ 0, 0 };
    }
};
