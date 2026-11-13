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
    date: ?[]const u8,
    docs: []const u8,
    std_docs: ?[]const u8,
    notes: ?[]const u8,
};

const Version = struct {
    meta: VersionMeta,
    architecture: std.StringHashMap(Source),
};

const ReleaseHistory = struct {
    versions: std.StringHashMap(Version),

    const Self = @This();

    pub fn init(allocator: std.mem.Allocator) Self {
        return .{
            .versions = .init(allocator),
        };
    }
};

fn fetchIndex(io: std.Io, allocator: std.mem.Allocator) !json.Parsed(json.Value) {
    var client = http.Client{
        .allocator = allocator,
        .io = io
    };
    defer client.deinit();

    var body: std.Io.Writer.Allocating = .init(allocator);
    defer body.deinit();

    const result = try client.fetch(.{
        .location = .{ .url = ziglang_releases },
        .method = .GET,
        .headers = .{
            .user_agent = .{
                .override = "zivm/0.1.0",
            },
        },
        .response_writer = &body.writer,
    });

    if (result.status != .ok) {
        std.log.err("Failed to retrieve Zig Version History\nGot non 200 status code: Received {d}\n", .{ result.status });
        return error.FetchError;
    }

    return try json.parseFromSlice(json.Value, allocator, body.written(), .{ .ignore_unknown_fields = true });
}

fn buildHistory(allocator: std.mem.Allocator, index: json.Value) !ReleaseHistory {
    var release_history: ReleaseHistory = .init(allocator);
    switch (index) {
        .object => |obj| {
            var outer_itr = obj.iterator();
            while(outer_itr.next()) |entry| {
                const entry_key = entry.key_ptr.*;
                const entry_value = entry.value_ptr.*;

                var version: ?[]const u8 = null;
                var date: ?[]const u8 = null;
                var docs: ?[]const u8 = null;
                var std_docs: ?[]const u8 = null;
                var notes: ?[]const u8 = null;

                switch (entry_value) {
                    .object => |inner_obj| {
                        var itr = inner_obj.iterator();
                        var architecture: std.StringHashMap(Source) = .init(allocator);

                        while(itr.next()) |meta| {
                            const meta_key = meta.key_ptr.*;
                            const meta_value = meta.value_ptr.*;

                            if (std.mem.eql(u8, meta_key, "version")) {
                                switch (meta_value) {
                                    .string => |text| { version = text; },
                                    .null => {},
                                    else => return error.InvalidVersionField,
                                }
                            } else if (std.mem.eql(u8, meta_key, "date")) {
                                switch (meta_value) {
                                    .string => |text| { date = text; },
                                    .null => {},
                                    else => return error.InvalidDateField,
                                }
                            } else if (std.mem.eql(u8, meta_key, "docs")) {
                                switch (meta_value) {
                                    .string => |text| { docs = text; },
                                    .null => {},
                                    else => return error.InvalidDocsField,
                                }
                            } else if (std.mem.eql(u8, meta_key, "stdDocs")) {
                                switch (meta_value) {
                                    .string => |text| { std_docs = text; },
                                    .null => {},
                                    else => return error.InvalidStdDocsField,
                                }
                            } else if (std.mem.eql(u8, meta_key, "notes")) {
                                switch (meta_value) {
                                    .string => |text| { notes = text; },
                                    .null => {},
                                    else => return error.InvalidNotesField,
                                }
                            } else if (meta_value == .object) {
                                const parsed = try json.parseFromValue(Source, allocator, meta_value, .{ .ignore_unknown_fields =  true });
                                defer parsed.deinit();
                                const source: Source = .{
                                    .tarball = try allocator.dupe(u8, parsed.value.tarball),
                                    .shasum = try allocator.dupe(u8, parsed.value.shasum),
                                    .size = parsed.value.size,
                                };
                                try architecture.put(try allocator.dupe(u8, meta_key), source);
                            }
                        }
                        
                        const required_docs = docs orelse return error.RequiredFieldDocs;

                        const v: Version = .{
                            .meta = .{
                                .version = if (version != null) try allocator.dupe(u8, version.?) else null,
                                .date = if (date != null) try allocator.dupe(u8, date.?) else null,
                                .docs = try allocator.dupe(u8, required_docs),
                                .notes = if (notes != null) try allocator.dupe(u8, notes.?) else null,
                                .std_docs = if (std_docs != null) try allocator.dupe(u8, std_docs.?) else null,
                            },
                            .architecture = architecture,
                        };
                        try release_history.versions.put(try allocator.dupe(u8, entry_key), v);
                    },
                    else => {},
                }

                // release_history.versions.put(version, )
            }
        },
        else => {},
    }

    return release_history;
}

pub fn main(init: std.process.Init) !void {
    const allocator = init.arena.allocator();

    var gpa = std.heap.DebugAllocator(.{}){};
    defer _ = gpa.deinit();

    const temp_allocator = gpa.allocator();
    const parsed_json = try fetchIndex(init.io, temp_allocator);
    defer parsed_json.deinit();

    const release_history = try buildHistory(allocator, parsed_json.value);
    _ = release_history;
}

