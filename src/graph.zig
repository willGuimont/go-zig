const std = @import("std");

pub fn Graph(comptime K: type, comptime V: type) type {
    return struct {
        const This = @This();
        const NodeMap = std.AutoHashMap(K, V);
        pub const NodeSet = std.AutoArrayHashMap(K, void);
        const EdgeMap = std.AutoHashMap(K, NodeSet);
        const SearchOutput = struct {
            visited: NodeSet,
            seen: NodeSet,

            pub fn init(fpa: std.mem.Allocator) SearchOutput {
                return SearchOutput{
                    .visited = NodeSet.init(fpa),
                    .seen = NodeSet.init(fpa),
                };
            }

            pub fn deinit(this: *SearchOutput) void {
                this.visited.deinit();
                this.seen.deinit();
            }
        };

        nodes: NodeMap,
        edges: EdgeMap,
        allocator: std.mem.Allocator,

        pub fn init(allocator: std.mem.Allocator) This {
            return Graph(K, V){
                .nodes = NodeMap.init(allocator),
                .edges = EdgeMap.init(allocator),
                .allocator = allocator,
            };
        }

        pub fn deinit(this: *This) void {
            this.nodes.deinit();
            var it = this.edges.iterator();
            while (it.next()) |edge| {
                edge.value_ptr.*.deinit();
            }
            this.edges.deinit();
        }

        pub fn eql(this: *const This, other: *const This) bool {
            if (this.nodes.count() != other.nodes.count() or this.edges.count() != other.edges.count()) {
                return false;
            }

            var it_nodes = this.nodes.iterator();
            while (it_nodes.next()) |node| {
                const other_node = other.nodes.get(node.key_ptr.*) orelse return false;
                if (node.value_ptr.* != other_node) {
                    return false;
                }
            }

            var it_edges = this.edges.iterator();
            while (it_edges.next()) |edge| {
                const other_edge = other.edges.get(edge.key_ptr.*) orelse return false;
                if (edge.value_ptr.*.count() != other_edge.count()) {
                    return false;
                }
                var it2 = edge.value_ptr.*.iterator();
                while (it2.next()) |neighbor| {
                    if (!other_edge.contains(neighbor.key_ptr.*)) {
                        return false;
                    }
                }
            }

            return true;
        }

        pub fn clone(this: *const This) !This {
            var dup = This.init(this.allocator);
            var it_nodes = this.nodes.iterator();
            while (it_nodes.next()) |node| {
                try dup.setNode(node.key_ptr.*, node.value_ptr.*);
            }
            var it_edges = this.edges.iterator();
            while (it_edges.next()) |edge| {
                var it2 = edge.value_ptr.*.iterator();
                while (it2.next()) |neighbor| {
                    try dup.addEdge(edge.key_ptr.*, neighbor.key_ptr.*);
                }
            }
            return dup;
        }

        pub fn getNode(this: *const This, key: K) ?V {
            return this.nodes.get(key);
        }

        pub fn setNode(this: *This, key: K, value: V) !void {
            try this.nodes.put(key, value);
            if (!this.edges.contains(key)) {
                try this.edges.put(key, NodeSet.init(this.allocator));
            }
        }

        pub fn getNeighbors(this: *const This, key: K) ?NodeSet {
            return this.edges.get(key);
        }

        pub fn addEdge(this: *This, from: K, to: K) !void {
            var v = try this.edges.getOrPut(from);
            if (!v.found_existing) {
                v.value_ptr.* = NodeSet.init(this.allocator);
            }
            try v.value_ptr.*.put(to, {});
        }

        pub fn seach(this: *const This, start: K, comptime key_predicate: fn (K) bool, comptime value_predicate: fn (V) bool) !SearchOutput {
            var output = SearchOutput.init(this.allocator);
            try output.seen.put(start, {});

            var queue = NodeSet.init(this.allocator);
            defer queue.deinit();

            try queue.put(start, {});
            while (queue.count() > 0) {
                const node = queue.pop().key;
                if (output.visited.contains(node)) {
                    continue;
                }
                try output.visited.put(node, {});
                const neighbors = this.edges.get(node);
                if (neighbors) |ns| {
                    var it = ns.iterator();
                    while (it.next()) |neighbor| {
                        const key = neighbor.key_ptr.*;
                        try output.seen.put(key, {});
                        if (!output.visited.contains(key) and key_predicate(key) and value_predicate(this.nodes.get(key).?)) {
                            try queue.put(key, {});
                        }
                    }
                }
            }
            return output;
        }
    };
}

fn test_key_predicate(k: u32) bool {
    return k != 3;
}

fn test_value_predicate(_: u32) bool {
    return true;
}

test "graph" {
    var graph = Graph(u32, u32).init(std.testing.allocator);
    defer graph.deinit();

    // Nodes and edges
    try graph.setNode(0, 0);
    try graph.setNode(1, 1);
    try graph.setNode(2, 2);
    try graph.setNode(3, 3);

    try graph.addEdge(0, 1);
    try graph.addEdge(1, 0);
    try graph.addEdge(0, 2);
    try graph.addEdge(2, 0);
    try graph.addEdge(1, 3);
    try graph.addEdge(3, 1);
    try graph.addEdge(2, 3);
    try graph.addEdge(3, 2);

    try std.testing.expectEqual(graph.nodes.count(), 4);
    try std.testing.expectEqual(graph.edges.count(), 4);

    // Search
    var search = try graph.seach(0, test_key_predicate, test_value_predicate);
    defer search.deinit();

    try std.testing.expectEqual(search.visited.count(), 3);
    try std.testing.expectEqual(search.seen.count(), 4);

    // Clone
    var cloned = try graph.clone();
    defer cloned.deinit();

    try std.testing.expect(cloned.eql(&graph));
    try cloned.setNode(100, 100);
    try std.testing.expect(!cloned.eql(&graph));

    try std.testing.expectEqual(cloned.nodes.count(), 5);
    try std.testing.expectEqual(graph.nodes.count(), 4);
}
