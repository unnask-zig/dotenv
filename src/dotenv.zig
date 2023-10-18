const std = @import("std");
const Allocator = std.mem.Allocator;
const EnvMap = std.process.EnvMap;

fn readFile(allocator: Allocator, path: []const u8) ![]const u8 {
    var file = try std.fs.cwd().openFile(path, .{});
    defer file.close();

    var fsz = (try file.stat()).size;
    var br = std.io.bufferedReader(file.reader());
    var reader = br.reader();
    return try reader.readAllAlloc(allocator, fsz);
}

inline fn next(bytes: []const u8, delimiter: u8) []const u8 {
    const pos = std.mem.indexOfPos(u8, bytes, 0, &[_]u8{delimiter}) orelse bytes.len;
    return bytes[0..pos];
}

fn parse(bytes: []const u8, env: *EnvMap, override: bool) !void {
    var cursor: usize = 0;
    while (cursor < bytes.len - 1) {
        const line = next(bytes[cursor..], '\n');
        cursor += line.len + 1;

        const key = next(line, '=');
        const value = next(line[key.len + 1 ..], '\n');

        if (!env.hash_map.contains(key) or override) {
            try env.put(key, value);
        }
    }
}

test "parse happy path" {
    var envmap = EnvMap.init(std.testing.allocator);
    defer envmap.deinit();

    var bytes =
        \\test=var1
        \\vart=test1
    ;

    try parse(bytes, &envmap, false);
}
