const std = @import("std");
const HostName = std.Io.net.HostName;

pub fn parseHostName(name: []const u8) !void {
    const host_name: std.Io.net.HostName = try .init(name);
    std.debug.print("{s}\n", .{ host_name.bytes[0..] });
}

const expect = std.testing.expect;

test "parsing a simple hostname" {
    const ziglang_host_name = "ziglang.org";
    try parseHostName(ziglang_host_name);
}
