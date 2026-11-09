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

pub fn tryThis(comptime T: type, allocator: std.mem.Allocator, value: []const u8) !void {
    const parsed = try json.parseFromSlice(T, allocator, value, .{ .ignore_unknown_fields = true });
    defer parsed.deinit();
    const zig_index = parsed.value;
    std.debug.print("{}", .{ zig_index });
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
    try tryThis(ZigIndex, std.testing.allocator, value);
}
