const std = @import("std");
const graph = @import("graph.zig");
const go = @import("go.zig");
const w4 = @import("wasm4.zig");

// TODO tune this
var buffer: [2048 * 16]u8 = undefined;
var fba = std.heap.FixedBufferAllocator.init(&buffer);
const allocator = fba.allocator();

const smiley = [8]u8{
    0b11000011,
    0b10000001,
    0b00100100,
    0b00100100,
    0b00000000,
    0b00100100,
    0b10011001,
    0b11000011,
};

var board = go.Board.init(9, 9, allocator) catch unreachable;

export fn start() void {
    w4.trace("Init");
    board.createSquareBoard() catch unreachable;
    board.putStone(0, 0, go.Board.StoneColor.black) catch unreachable;
    board.putStone(0, 1, go.Board.StoneColor.white) catch unreachable;
    w4.trace("should kill");
    board.putStone(1, 0, go.Board.StoneColor.white) catch unreachable;
    w4.trace("wat");
    w4.tracefs("at 0 0 {?}", .{board.getStone(0, 0)}, allocator);
}

export fn update() void {
    w4.DRAW_COLORS.* = 2;
    w4.text("Hello from Zig!", 10, 10);

    const gamepad = w4.GAMEPAD1.*;
    if (gamepad & w4.BUTTON_1 != 0) {
        w4.DRAW_COLORS.* = 4;
    }

    w4.blit(&smiley, 76, 76, 8, 8, w4.BLIT_1BPP);
    w4.text("Press X to blink", 16, 90);
}
