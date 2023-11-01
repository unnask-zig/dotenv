const std = @import("std");
const Allocator = std.mem.Allocator;
const EnvMap = std.process.EnvMap;

const whitespace_bytes = [_]u8{
    // ASCII + UTF-8 supported whitespace
    0x09, // U+0009 horizontal tab
    0x0a, // U+000A line feed
    0x0b, // U+000B vertical tab
    0x0c, // U+000C form feed
    0x0d, // U+000D carriage return
    0x20, // U+0020 space
    0x85, // U+0085 next line
    0xA0, // U+00A0 no-break space

    // UNICODE/UTF-8 multibyte characters marked as whitespace
    0xe1, 0x9a, 0x80, // U+1680 ogham space mark
    0xe2, 0x80, 0x80, // U+2000 en quad
    0xe2, 0x80, 0x81, // U+2001 em quad
    0xe2, 0x80, 0x82, // U+2002 en space
    0xe2, 0x80, 0x83, // U+2003 em space
    0xe2, 0x80, 0x84, // U+2004 three-per-em space
    0xe2, 0x80, 0x85, // U+2005 four-per-em space
    0xe2, 0x80, 0x86, // U+2006 six-per-em space
    0xe2, 0x80, 0x87, // U+2007 figure space
    0xe2, 0x80, 0x88, // U+2008 punctuation space
    0xe2, 0x80, 0x89, // U+2009 thin space
    0xe2, 0x80, 0x8a, // U+200A hair space
    0xe2, 0x80, 0xa8, // U+2028 line separator
    0xe2, 0x80, 0xa9, // U+2029 paragraph separator
    0xe2, 0x80, 0xaf, // U+202F narrow no-break space
    0xe2, 0x81, 0x9f, // U+205F medium mathematical space
    0xe3, 0x80, 0x80, // U+3000 ideographic space

    // Not marked whitespace but may be used or it
    0xe1, 0xa0, 0x8e, // U+180E mongolian vowel separator
    0xe2, 0x80, 0x8b, // U+200B zero width space
    0xe2, 0x80, 0x8c, // U+200C zero width non-joiner
    0xe2, 0x80, 0x8d, // U+200D zero width joiner
    0xe2, 0x81, 0xa0, // U+2060 word joiner
    0xef, 0xbb, 0xbf, // U+FEFF zero width non-breaking space
};

const single_bytes = whitespace_bytes[0..8];
const multi_bytes = whitespace_bytes[8..74];

fn trim(value: []const u8) []const u8 {
    if (value.len == 0) {
        return value;
    }

    //todo actually write it

    return value;
}

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
