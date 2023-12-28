const std = @import("std");

pub fn Graph(comptime K: type, comptime V: type) type {
    return struct {
        const This = @This();
        const NodeMap = std.AutoHashMap(K, V);
        const NodeSet = std.AutoArrayHashMap(K, void);
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
        fpa: std.mem.Allocator,

        pub fn init(fpa: std.mem.Allocator) This {
            return Graph(K, V){
                .nodes = NodeMap.init(fpa),
                .edges = EdgeMap.init(fpa),
                .fpa = fpa,
            };
        }

        pub fn deinit(this: *This) void {
            this.nodes.deinit();
            for (this.edges.items) |edge| {
                edge.value.deinit();
            }
            this.edges.deinit();
        }

        pub fn get_node(this: *This, key: K) ?V {
            return this.nodes.get(key);
        }

        pub fn set_node(this: *This, key: K, value: V) !void {
            try this.nodes.put(key, value);
            try this.edges.put(key, NodeSet.init(this.fpa));
        }

        pub fn get_neighbors(this: *This, key: K) ?NodeSet {
            return this.edges.get(key);
        }

        pub fn add_edge(this: *This, from: K, to: K) !void {
            try this.edges.getPtr(from).?.put(to, {});
        }

        pub fn prune(this: *This) !void {
            var to_remove = std.ArrayList(K).init(this.fpa);
            defer to_remove.deinit();

            var it = this.edges.iterator();
            while (it.next()) |edge| {
                const k = edge.key_ptr.*;
                if (!this.nodes.contains(k)) {
                    try to_remove.append(k);
                }
            }
            for (to_remove.items) |k| {
                _ = this.edges.remove(k);
            }
        }

        pub fn seach(this: *This, start: K, comptime key_predicate: fn (K) bool, comptime value_predicate: fn (V) bool) !SearchOutput {
            var output = SearchOutput.init(this.fpa);
            defer output.deinit();
            try output.seen.put(start, {});

            var queue = NodeSet.init(this.fpa);
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
