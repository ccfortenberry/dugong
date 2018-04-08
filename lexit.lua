--[[
	Curtis Fortenberry
	lexit.lua
	last rev.: 2/21/2018
	Lua module for a lexer program
	
	Significant portions taken from in-class
	example written by Dr. Glenn G. Chappell
	
	Secret Message #3:
	May the Forth be with you!
]]

-- Module init
local lexit = {}

-- Public constants
lexit.KEY = 1
lexit.ID = 2
lexit.NUMLIT = 3
lexit.STRLIT = 4
lexit.OP = 5
lexit.PUNCT = 6
lexit.MAL = 7

-- Flag for preferOp()
local preferOpFlag = false

-- Table for category names
lexit.catnames = {
	"Keyword",
	"Identifier",
	"NumericLiteral",
	"StringLiteral",
	"Operator",
	"Punctuation",
	"Malformed"
}

-- Table for registered keywords
lexit.keywords = {
	"call",
	"cr",
	"else",
	"elseif",
	"end",
	"false",
	"func",
	"if",
	"input",
	"print",
	"true",
	"while"
}

-- Character-Type functions
-- Graciously borrowed from the class example

-- isLetter
-- Returns true if string ch is a letter character, false otherwise.
local function isLetter(ch)
	if ch:len() ~= 1 then
		return false
	elseif ch >= "A" and ch <= "Z" then
		return true
	elseif ch >= "a" and ch <= "z" then
		return true
	else
		return false
	end
end

-- isDigit
-- Returns true if string ch is a digit character, false otherwise.
local function isDigit(ch)
	if ch:len() ~= 1 then
		return false
	elseif ch >= "0" and ch <= "9" then
		return true
	else
		return false
	end
end

-- isWhitespace
-- Returns true if string ch is a whitespace character, false otherwise.
local function isWhitespace(ch)
	if ch:len() ~= 1 then
		return false
	elseif ch == " " or ch == "\t" or ch == "\n" or ch == "\r"
	  or ch == "\f" then
		return true
	else
		return false
	end
end

-- isIllegal
-- Returns true if string ch is an illegal character, false otherwise.
local function isIllegal(ch)
	if ch:len() ~= 1 then
		return false
	elseif isWhitespace(ch) then
		return false
	elseif ch >= " " and ch <= "~" then
		return false
	else
		return true
	end
end

-- isKeyword
-- Returns true if the passed lexeme is a keyword, else false
local function isKeyword(lexeme)
	for _,val in pairs(lexit.keywords) do
		if lexeme == val then
			return true
		end
	end
	return false
end

-- preferOp
-- Function that sets a flag to determine whether or not the
-- module follows the maximal munch rule for cases like "x+4"
-- for a given iteration
function lexit.preferOp()
	preferOpFlag = true
end

