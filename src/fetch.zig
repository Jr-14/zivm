const std = @import("std");
const http = std.http;
const json = std.json;

const FetchOptions = struct {
    client: ?*http.Client = null,
    url: []const u8,
    user_agent: ?[]const u8 = null,
};

fn fetch(io: std.Io, allocator: std.mem.Allocator, response_writer: *std.Io.Writer, options: FetchOptions) !http.Status {
    var owned_client: ?http.Client = null;
    const client: *http.Client = if (options.client) |provided| provided else blk: {
        owned_client = .{
            .allocator = allocator,
            .io = io,
        };
        break :blk &owned_client.?;
    };
    defer if (owned_client) |*owned| owned.deinit();

    const result = try client.fetch(.{
        .location = .{ .url = options.url },
        .method = .GET,
        .headers = .{
            .user_agent = .{
                .override = options.user_agent orelse "zivm/0.1.0",
            },
        },
        .response_writer = response_writer,
    });

    return result.status;
}

pub const Mirrors = struct {
    allocator: std.mem.Allocator,
    bytes: []u8,
    lines: [][]const u8,

    fn deinit(self: *Mirrors) void {
        self.allocator.free(self.lines);
        self.allocator.free(self.bytes);
        self.* = undefined;
    }
};

/// Fetch community mirrors download link
pub fn getCommunityMirrors(io: std.Io, allocator: std.mem.Allocator) !Mirrors {
    var body: std.Io.Writer.Allocating = .init(allocator);
    defer body.deinit();

    const status = try fetch(io, allocator, &body.writer, .{
        .url = "https://ziglang.org/download/community-mirrors.txt",
    });

    if (status != .ok) {
        std.log.err("Failed to fetch - status: {any}, response: {s}\n", .{ status, body.written() });
        return error.FetchFailed;
    }

    const bytes = try body.toOwnedSlice();
    errdefer allocator.free(bytes);

    var lines: std.ArrayList([]const u8) = .empty;
    errdefer lines.deinit(allocator);

    var iterator = std.mem.splitScalar(u8, bytes, '\n');
    while (iterator.next()) |line| {
        const trimmed = std.mem.trim(u8, line, "\r \t");
        if (trimmed.len == 0) continue;

        try lines.append(allocator, trimmed);
    }

    return .{
        .allocator = allocator,
        .bytes = bytes,
        .lines = try lines.toOwnedSlice(allocator),
    };
}

pub fn getIndex(io: std.Io, allocator: std.mem.Allocator) !json.Parsed(json.Value) {
    var body: std.Io.Writer.Allocating = .init(allocator);
    defer body.deinit();

    const status = try fetch(io, allocator, &body.writer, .{
        .url = "https://ziglang.org/download/index.json"
    });

    if (status != .ok) {
        std.log.err("Failed to fetch - status: {any}, response: {s}\n", .{ status, body.written() });
        return error.FetchFailed;
    }

    return try json.parseFromSlice(json.Value, allocator, body.written(), .{ .ignore_unknown_fields = true });
}

test "fetch community mirrors" {
    var mirrors = try getCommunityMirrors(std.testing.io, std.testing.allocator);
    defer mirrors.deinit();

    for (mirrors.lines) |line| {
        std.log.err("{s}", .{line});
    }
}

test "fetch zig index" {
    const parsed_json = try getIndex(std.testing.io, std.testing.allocator);
    defer parsed_json.deinit();

    std.log.err("{any}", .{ parsed_json.value });
}
