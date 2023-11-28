const std = @import("std");
const Allocator = std.mem.Allocator;
const EnvMap = std.process.EnvMap;
const trim = @import("trimstr").trim;

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
        const next_line = next(bytes[cursor..], '\n');
        cursor += next_line.len + 1;
        const line = trim(next_line);

        if (line.len == 0) {
            continue;
        }

        const key = next(line, '=');
        var value: []const u8 = "";
        if (line.len > key.len) {
            value = next(line[key.len + 1 ..], '\n');
        }

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

    try std.testing.expect(envmap.hash_map.contains("test"));
    try std.testing.expect(envmap.hash_map.contains("vart"));

    try std.testing.expectEqualStrings(envmap.get("test").?, "var1");
    try std.testing.expectEqualStrings(envmap.get("vart").?, "test1");
}

test "parse empty lines" {
    var envmap = EnvMap.init(std.testing.allocator);
    defer envmap.deinit();

    var bytes =
        \\test=var1
        \\
        \\vart=test
    ;

    try parse(bytes, &envmap, false);

    try std.testing.expect(envmap.hash_map.contains("test"));
    try std.testing.expect(envmap.hash_map.contains("vart"));

    try std.testing.expectEqualStrings(envmap.get("test").?, "var1");
    try std.testing.expectEqualStrings(envmap.get("vart").?, "test");
}

test "parse empty line w/ whitespace" {
    var envmap = EnvMap.init(std.testing.allocator);
    defer envmap.deinit();

    var bytes =
        \\test=var1
        \\  
        \\vart=test
    ;

    try parse(bytes, &envmap, false);

    try std.testing.expect(envmap.hash_map.contains("test"));
    try std.testing.expect(envmap.hash_map.contains("vart"));

    try std.testing.expectEqualStrings(envmap.get("test").?, "var1");
    try std.testing.expectEqualStrings(envmap.get("vart").?, "test");
}

test "parse line without value" {
    var envmap = EnvMap.init(std.testing.allocator);
    defer envmap.deinit();

    var bytes =
        \\test
        \\
        \\vart=test
    ;

    try parse(bytes, &envmap, false);
    try std.testing.expect(envmap.hash_map.contains("test"));
    try std.testing.expect(envmap.hash_map.contains("vart"));
    try std.testing.expectEqualStrings(envmap.get("test").?, "");
    try std.testing.expectEqualStrings(envmap.get("vart").?, "test");
}
