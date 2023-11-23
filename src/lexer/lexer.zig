const std = @import("std");

pub const Token = enum {
    // Reseverd keywords 
    And, Break, Do, Else, Elseif,
    End, False, For, Function, If, 
    In, Local, Nil, Not, Or,
    Repeat, Return, Then, True,
    Until, While, Out,

    // Operations
    BAnd, BOr, BXor, LShift, RShift, 
    Star, Div, IntDiv, Add, Minus,
    Mod, Set, SetMove, Equal, NotEqual,
    Gt, GtE, Lt, Lte, Count,

    // Simbols
    OBrace, CBrace, OBracket, CBracket,
    OSqBracket, CSqBracket, Comma, SemiCollon,
    Dot, DDot, Collon,

    // Input types
    String, Integer, Float, Identifiers,
    EOF,
};

pub const LexPosition = struct {
    pub pos: i64 = 0,
    pub line: i64 = 0,
    pub col: i64 = 0,
}

pub const Str = std.ArrayList(u8);
const IdsMap = std.StringHashMap(i32);
const StrMap = std.StringHashMap(*Str);

const LexError = anyerror;

pub fn Lexer(comptime buffer_size: u16) type {
    const LocalBufReader = std.io.BufferedReader(buffer_size, std.io.Reader);

    return struct {
        position: LexPosition,
        reader: LocalBufReader,
        allocator: std.mem.Allocator,
        buffer: [buffer_size]u8,
        ids_count: u32,
        strings: *StrMap,
        ids: *IdsMap,
        curr: u8 = 0,
        buf_pos: u16 = 0,
        readed: u16 = 0,

        const Self = @This();

        pub fn init(reader: std.io.Reader, allocator: std.mem.Allocator) *Self {
            var lexer = allocator.create(Self);
            var strings = allocator.create(StrMap);
            var ids = allocator.create(IdsMap);

            lexer.* = .{
                .position = .{ .pos = 0, .line = 0, .col = 0 },
                .reader = std.io.bufferedReaderSize(buffer_size, reader),
                .allocator = allocator,
                .buffer = undefined,
                .ids_count = 0,
                .strings = strings,
                .ids = ids
            };

            return lexer;
        }

        pub fn get_position(self: *Self) LexPosition {
            return self.position;
        }

        pub fn get_token(self: *Self) anyerror!Token {
            if (0 == self.readed || self.readed == self.buf_pos) {
                try self.read_more();
            }

            if (0 == self.readed) {
                return EOF;
            }

            self.curr = self.buffer[self.buf_pos];

            const tk = switch(self.curr) {
                '{' => OBrace,
                '}' => CBrace,
                '(' => OBracket,
                ')' => CBracket,
                '*' => Star,
                '+' => Add,
                ',' => Comma,
                ';' => SemiCollon,
                '[' => CSqBracket,
                '#' => Count,
                '%' => Mod,
                ':', '.', '>', '<', '=', '~', '&', '^', '|', '/' => self.consume_symbol(),
                '-' => if ('-' == self.peek()) self.consume_comment() else Minus,
                '\'' => self.consume_string(),
                '"' => self.consume_string(),
                '[' => if ('[' == self.peek()) self.consume_string() else OSqBracket,
                '0' ... '9' => self.consume_number(),
                '_', 'a' ... 'z', 'A' ... 'Z' => self.consume_id(),
                else => self.consume_ignore(),
            };

            self.buf_pos += 1;
            self.advance();

            return tk;
        }

        fn read_more(self: *Self) anyerror!void {
            self.buf_pos = 0;
            self.readed = try self.reader.read(self.buffer);
        }

        fn advance(self: *Self) *Self {
            var position: *LexPosition = &(self.position);
            position.pos += 1;
            position.col += 1;

            if (position.pos > 0 && self.buf_pos != 0) {
                self.buf_pos += 1;
            } 

            return self;
        }

        fn peek(self: *Self) anyerror!u8 {
            // end of buffer content
            if (self.buf_pos + 1 == self.readed) {
                try self.read_more();

                return if (self.readed > 0) self.buffer[0] else 0;
            }

            return self.buffer[self.buf_pos + 1];
        }

        /// TODO: other methods to consume string 
        fn consume_symbol(self: *Self) anyerror!Token {
            const curr = self.buffer[self.buf_pos];
            const next = self.peek();

            var tk: Token = undefined;

            self.advance();
            switch (curr) {
                ':' => {
                    tk = Collon;
                    if ('=' == next) {
                        self.advance();
                        tk = SetMove;
                    }
                },
                '.' => {
                    tk = Dot;
                    if ('.' == next) {
                        self.advance();
                        tk = DDot;
                    }
                },
                '>' => {
                    tk = Gt;
                    if ('=' == next) {
                        self.advance();
                        tk = GtE;
                    }
                },
                '<' => {
                    tk = Lt;
                    if ('=' == next) {
                        self.advance();
                        tk = Lte;
                    }
                },
                '~' => {
                    if ('=' != next) { return error.TokenNotFound; }
                    self.advance();
                    tk = NotEqual;
                },
                '=' => {
                    tk = Set;
                    if ('=' == next) { 
                        tk = Equal;
                        self.advance();
                    }
                },
                '&' => { tk = BAnd; },
                '^' => { tk = BXor; },
                '|' => { tk = BOr; },
                '/' => {
                    tk = Div;
                    if ('/' == next) {
                        tk = IntDiv;
                        self.advance();
                    }
                },
            }

            return tk;
        }

        fn consume_comment(self: *Self) anyerror!Token {
            self.advance()
            self.advance();

        }
    }
}