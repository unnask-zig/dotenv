const std = @import("std");

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
const multi_bytes = whitespace_bytes[8..77];

fn findSingleByteWhitespace(byte: u8) bool {
    comptime var i: usize = 0;

    inline while (i < single_bytes.len) : (i += 1) {
        if (byte == single_bytes[i]) {
            return true;
        }
    }

    return false;
}

fn findMultibyteWhitespace(scalar: []const u8) bool {
    comptime var i: usize = 0;

    inline while (i < multi_bytes.len) : (i += 3) {
        const whitespace = multi_bytes[i..][0..3];
        if (std.mem.eql(u8, scalar, whitespace)) {
            return true;
        }
    }

    return false;
}

pub fn ltrim(value: []const u8) []const u8 {
    if (value.len == 0) {
        return value;
    }

    var idx: usize = 0;
    while (idx < value.len) {
        // Fortunately, all the UTF-8 multibyte whitespace are all 3 bytes,
        // so we can just look for this one condition, and otherwise check
        // for the single byte
        if (value[idx] & 0xf0 == 0xe0) {
            if (findMultibyteWhitespace(value[idx..][0..3])) {
                idx += 3;
                continue;
            }
            break;
        } else {
            if (findSingleByteWhitespace(value[idx])) {
                idx += 1;
                continue;
            }
            break;
        }
    }

    return value[idx..];
}

pub fn rtrim(value: []const u8) []const u8 {
    //todo write me
    return value;
}

pub fn trim(value: []const u8) []const u8 {
    return ltrim(rtrim(value));
}

test "ltrim ascii spaces" {
    var str = "     hello world   ";
    var cmp = ltrim(str);

    try std.testing.expectEqualStrings("hello world   ", cmp);
}
