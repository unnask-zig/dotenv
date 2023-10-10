const std = @import("std");
const Allocator = std.mem.Allocator;
const testing = std.testing;
const EnvMap = std.process.EnvMap;

const KVPairsSpan = std.ArrayList([]const u8);

/// Loads a .env file for reading, returning an ArrayList([]u8) with
/// one line per element.
///
/// @param - allocator - the allocator to use
/// @param - path - relative path to the .env file
///
/// @return - errorsets - Allocator.Error, File.OpenError, Writer.Error
///         - ArrayList of file lines
///
fn initKVPairsSpan(allocator: Allocator, path: []const u8) !KVPairsSpan {
    var file = try std.fs.cwd().openFile(path, .{});
    defer file.close();

    var buf = std.io.bufferedReader(file.reader());
    var reader = buf.reader();
    var spans = KVPairsSpan.init(allocator);
    var kvspan = std.ArrayList(u8).init(allocator);
    defer kvspan.deinit();

    rall: while (true) {
        reader.streamUntilDelimiter(kvspan.writer(), '\n', null) catch |err| switch (err) {
            error.EndOfStream => {
                break :rall;
            },
            else => |e| return e,
        };

        try spans.append(try kvspan.toOwnedSlice());
    }

    return spans;
}

/// Deinitialize the ArrayList returned from readEnvFile
fn deinitKVEnvSpan(allocator: Allocator, var_list: KVPairsSpan) void {
    for (var_list.items) |e| {
        allocator.free(e);
    }
    var_list.deinit();
}

/// Parse the env file entries and add them to the EnvMap.
///
/// @param - pairs - the loaded .env file
/// @param - env - the EnvMap to add the key value pairs to
/// @param - override - whether to override an existing key or not
/// @return - errorsets - Allocator.error, Reader.error
fn parseEnvFile(pairs: *KVPairsSpan, env: *EnvMap, override: bool) !void {
    for (pairs.items) |e| {
        var stream = std.io.fixedBufferStream(e);
        var reader = stream.reader();

        try reader.skipUntilDelimiterOrEof('=');
        const tmpPos = try stream.getPos();
        const pos = std.math.cast(usize, tmpPos) orelse e.len;

        var key = e[0 .. pos - 1];
        var value = e[pos..];

        if (override or (!override and !env.hash_map.contains(key))) {
            try env.put(key, value);
        }
    }
}

pub const DefaultConfig = struct {
    path: []const u8 = ".env",
    override: bool = false,
};

pub fn load(allocator: Allocator) !EnvMap {
    try load_conf(allocator, DefaultConfig{});
}

pub fn load_conf(allocator: Allocator, comptime config: anytype) !EnvMap {
    _ = config;
    _ = allocator;
}

test "readEnvFile happy path" {
    const span = try initKVPairsSpan(std.testing.allocator, ".env");
    defer {
        deinitKVEnvSpan(std.testing.allocator, span);
    }

    //for (span.items) |item| {
    //    std.debug.print("{s}", .{item});
    //}

    try std.testing.expectEqual(span.items.len, 2);
}

test "parseEnvFile happy path" {
    var env = try std.process.getEnvMap(std.testing.allocator);
    defer env.deinit();

    var tst = KVPairsSpan.init(std.testing.allocator);
    defer tst.deinit();

    try tst.append("test=var");
    try tst.append("test2=var2");

    try parseEnvFile(&tst, &env, false);

    //var iter = env.iterator();
    //while (iter.next()) |e| {
    //    std.debug.print("{s}={s}\n", .{ e.key_ptr.*, e.value_ptr.* });
    //}

    try std.testing.expect(env.get("test") != null);
    try std.testing.expect(env.get("test2") != null);
    try std.testing.expectEqualStrings(env.get("test").?, "var");
    try std.testing.expectEqualStrings(env.get("test2").?, "var2");
}
