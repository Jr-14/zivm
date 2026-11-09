const std = @import("std");
const http = std.http;

const ziglang_host_name = "ziglang.org";

pub fn main(init: std.process.Init) !void {
    var client = http.Client{
        .allocator = init.gpa,
        .io = init.io,
    };
    defer client.deinit();
    const uri = try std.Uri.parse("https://" ++ ziglang_host_name ++ "/download/index.json");
    const result = try client.fetch(.{
        .location = .{ .uri =  uri },
        .method = .GET,
    });
    std.debug.print("{}\n", .{ result.status });
}

