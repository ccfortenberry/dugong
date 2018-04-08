--[[
	Curtis Fortenberry
	parseit.lua
	last rev.: 3/4/2018
	Lua module for a parser program
	
	Assignment 4 Exercise A
]]

local parseit = {}

lexit = require "lexit"

-- Lexit iteration
local iter          -- Iterator returned by lexit.lex
local state         -- State for above iterator (maybe not used)
local lexit_out_s   -- Return value #1 from above iterator
local lexit_out_c   -- Return value #2 from above iterator

-- Current lexeme
local lexeme = ""   -- String form of current lexeme
local lexcat = 0    -- Category of current lexeme:
					--  one of categories below, or 0 for past the end

-- Symbolic constants for AST
local STMT_LIST   = 1
local INPUT_STMT  = 2
local PRINT_STMT  = 3
local FUNC_STMT   = 4
local CALL_FUNC   = 5
local IF_STMT     = 6
local WHILE_STMT  = 7
local ASSN_STMT   = 8
local CR_OUT      = 9
local STRLIT_OUT  = 10
local BIN_OP      = 11
local UN_OP       = 12
local NUMLIT_VAL  = 13
local BOOLLIT_VAL = 14
local SIMPLE_VAR  = 15
local ARRAY_VAR   = 16

-- Utility Functions

-- advance
-- Go to next lexeme and load it into lexeme, lexcat.
-- Should be called once before any parsing is done.
-- Function init must be called before this function is called.
local function advance()
	-- Advance the iterator
	lexit_out_s, lexit_out_c = iter(state, lexit_out_s)

	-- If we're not past the end, copy current lexeme into vars
	if lexit_out_s ~= nil then
		lexeme, lexcat = lexit_out_s, lexit_out_c
		if lexcat == lexit.ID or
		lexcat == lexit.NUMLIT or
		lexeme == "]" or
		lexeme == ")" or
		lexeme == "true" or
		lexeme == "false" then
			lexit.preferOp()
		end
	else
		lexeme, lexcat = "", 0
	end
end


-- init
-- Initial call. Sets input for parsing functions.
local function init(prog)
	iter, state, lexit_out_s = lexit.lex(prog)
	advance()
end


-- atEnd
-- Return true if pos has reached end of input.
-- Function init must be called before this function is called.
local function atEnd()
	return lexcat == 0
end


-- matchString
-- Given string, see if current lexeme string form is equal to it. If
-- so, then advance to next lexeme & return true. If not, then do not
-- advance, return false.
-- Function init must be called before this function is called.
local function matchString(s)
	if lexeme == s then
		advance()
		return true
	else
		return false
	end
end


-- matchCat
-- Given lexeme category (integer), see if current lexeme category is
-- equal to it. If so, then advance to next lexeme & return true. If
-- not, then do not advance, return false.
-- Function init must be called before this function is called.
local function matchCat(c)
	if lexcat == c then
		advance()
		return true
	else
		return false
	end
end

-- Parse functions

-- parseit.parse
-- Parse function that parses a given program "prog"
-- Is exported
function parseit.parse(prog)
	-- Initialization
	init(prog)

	-- Get results from parsing
	local good, ast = parse_prog()  -- Parse start symbol
	local done = atEnd()

	-- And return them
	return good, done, ast
end

-- parse_program
-- Parsing function for nonterminal "program".
-- Function init must be called before this function is called.
function parse_prog()
	local good, ast
	
	good, ast = parse_stmt_list()
	return good, ast
end

-- parse_stmt_list
-- Parsing function for nonterminal "stmt_list".
-- Function init must be called before this function is called.
function parse_stmt_list()
	local good, ast, newast

	ast = { STMT_LIST }
	while true do
		if lexeme ~= "input"
		  and lexeme ~= "print"
		  and lexeme ~= "func"
		  and lexeme ~= "call"
		  and lexeme ~= "if"
		  and lexeme ~= "while"
		  and lexcat ~= lexit.ID then
			return true, ast
		end

		good, newast = parse_stmt()
		if not good then
			return false, nil
		end

		table.insert(ast, newast)
	end
