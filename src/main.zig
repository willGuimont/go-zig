const std = @import("std");
const graph = @import("graph.zig");
const w4 = @import("wasm4.zig");

var buffer: [640]u8 = undefined;
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

const StoneColor = enum(u1) {
    black,
    white,
};

var graph_state = graph.Graph(i32, ?StoneColor).init(allocator);

fn key_predicate(_: i32) bool {
    return true;
}

fn is_black(c: ?StoneColor) bool {
    return c == .black;
}

fn is_white(c: ?StoneColor) bool {
    return c == .white;
}

export fn start() void {
    w4.trace("Init");
    graph_state.set_node(1, StoneColor.white) catch unreachable;
    graph_state.set_node(2, StoneColor.white) catch unreachable;
    graph_state.set_node(3, StoneColor.white) catch unreachable;
    graph_state.set_node(4, StoneColor.black) catch unreachable;
    graph_state.set_node(5, StoneColor.black) catch unreachable;
    graph_state.set_node(6, null) catch unreachable;
    graph_state.add_edge(1, 2) catch unreachable;
    graph_state.add_edge(2, 3) catch unreachable;
    graph_state.add_edge(4, 5) catch unreachable;
    graph_state.add_edge(5, 6) catch unreachable;
    graph_state.add_edge(1, 4) catch unreachable;
    graph_state.add_edge(2, 5) catch unreachable;
    graph_state.add_edge(3, 6) catch unreachable;
    graph_state.prune() catch unreachable;

    var x = graph_state.seach(1, key_predicate, is_white) catch unreachable;
    defer x.deinit();
    const s1 = x.visited.count();
    const s2 = x.seen.count();
    const s = std.fmt.allocPrint(allocator, "visited {d} seen {d}", .{ s1, s2 }) catch "error";
    defer allocator.free(s);
    w4.trace(s);
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
