//! Deadline syntax: `YYYY-MM-DD HH:MM`, time of day required.

const std = @import("std");

pub const format = "YYYY-MM-DD HH:MM";

/// Reports whether `text` is a real calendar date and time in `format`.
pub fn isValid(text: []const u8) bool {
    if (text.len != format.len) return false;
    for (text, format) |actual, expected| {
        const matches = switch (expected) {
            'Y', 'M', 'D', 'H' => std.ascii.isDigit(actual),
            else => actual == expected,
        };
        if (!matches) return false;
    }
    const year = number(text[0..4]);
    const month = number(text[5..7]);
    const day = number(text[8..10]);
    if (month < 1 or month > 12) return false;
    if (day < 1 or day > daysInMonth(year, month)) return false;
    return number(text[11..13]) <= 23 and number(text[14..16]) <= 59;
}

/// Converts a run of ASCII digits to its value.
fn number(digits: []const u8) u16 {
    var value: u16 = 0;
    for (digits) |digit| value = value * 10 + (digit - '0');
    return value;
}

/// Returns the length of `month` (1-12) in `year`.
fn daysInMonth(year: u16, month: u16) u16 {
    const leap = (year % 4 == 0 and year % 100 != 0) or year % 400 == 0;
    return switch (month) {
        2 => if (leap) 29 else 28,
        4, 6, 9, 11 => 30,
        else => 31,
    };
}
