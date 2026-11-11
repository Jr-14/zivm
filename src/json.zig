const std = @import("std");
const json = std.json;

const Meta = struct {
    version: ?[]const u8,
    date: ?[]const u8,
    docs: ?[]const u8,
};
const ZigIndex = struct {
    master: Meta,
};

pub fn tryThis(comptime T: type, allocator: std.mem.Allocator, value: []const u8) !T {
    const parsed = try json.parseFromSlice(T, allocator, value, .{ .ignore_unknown_fields = true });
    defer parsed.deinit();
    return parsed.value;
}

test "simple json parsing" {
    const value =
        \\{
        \\  "master": {
        \\    "version": "0.18.0-dev.935+ead8f5a7a",
        \\    "date": "2026-11-07",
        \\    "docs": "https://ziglang.org/documentation/master/"
        \\  }
        \\}
    ;
    const wow = try tryThis(ZigIndex, std.testing.allocator, value);
    std.debug.print("{s}\n", .{ wow.master.docs orelse "" });
}
