const std = @import("std");
const http = std.http;
const json = std.json;

const ziglang_releases = "https://ziglang.org/download/index.json";
const ziglang_mirrors = "https://ziglang.org/download/community-mirrors.txt";

const Architectures = enum {
    @"src",
    @"bootstrap",
    @"aarch64-freebsd",
    @"arm-freebsd",
    @"powerpc64-freebsd",
    @"powerpc64le-freebsd",
    @"riscv64-freebsd",
    @"x86_64-freebsd",
    @"aarch64-netbsd",
    @"arm-netbsd",
    @"x86-netbsd",
    @"x86_64-netbsd",
    @"riscv64-netbsd",
    @"aarch64-openbsd",
    @"arm-openbsd",
    @"riscv64-openbsd",
    @"x86_64-openbsd",
    @"aarch64-linux",
    @"armv6kz-linux",
    @"armv7a-linux",
    @"arm-linux",
    @"i386-linux",
    @"riscv64-linux",
    @"x86_64-linux",
    @"x86-linux",
    @"loongarch64-linux",
    @"s390x-linux",
    @"powerpc64le-linux",
    @"powerpc-linux",
    @"aarch64-macos",
    @"x86_64-macos",
    @"i386-windows",
    @"x86_64-windows",
    @"x86-windows",
    @"aarch64-windows",
};

const architectures = @typeInfo(Architectures).@"enum".field_names;

const Source = struct {
    tarball: []const u8,
    shasum: []const u8,
    size: u32,
};

const VersionMeta = struct {
    version: ?[]const u8,
    date: []const u8,
    docs: []const u8,
    stdDocs: ?[]const u8,
    notes: []const u8,
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

    if (result.status != http.Status.ok) {
        std.log.err("Received non 200 status type - got {d}\n", .{ result.status });
        return std.process.exit(1);
    }

    // for (architectures) |name| {
    //     std.debug.print("{s}\n", .{ name });
    // }

    const allocator = init.arena.allocator();

    const parsed = try json.parseFromSlice(json.Value, allocator, body.written(), .{ .ignore_unknown_fields = true });
    defer parsed.deinit();
    switch (parsed.value) {
        .object => |obj| {
            var itr = obj.iterator();
            while (itr.next()) |entry| {
                const key = entry.key_ptr.*;
                const value = entry.value_ptr.*;

                std.debug.print("{s} -- {s}\n", .{
                    key,
                    @tagName(value),
                });
            }
        },
        else => return error.UnexpectedValue,
    }
}

