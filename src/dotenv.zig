const std = @import("std");
const Allocator = std.mem.Allocator;
const EnvMap = std.process.EnvMap;
const trim = @import("trimstr").trim;

inline fn next(bytes: []const u8, delimiter: u8) []const u8 {
    const pos = std.mem.indexOfPos(u8, bytes, 0, &[_]u8{delimiter}) orelse bytes.len;
    return bytes[0..pos];
}

/// parse accepts a string containing the whole environment file, a
/// std.process.EnvMap and a boolean of whether to override the EnvMap
/// values with those found in the environment file.
/// the EnvMap will be updated with key/value pairs from the environment
/// file.
/// the user maintains all memory ownership.
fn parse(bytes: []const u8, env: *EnvMap, override: bool) !void {
    var cursor: usize = 0;

    while (cursor < bytes.len) {
        const next_line = next(bytes[cursor..], '\n');
        cursor += next_line.len + 1;
        const line = trim(next_line);

        if (line.len == 0) {
            continue;
        }

        const key = trim(next(line, '='));
        var value: []const u8 = "";
        if (line.len > key.len) {
            value = trim(next(line[key.len + 1 ..], '\n'));
        }

        if (!env.hash_map.contains(key) or override) {
            try env.put(key, value);
        }
    }
}

/// readfile will read the entire file into an allocted buffer.
/// the user owns the returned buffer
fn readFile(allocator: Allocator, path: []const u8) ![]const u8 {
    var file = try std.fs.cwd().openFile(path, .{});
    defer file.close();

    const fsz = (try file.stat()).size;
    var br = std.io.bufferedReader(file.reader());
    var reader = br.reader();
    return try reader.readAllAlloc(allocator, fsz);
}

/// Configuration options for dotenv
pub const DotenvConf = struct {
    path: []const u8 = ".env",
    override: bool = false,
};

/// dotenvConf runs dotenv with the users passed in configuration options
/// returning a std.process.EnvMap containing key/value pairs from the
/// environment as well as the .env file (if it exists).
/// DotenfConf
///     .path default is ".env"
///     .override default is false
///
/// Set override to true if you wish to have the environment file values
/// override values from the environment. (Note that doing so should be
/// generally frowned upon as this poses substantial risk to accidentally
/// setting a value inappropriately.)
pub fn dotenvConf(allocator: Allocator, config: DotenvConf) !EnvMap {
    const env = readFile(allocator, config.path) catch "";
    defer allocator.free(env);

    var map = EnvMap.init(allocator);
    errdefer map.deinit();

    try parse(env, &map, config.override);

    return map;
}

/// dotenv runs dotenv with the default configuration options
/// returning a std.process.EnvMap containing key/value pairs from the
/// environment as well as the .env file (if it exists).
/// DotenfConf
///     .path default is ".env"
///     .override default is false
pub fn dotenv(allocator: Allocator) !EnvMap {
    return try dotenvConf(allocator, DotenvConf{});
}

test "parse happy path" {
    var envmap = EnvMap.init(std.testing.allocator);
    defer envmap.deinit();

    const bytes =
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

    const bytes =
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

    const bytes =
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

    const bytes =
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

test "dotenv default test file" {
    var envmap = try dotenv(std.testing.allocator);
    defer envmap.deinit();

    try std.testing.expect(envmap.hash_map.contains("test"));
    try std.testing.expect(envmap.hash_map.contains("file"));
    try std.testing.expectEqualStrings(envmap.get("test").?, "file");
    try std.testing.expectEqualStrings(envmap.get("file").?, "test");
}

test "dotenvconf set override" {
    var envmap = try dotenvConf(std.testing.allocator, DotenvConf{
        .override = false,
    });
    defer envmap.deinit();

    try std.testing.expect(envmap.hash_map.contains("test"));
    try std.testing.expect(envmap.hash_map.contains("file"));
    try std.testing.expectEqualStrings(envmap.get("test").?, "file");
    try std.testing.expectEqualStrings(envmap.get("file").?, "test");
}
