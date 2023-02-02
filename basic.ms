// BASIC interpreter for Mini Micro

import "stringUtil"
import "listUtil"

isNumericChar = function(c)
	return (c >= "0" and c <= "9")
end function

isIdentifierChar = function(c)
	return (c >= "0" and c <= "9") or
	  (c >= "A" and c <= "Z") or
	  (c >= "a" and c <= "z") or
	  c == "_" or code(c) > 127
end function

isWhitespaceChar = function(c)
	return stringUtil.whitespace.indexOf(c) != null
end function

keywords = "PRINT GOTO IF THEN FOR END".split +
  "HOME SWEET".split +
  "NEW LIST".split

operators = "EQV IMP XOR OR AND NOT = <> < > <= >= + - * / \ MOD ^".split

// tokenize: take the given line af BASIC code and return a 
// list of tokens.  Numbers will be actual numbers in the token
// list; all others will be strings, with string literals 
// enclosed in quotes.  In case of a REMark, the text part
// of the remark will be an unquoted string.
tokenize = function(line)
	tokens = []
	p0 = 0
	lineLen = line.len
	while p0 < lineLen
		c = line[p0]
		if isWhitespaceChar(c) then
			p0 += 1
		else if c >= "0" and c <= "9" then
			// lex a number
			p1 = p0 + 1
			while p1 < lineLen and isNumericChar(line[p1])
				p1 += 1
			end while
			tokens.push line[p0:p1].val
			p0 = p1
		else if isIdentifierChar(c) then
			// lex an identifier or keyword
			p1 = p0 + 1
			while p1 < lineLen and isIdentifierChar(line[p1])
				p1 += 1
			end while
			tok = line[p0:p1]
			upperTok = tok.upper
			if keywords.contains(upperTok) then tok = upperTok
			tokens.push tok
			p0 = p1
		else if c == """" then
			// lex a quoted string literal
			p1 = p0 + 1
			while p1 < lineLen and line[p1] != """"
				p1 += 1
			end while
			if p1 >= lineLen then
				print "Unterminated string literal"
				return null
			end if
			tokens.push line[p0:p1+1]
			p0 = p1+1
		else if c == "?" then
			tokens.push "PRINT"
			p0 += 1
		else
			// unknown -- maybe an operator?
			tokens.push line[p0]
			p0 += 1
		end if
	end while
	return tokens
end function

int = function(x)
	if x >= 0 then return floor(x) else return ceil(x)
end function

// evalTokens: evaluate a tokenized expression.
//  For example, given [6, "*", 7], return 42.
evalTokens = function(tokens)
	stack = []
	
	doOneOp = function
		opB = stack.pop
		op = stack.pop
		opA = stack.pop		
		if op == "+" then
			stack.push opA + opB
		else if op == "-" then
			stack.push opA - opB
		else if op == "*" then
			stack.push opA * opB
		else if op == "/" then
			stack.push opA / opB
		else if op == "\" then
			stack.push int(int(opA) / int(opB))
		else if op == "MOD" then
			stack.push opA % opB
		else if op == "^" then
			stack.push opA ^ opB
		else if op == "=" then
			stack.push opA == opB
		else if op == "<>" then
			stack.push opA != opB
		else if op == "<" then
			stack.push opA < opB
		else if op == ">" then
			stack.push opA > opB
		else if op == "<=" then
			stack.push opA <= opB
		else if op == ">=" then
			stack.push opA >= opB	
		else if op == "EQV" then
			stack.push (opA != 0) == (opB != 0)	
		else if op == "IMP" then
			stack.push (opA == 0) or (opA != 0 and opB != 0)	
		else if op == "XOR" then
			stack.push (opA == 0) != (opB == 0)
		else if op == "OR" then
			stack.push (opA != 0) or (opB != 0)
		else if op == "AND" then
			stack.push (opA != 0) and (opB != 0)
		else if op == "NOT" then
			stack.push (opA == 0)
		else
			print "Unknown operator: " + op
			exit
		end if
