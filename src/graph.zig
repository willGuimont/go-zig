const std = @import("std");

pub fn Graph(comptime T: type) type {
    return struct {
        const This = @This();
        node: std.AutoHashMap(T, void),
        edges: std.AutoHashMap(T, std.ArrayList(T)),
        gpa: std.mem.Allocator,

        pub fn init(gpa: std.mem.Allocator) This {
            return Graph(T){
                .node = std.AutoHashMap(T, void).init(gpa),
                .edges = std.AutoHashMap(T, std.ArrayList(T)).init(gpa),
                .gpa = gpa,
            };
        }
    };
}
