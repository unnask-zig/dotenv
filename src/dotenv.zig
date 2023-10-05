const std = @import("std");
const Allocator = std.mem.Allocator;
const testing = std.testing;

const KeySpan = std.ArrayList([]u8);

fn readEnvFile(path: []u8, allocator: Allocator) !KeySpan {
    var file = try std.fs.cwd().openFile(path, .{});
    defer file.close();

    var reader = std.io.bufferedReader(file.reader()).reader();
    var buffer = KeySpan.init(allocator);
    var keyspan = std.ArrayList(u8).init(allocator);
    defer keyspan.deinit();

    rall: while (true) {
        reader.streamUntilDelimiter(keyspan.writer(), '\n', null) catch |err| switch (err) {
            .EndOfStream => {
                break :rall;
            },
            else => |e| return e,
        };
    }

    return buffer;
}

pub fn Dotenv(comptime filepath: ?[]u8) type {
    return struct {
        const Self = @This();

        filename: []u8,
        allocator: Allocator,

        pub fn init(allocator: Allocator) Self {
            return Self{
                .filename = filepath.?,
                .allocator = allocator,
            };
        }

        pub fn readEnv(self: *Self, path: []const u8) !void {
            _ = path;
            _ = self;
        }

        pub fn parse(self: *Self, text: []u8) !void {
            _ = text;
            _ = self;
        }
    };
}

pub fn load(allocator: Allocator) Dotenv {
    return Dotenv(null).init(allocator);
}

pub fn load_file(allocator: Allocator, path: []u8) Dotenv {
    return Dotenv(path).init(allocator);
}
