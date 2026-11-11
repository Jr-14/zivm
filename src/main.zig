const std = @import("std");
const http = std.http;
const json = std.json;

const ziglang_releases = "https://ziglang.org/download/index.json";
const ziglang_mirrors = "https://ziglang.org/download/community-mirrors.txt";

const Architectures = enum {
    @"src",
    @"x86_64-windows",
    @"x86_64-linux",
};

const architectures = @typeInfo(Architectures).@"enum".field_names;

const Source = struct {
    tarball: []const u8,
    shasum: []const u8,
    size: u32,
};

const Version = struct {
    version: ?[]const u8,
    date: []const u8,
    
};

pub fn main(init: std.process.Init) !void {
    var body: std.Io.Writer.Allocating = .init(init.gpa);
    defer body.deinit();

    var client = http.Client{
        .allocator = init.gpa,
        .io = init.io,
    };
    defer client.deinit();
    const result = try client.fetch(.{
        .location = .{ .url = ziglang_releases },
        .method = .GET,
        .headers = .{
            .user_agent = .{
                .override = "zivm/0.1.0"
            },
        },
        .response_writer = &body.writer,
    });

    std.debug.print("{}\n", .{ result.status });
    std.debug.print("\n", .{});

    for (architectures) |name| {
        std.debug.print("{s}\n", .{ name });
    }
    // std.debug.print("Some sick field names\n{any}\n", .{ architectures });

    // const text = body.written();
    // std.debug.print("{s}\n", .{ text });
}