end

-- parse_statement
-- Parsing function for nonterminal "statement"
-- Function init must be called before this function is called.
function parse_stmt()
	local good, ast1, ast2, savelex
	
	if matchString("input") then
		good, ast1 = parse_lvalue()
		if not good then
			return false, nil
		end
		
		return true, { INPUT_STMT, ast1 }

	elseif matchString("print") then
		good, ast1 = parse_print_arg()
		if not good then
			return false, nil
		end

		ast2 = { PRINT_STMT, ast1 }

		while true do
			if not matchString(";") then
				break
			end

			good, ast1 = parse_print_arg()
			if not good then
				return false, nil
			end

			table.insert(ast2, ast1)
		end

		return true, ast2

	elseif matchString("func") then
		savelex = lexeme
		if not matchCat(lexit.ID) then
			return false, nil
		end
		 
		good, ast1 = parse_stmt_list()
		if not good then
			return false, nil
		end
		
		if not matchString("end") then
			return false, nil
		end
		
		ast2 = { FUNC_STMT, savelex }
		table.insert(ast2, ast1)
		return true, ast2
		
	elseif matchString("call") then
		savelex = lexeme
		if not matchCat(lexit.ID) then
			return false, nil
		end
		
		return true, { CALL_FUNC, savelex }
		
	elseif matchString("if") then
		local ast = { IF_STMT }
		
		good, ast1 = parse_expr()
		if not good then
			return false, nil
		end
		
		table.insert(ast, ast1)
		
		good, ast2 = parse_stmt_list()
		if not good then
			return false, nil
		end
		
		table.insert(ast, ast2)
		
		while matchString("elseif") do
			good, ast1 = parse_expr()
			if not good then
				return false, nil
			end
			
			table.insert(ast, ast1)
			
			good, ast2 = parse_stmt_list()
			if not good then
				return false, nil
			end
			
			table.insert(ast, ast2)
		end
		
		if matchString("else") then
			good, ast2 = parse_stmt_list()
			if not good then
				return false, nil
			end
			
			table.insert(ast, ast2)
		end
		
		if not matchString("end") then
			return false, nil
		end
		
		return true, ast
		
	elseif matchString("while") then
		good, ast1 = parse_expr()
		if not good then
			return false, nil
		end
		
		good, ast2 = parse_stmt_list()
		if not good then
			return false, nil
		end
		
		if not matchString("end") then
			return false, nil
		end
		
		ast1 = { WHILE_STMT, ast1, ast2 }
		
		return true, ast1
		
	else
		good, ast1 = parse_lvalue()
		if not good then
			return false, nil
		end
		
		if matchString("=") then
			good, ast2 = parse_expr()
			if not good then
				return false, nil
			end
		else
			return false, nil
		end
		
		return true, { ASSN_STMT, ast1, ast2 }
	end
end

-- parse_print_arg
-- Parsing function for nonterminal "print_arg".
-- Function init must be called before this function is called.
function parse_print_arg()
	local good, ast, savelex
	
	savelex = lexeme
	if matchString("cr") then
		return true, { CR_OUT }
	elseif matchCat(lexit.STRLIT) then
		return true, { STRLIT_OUT, savelex }
	else
		good, ast = parse_expr()
		if not good then
			return false, nil
		end
		
		return true, ast
	end
end

-- parse_expr
-- Parsing function for nonterminal "expr".
-- Function init must be called before this function is called.
function parse_expr()
	local good, ast, saveop, newast
	
	good, ast = parse_comp_expr()
	if not good then
		return false, nil
	end

	while true do
		saveop = lexeme
		if not matchString("&&") and not matchString("||") then
			break
		end

		good, newast = parse_comp_expr()
		if not good then
			return false, nil
		end

		ast = { { BIN_OP, saveop }, ast, newast }
	end

	return true, ast
