const std = @import("std");
const build = @import("build.zig.zon");

pub fn printManifest() void {
    std.debug.print("{any}", .{ build.version });
}

test "print" {
    printManifest();
}
