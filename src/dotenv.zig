const std = @import("std");
const Allocator = std.mem.Allocator;
const testing = std.testing;

const KeySpan = std.ArrayList([]u8);

/// Loads a .env file for reading, returning an ArrayList([]u8) with
/// one line per element.
///
/// @param - allocator - the allocator to use
/// @param - path - relative path to the .env file
///
/// @return - errorsets - Allocator.Error, File.OpenError, Writer.Error
///         - ArrayList of file lines
///
fn readEnvFile(allocator: Allocator, path: []const u8) !KeySpan {
    var file = try std.fs.cwd().openFile(path, .{});
    defer file.close();

    var buf = std.io.bufferedReader(file.reader());
    var reader = buf.reader();
    var buffer = KeySpan.init(allocator);
    var keyspan = std.ArrayList(u8).init(allocator);
    defer keyspan.deinit();

    rall: while (true) {
        reader.streamUntilDelimiter(keyspan.writer(), '\n', null) catch |err| switch (err) {
            error.EndOfStream => {
                break :rall;
            },
            else => |e| return e,
        };

        try buffer.append(try keyspan.toOwnedSlice());
    }

    return buffer;
}

/// Deinitialize the ArrayList returned from readEnvFile
fn deinitEnvList(allocator: Allocator, var_list: KeySpan) void {
    for (var_list.items) |e| {
        allocator.free(e);
    }
    var_list.deinit();
}

pub const DefaultConfig = struct {
    path: []const u8 = ".env",
};

pub fn load(allocator: Allocator) !void {
    try load_conf(allocator, DefaultConfig{});
}

pub fn load_conf(allocator: Allocator, comptime config: anytype) !void {
    _ = config;
    _ = allocator;
}

test "readEnvFile happy path" {
    const span = try readEnvFile(std.testing.allocator, ".env");
    defer {
        deinitEnvList(std.testing.allocator, span);
    }

    //for (span.items) |item| {
    //    std.debug.print("{s}", .{item});
    //}

    try std.testing.expectEqual(span.items.len, 2);
}