end

-- parse_comp_expr
-- Parsing function for nonterminal "comp_expr".
-- Function init must be called before this function is called.
function parse_comp_expr()
	local good, ast, newast, saveop
	
	saveop = lexeme
	if matchString("!") then
		good, newast = parse_comp_expr()
		if not good then
			return false, nil
		end
		
		ast = { { UN_OP, saveop }, newast }
		
	else
		good, ast = parse_arith_expr()
		if not good then
			return false, nil
		end
		
		while true do
			saveop = lexeme
			
			if not matchString("==") and 
			not matchString("!=") and 
			not matchString("<") and 
			not matchString("<=") and 
			not matchString(">") and 
			not matchString(">=") then
				break
			end
			
			good, newast = parse_arith_expr()
			if not good then
				return false, nil
			end
			
			ast = { { BIN_OP, saveop }, ast, newast}
		end
	end
	
	return true, ast
end

-- parse_arith_expr
-- Parsing function for nonterminal "arith_expr".
-- Function init must be called before this function is called.
function parse_arith_expr()
	local good, ast, saveop, newast
	
	good, ast = parse_term()
	if not good then
		return false, nil
	end

	while true do
		saveop = lexeme
		if not matchString("+") and not matchString("-") then
			break
		end

		good, newast = parse_term()
		if not good then
			return false, nil
		end

		ast = { { BIN_OP, saveop }, ast, newast }
	end

	return true, ast
end

-- parse_term
-- Parsing function for nonterminal "term".
-- Function init must be called before this function is called.
function parse_term()
	local good, ast, saveop, newast
	
	good, ast = parse_factor()
	if not good then
		return false, nil
	end

	while true do
		saveop = lexeme
		if not matchString("*") and 
		not matchString("/") and 
		not matchString("%") then
			break
		end

		good, newast = parse_factor()
		if not good then
			return false, nil
		end

		ast = { { BIN_OP, saveop }, ast, newast }
	end

	return true, ast
end

-- parse_factor
-- Parsing function for nonterminal "factor".
-- Function init must be called before this function is called.
function parse_factor()
	local savelex, good, ast
	
	savelex = lexeme
	
	if matchString("(") then
		good, ast = parse_expr()
		if not good then
			return false, nil
		end
		
		if not matchString(")") then
			return false, nil
		end
		
		return true, ast
		
	elseif matchString("+") or matchString("-") then
		good, ast = parse_factor()
		if not good then
			return false, nil
		end
		
		ast = { { UN_OP, savelex }, ast }
		
		return true, ast
		
	elseif matchString("call") then
		savelex = lexeme
		
		if not matchCat(lexit.ID) then
			return false, nil
		end
		
		return true, { CALL_FUNC, savelex }
		
	elseif matchCat(lexit.NUMLIT) then
		return true, { NUMLIT_VAL, savelex }
		
	elseif matchString("true") or matchString("false") then
		return true, { BOOLLIT_VAL, savelex }
		
	else
		good, ast = parse_lvalue()
		if not good then
			return false, nil
		end

		return true, ast
	
	end
end

-- parse_lvalue
-- Parsing function for nonterminal "lvalue".
-- Function init must be called before this function is called.
function parse_lvalue()
	local savelex, good, ast1, ast2
	
	savelex = lexeme
	
	if matchCat(lexit.ID) then
		
		if matchString("[") then
			ast1 = { ARRAY_VAR, savelex }
			
			good, ast2 = parse_expr()
			if not good then
				return false, nil
			end
			
			if not matchString("]") then
				return false, nil
			end
			
			table.insert(ast1, ast2)
			
			return true, ast1
		else
			return true, { SIMPLE_VAR, savelex }
		end
	else
		return false, nil
	end
end

return parseit