-- lexit lexit
function lexit.lex(prog)
	-- State variables
	local pos
	local state
	local ch
	local lexeme
	local cat
	local handlers
	
	-- Character utility functions
	-- also graciously borrowed from class example
	
	-- currChar
	-- Return the current character, at index pos in program. Return
	-- value is a single-character string, or the empty string if pos is
	-- past the end.
	local function currChar()
		return prog:sub(pos, pos)
	end

	-- nextChar
	-- Return the next character, at index pos+1 in program. Return
	-- value is a single-character string, or the empty string if pos+1
	-- is past the end.
	local function nextChar()
		return prog:sub(pos+1, pos+1)
	end
	
	-- (except this one)
	-- nextNextChar
	-- Return the next-next character, at index pos+2 in program. Return
	-- value is a single-character string, or the empty string if pos+2
	-- is past the end.
	local function nextNextChar()
		return prog:sub(pos+2, pos+2)
	end

	-- drop1
	-- Move pos to the next character.
	local function drop1()
		pos = pos+1
	end

	-- add1
	-- Add the current character to the lexeme, moving pos to the next
	-- character.
	local function add1()
		lexeme = lexeme .. currChar()
		drop1()
	end

	-- skipWhitespace
	-- Skip whitespace and comments, moving pos to the beginning of
	-- the next lexeme, or to program:len()+1.
	local function skipWhitespace()
		while true do
			while isWhitespace(currChar()) do
				drop1()
			end

			if currChar() ~= "#" then  -- Comment?
				break
			end
			drop1()

			while true do
				if currChar() == "\n" then
					drop1()
					break
				elseif currChar() == "" then  -- End of input?
				   return
				end
				drop1()
			end
		end
	end
	
	-- State constants
	local DONE		= 0
	local START		= 1
	local LETTER	= 2
	local DIGIT		= 3
	local EXP		= 4
	local EXPSIGNED	= 5
	local EXPDIG	= 6
	local STRING_DQ = 7
	local STRING_SQ = 8
	local PLUSMINUS = 9
	local LOGICOP	= 10
	local ANDOP		= 11
	local OROP		= 12
	
	-- State handler functions
	-- as seen in class example
	local function handle_DONE()
		io.write("ERROR: 'DONE' state should not be handled\n")
		assert(0)
	end

	local function handle_START()
		if isIllegal(ch) then
			add1()
			state = DONE
			category = lexit.MAL
		elseif isLetter(ch) or ch == "_" then
			add1()
			state = LETTER
		elseif isDigit(ch) then
			add1()
			state = DIGIT
		elseif ch == "\"" then
			add1()
			state = STRING_DQ
		elseif ch == "'" then
			add1()
			state = STRING_SQ
		elseif ch == "+" or ch == "-" then
			add1()
			state = PLUSMINUS
		elseif ch == "*" or ch == "/" or ch == "%" or ch == "[" or ch == "]" or ch == ";" then
			add1()
			state = DONE
			category = lexit.OP
		elseif ch == "=" or ch == "!" or ch == "<" or ch == ">" then
			add1()
			state = LOGICOP
		elseif ch == "&" then
			add1()
			state = ANDOP
		elseif ch == "|" then
			add1()
			state = OROP
		else
			add1()
			state = DONE
			category = lexit.PUNCT
		end
	end
	
	local function handle_LETTER()
		if isLetter(ch) or isDigit(ch) or ch == "_" then
			add1()
		else
			state = DONE
			if isKeyword(lexeme) then
				category = lexit.KEY
			else
				category = lexit.ID
			end
		end
	end
	
	local function handle_DIGIT()
		if isDigit(ch) then
			add1()
		elseif ch == "e" or ch == "E" then
			state = EXP
		else
			state = DONE
			category = lexit.NUMLIT
		end
	end
	
	local function handle_EXP()
		if isDigit(nextChar()) then
			add1()
			state = EXPDIG
		elseif nextChar() == "+" then
			state = EXPSIGNED
		else
			state = DONE
			category = lexit.NUMLIT
		end
	end
	
	local function handle_EXPSIGNED()
		if isDigit(nextNextChar()) then
			add1()
			add1()
			state = EXPDIG
		else
			state = DONE
			category = lexit.NUMLIT
		end
	end
	
	local function handle_EXPDIG()
		if isDigit(ch) then
			add1()
		else
			state = DONE
			category = lexit.NUMLIT
		end
	end
	
	local function handle_STRING_DQ()
		add1()
		if ch == "\n" then
			state = DONE
			category = lexit.MAL
		elseif ch == "" then
			state = DONE
			category = lexit.MAL
		elseif ch == '"' then
			state = DONE
			category = lexit.STRLIT
		end
	end
	
	local function handle_STRING_SQ()
		add1()
		if ch == "\n" then
			state = DONE
			category = lexit.MAL
		elseif ch == "" then
			state = DONE
			category = lexit.MAL
		elseif ch == "'" then
			state = DONE
			category = lexit.STRLIT
		end
	end
	
	local function handle_PLUSMINUS()
		if preferOpFlag then
			state = DONE
			category = lexit.OP
		else
			if isDigit(ch) then
				add1()
				state = DIGIT
			else
				state = DONE
				category = lexit.OP
			end
		end
	end
	
	local function handle_LOGICOP()
		if ch == "=" then
			add1()
			state = DONE
			category = lexit.OP
		else
			state = DONE
			category = lexit.OP
		end
	end
	
	local function handle_ANDOP()
		if ch == "&" then
			add1()
			state = DONE
			category = lexit.OP
		else
			state = DONE
			category = lexit.PUNCT
		end
	end
	
	local function handle_OROP()
		if ch == "|" then
			add1()
			state = DONE
			category = lexit.OP
		else
			state = DONE
			category = lexit.PUNCT
		end
	end
	
	-- Table of state handler functions
	handlers = {
		[DONE]		= handle_DONE,
		[START]		= handle_START,
		[LETTER]	= handle_LETTER,
		[DIGIT]		= handle_DIGIT,
		[EXP]		= handle_EXP,
		[EXPSIGNED]	= handle_EXPSIGNED,
		[EXPDIG]	= handle_EXPDIG,
		[STRING_DQ]	= handle_STRING_DQ,
		[STRING_SQ]	= handle_STRING_SQ,
		[PLUSMINUS]	= handle_PLUSMINUS,
		[LOGICOP]	= handle_LOGICOP,
		[ANDOP]		= handle_ANDOP,
		[OROP]		= handle_OROP
	}
	
	-- Iterator function
	-- again, borrowed from class example
	
	-- getLexeme
	-- Called each time through the for-in loop.
	-- Returns a pair: lexeme-string (string) and category (int), or
	-- nil, nil if no more lexemes.
	local function getLexeme(dum1, dum2)
		if pos > prog:len() then
			preferOpFlag = false
			return nil, nil
		end
		lexeme = ""
		state = START
		while state ~= DONE do
			ch = currChar()
			handlers[state]()
		end

		skipWhitespace()
		preferOpFlag = false
		return lexeme, category
	end
	
	-- The thin, meaty veil of lexit.lex
	pos = 1
	skipWhitespace()
	return getLexeme, nil, nil
end

-- Module return
return lexit