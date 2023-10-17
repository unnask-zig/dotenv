const std = @import("std");
const Allocator = std.mem.Allocator;
const testing = std.testing;
const EnvMap = std.process.EnvMap;

const KVPairsSpan = std.ArrayList([]const u8);

//todo: this doc format sucks ass. zig doesnt really specify one. There's
//probably a better way

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
    errdefer spans.deinit();
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
fn parseEnvFile(pairs: *const KVPairsSpan, env: *EnvMap, override: bool) !void {
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

/// Gets the environment and attempts to add user defined env vars with a
/// default config.
/// If the given env file is not found, then this function is equivalent to
/// calling std.process.getEnvMap(allocator)
/// In the default config:
///     .path = ".env"
///     .override = "false"
/// @param - allocator - the allocator to use
///         note that it will be used multiple times (reading a file, getting env)
/// @return - std.process.EnvMap - caller owns and must call .deinit()
pub fn load(allocator: Allocator) !EnvMap {
    try load_conf(allocator, DefaultConfig{});
}

/// Gets the environment and attempts to add user defined env vars with a
/// with a user provided config.
/// If the given env file is not found, then this function is equivalent to
/// calling std.process.getEnvMap(allocator)
/// @param - allocator - the allocator to use
///         note that it will be used multiple times (reading a file, getting env)
/// @param - config - anytype struct that can contain any of the following fields:
///         path: []const u8    - path to the env file
///         override: bool      - whether to override values in EnvMap with those in the env file
/// @return - std.process.EnvMap - caller owns and must call .deinit()
pub fn load_conf(allocator: Allocator, config: anytype) !EnvMap {
    comptime {
        const tp = @TypeOf(config);
        switch (@typeInfo(tp)) {
            .Struct => |struct_info| {
                for (struct_info.fields) |field| {

                    //i wonder if maybe this is worse. maybe just check for the relevant
                    //fields existing.
                    //that way any struct providing the fields works
                    //on the other side, this is probably fine and prevents any typos

                    if (!@hasField(DefaultConfig, field.name)) {
                        @compileError("Dotenv conf supports fields path: []const u8 and override: bool\n");
                    }
                }
            },
            else => @compileError("load_conf expects a struct for config\n"),
        }
    }

    var conf = DefaultConfig{};
    if (@hasField(@TypeOf(config), "path")) {
        conf.path = config.path;
    }
    if (@hasField(@TypeOf(config), "override")) {
        conf.override = config.override;
    }

    var env = try std.process.getEnvMap(allocator);
    errdefer env.deinit();

    var dotenv = initKVPairsSpan(allocator, conf.path);
    if (dotenv) |*denv| {
        defer deinitKVEnvSpan(allocator, denv.*);
        try parseEnvFile(denv, &env, conf.override);
    } else |err| switch (err) {
        error.FileNotFound => {},
        else => |e| return e,
    }

    return env;
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

test "load_conf happy path" {
    //compiler error:
    //var env = try load_conf(std.testing.allocator, .{ .parth = ".env" });
    var env = try load_conf(std.testing.allocator, .{ .path = ".env" });
    env.deinit();
}

test "load_conf file does not exist" {
    var env = try load_conf(std.testing.allocator, .{ .path = "file.env" });
    env.deinit();
    // env should normally have variables even with a file that doesn't exist
    // I suppose the test could make sure the file doesn't exist, but oh well.
    try std.testing.expect(env.hash_map.count() > 0);

    // todo: maybe compare with std.process.EnvMap
}