//		print "Applied " + op + " to " + opA + " and " + opB + " to get " + stack[-1]
	end function
	
	pos = 0
	tokensLen = tokens.len
	while pos < tokensLen
		tok = tokens[pos]
		if tok isa number then
			// push a numeric operand
			stack.push tok
		else if tok[0] == """" then
			// push a string literal
			stack.push tok[1:-1]
		else
			// get an operator...
			opIdx = operators.indexOf(tok)
			while stack.len >= 3
				// process any higher-precedence operators already on the stack
				prevOpIdx = -1
				if stack.len > 1 then prevOpIdx = operators.indexOf(stack[-2])
				if opIdx > prevOpIdx then break
				doOneOp
			end while
			// then push the new operator
			stack.push tok
			//print "Pushed operator: " + tok
		end if
		pos += 1
	end while
	// finally, collapse the stack (which should be in precedence order)
	while stack.len >= 3
		doOneOp
	end while
	return stack[0]
end function

splitOnCommaOrSemicolon = function(tokens)
	result = []
	p0 = 0
	while p0 < tokens.len
		p1 = p0
		while true
			if p1 >= tokens.len or tokens[p1] == "," or tokens[p1] == ";" then
				result.push tokens[p0:p1]
				if p1 < tokens.len then result.push tokens[p1]
				break
			end if
			p1 += 1
		end while
		p0 = p1 + 1
	end while
	if p0 < tokens.len then result.push tokens[p0:]
	return result
end function

// execLine: execute one (already-tokenized) line of code.
// Used both in immediate mode, and when running a program.
// Note that the given tokens should NOT include a line number.
execLine = function(tokens)
	if not tokens then return
	cmd = tokens[0]
	if cmd == "PRINT" then
		// print a series of expressions, separated by , or ;
		series = splitOnCommaOrSemicolon(tokens[1:])
		needEOL = true
		i = 0; while i < series.len
			value = evalTokens(series[i])
			print value, ""
			if i+1 < series.len then
				if series[i+1] == "," then
					print " ", ""
				end if
				needEOL = false
			else
				needEOL = true
			end if
			i += 2
		end while
		if needEOL then print
	else if cmd == "GOTO" then
		if tokens.len != 2 or not (tokens[1] isa number) then
			print "Error: line number required for GOTO"
			globals.halt = true
			return
		end if
		globals.nextLine = tokens[1]
	else if cmd == "IF" then
		thenIdx = tokens.indexOf("THEN")
		if thenIdx == null then
			print "Error: THEN required after IF"
			globals.halt = true
			return
		end if
		if tokens.len != thenIdx + 2 then
			print "Error: line number required after THEN"
			globals.halt = true
			return
		end if
		value = evalTokens(tokens[1:thenIdx])
		if value != 0 then globals.nextLine = tokens[thenIdx+1]
	else if cmd == "HOME" then
		clear
		text.row = 26
		text.color = "#00CC00FF"
		text.backColor = color.clear
		gfx.clear color.black
	else if cmd == "SWEET" then
		print "HOME ", ""
		wait 0.1
		print "SWEET ", ""
		wait 0.1
	else if cmd == "END" then
		globals.halt = true
	else
		print "Unknown command: " + cmd
	end if
end function

// repl: handle raw input from the user, which may be an 
// immediate line, or (with a line number) alter the program,
// or may be a command that ONLY works in the repl (i.e. a
// shell command).
repl = function(line)
	tokens = tokenize(line)
	if not tokens then return
	cmd = tokens[0]
	if cmd isa string then cmd = cmd.upper
	if cmd isa number then
		lineNum = cmd
		if tokens.len == 1 then
			program.remove lineNum
		else
			program[lineNum] = tokens[1:]
		end if
	else if cmd == "NEW" then
		globals.program = {}
	else if cmd == "LIST" then
		listProgram
	else if cmd == "RUN" then
		runProgram
	else
		execLine tokens
	end if
end function

listProgram = function
	lineNums = program.indexes
	lineNums.sort
	for lineNum in lineNums
		print lineNum + " " + program[lineNum].join(" ")
	end for
end function

runProgram = function
	lineNums = program.indexes
	lineNums.sort
	lineNumIdx = 0
	globals.halt = false
	while not halt
		globals.nextLine = null
		execLine program[lineNums[lineNumIdx]]
		if not nextLine then
			lineNumIdx += 1
			if lineNumIdx >= lineNums.len then break
//			print "Advancing to line index " + lineNumIdx + ", which is " + lineNums[lineNumIdx]
		else
			lineNumIdx = lineNums.indexOf(nextLine)
		end if		
	end while
end function

// Machine State:
program = {}		// key: line number; value: tokens

runUnitTests = function
	errorCount = 0
	assertEqual = function(actual, expected, note)
		if actual != expected then
			print "Unit test failure (" + note + "): expected " + expected + ", got " + actual
			outer.errorCount = errorCount + 1
		end if
	end function

	assertEqual tokenize("10print""Hello""+42"), [10, "PRINT", """Hello""", "+", 42]
	assertEqual tokenize("10 ?""Hello""  +   42"), [10, "PRINT", """Hello""", "+", 42]

end function


execLine ["HOME"]
runUnitTests

print "MiniBasic 0.01"

// HACK For testing
repl "10 if 2+2 = 4 AND 3+3 = 6 then 30"
repl "20 ? ""math is broken"""
repl "25 end"
repl "30 ? ""math works!"""
repl "list"

basic = function
	reset
	load "basic"
	run
end function
_savedGlobals.basic = @basic

while true
	line = input(">")
	if line.lower == "exit" then break
	repl line
end while
