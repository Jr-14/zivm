const std = @import("std");
const http = std.http;
const json = std.json;

const ziglang_host_name = "ziglang.org";

pub fn main(init: std.process.Init) !void {
    var body: std.Io.Writer.Allocating = .init(init.gpa);
    defer body.deinit();

    var client = http.Client{
        .allocator = init.gpa,
        .io = init.io,
    };
    defer client.deinit();
    const uri = try std.Uri.parse("https://" ++ ziglang_host_name ++ "/download/index.json");
    const result = try client.fetch(.{
        .location = .{ .uri =  uri },
        .method = .GET,
        .headers = .{
            .user_agent = .{
                .override = "zivm/0.1.0"
            },
        },
        .response_writer = &body.writer,
    });

    std.debug.print("{}\n", .{ result.status });

    const text = body.written();
    std.debug.print("{s}\n", .{ text });
}

