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

keywords = "PRINT GOTO IF THEN FOR TO STEP NEXT END LET".split +
  "HOME SWEET".split +
  "NEW LIST".split

operators = "( ) EQV IMP XOR OR AND NOT = <> < > <= >= + - * / \ MOD ^".split

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
			if tok == "REM" then
				// special case: rest of the line is a remark
				if p0 < lineLen and line[p0] == " " then p0 += 1
				if p0 < lineLen then tokens.push line[p0:]
				p0 = lineLen
			end if
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
	if tokens.len > 1 then
		// As a final pass, check for "-" before a number and after anything
		// except an identifier or number.  In that case, combine it with the
		// number (making it negative).
		for i in range(tokens.len-2, 0)
			if tokens[i] == "-" and tokens[i+1] isa number and
			  not (i > 0 and (tokens[i-1] isa number or isIdentifier(tokens[i-1]))) then
				tokens[i+1] = -tokens[i+1]
				tokens.remove i
			end if
		end for
	end if
	return tokens
end function

int = function(x)
	if x >= 0 then return floor(x) else return ceil(x)
end function

// evalTokens: evaluate a tokenized expression.
//  For example, given [6, "*", 7], return 42.
evalTokens = function(tokens)
//	print "evalTokens(" + tokens + ")"
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
			return printErr("Unknown operator: " + op)
		end if
//		print "Applied " + op + " to " + opA + " and " + opB + " to get " + stack[-1]
	end function
	
	pos = 0
	tokensLen = tokens.len
	while pos < tokensLen
		tok = tokens[pos]
//		print stack + " <-- " + tok
		if tok == "(" then
			stack.push tok
		else if tok == ")" then
			// collapse stack back to opening "("
			while stack
				if stack[-1] == "(" then
					stack.pop
					break
				else if stack.len > 1 and stack[-2] == "(" then
					stack.remove -2
					break
				else if stack.len < 3 then
					return printErr("unmatched parentheses")
				end if
				doOneOp
			end while
		else if tok isa number then
			// push a numeric operand
			stack.push tok
		else if tok[0] == """" then
			// push a string literal
			stack.push tok[1:-1]
		else if operators.contains(tok) then
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
		else
			// push the value of identifier
			if not machine.vars.hasIndex(tok) then
				return printErr("undefined identifier: " + tok)
			end if
			stack.push machine.vars[tok]
		end if
		pos += 1
	end while
	// finally, collapse the stack (which should be in precedence order)
	while stack.len >= 3
		doOneOp
	end while
	return stack[0]
end function

// indexOfAny: return the smallest index of any of the options;
// or if none are found, return the given default.
list.indexOfAny = function(options, startIdx=0, defaultIfNotFound=null)
	bestResult = null
	for opt in options
		idx = self.indexOf(opt, startIdx)
		if idx != null and (bestResult == null or idx < bestResult) then
			bestResult = idx
		end if
	end for
	if bestResult != null then return bestResult
	return defaultIfNotFound
end function

isIdentifier = function(s)
	if s isa number or not s then return false
	if keywords.contains(s) then return false
	return isIdentifierChar(s[0])
end function

printErr = function(err)
	print "Error: " + err
	globals.halt = true
end function

// execLine: execute one (already-tokenized) line of code.
// Used both in immediate mode, and when running a program.
// Note that the given tokens should NOT include a line number.
execLine = function(tokens)
	if not tokens then return
	cmd = tokens[0]
	if cmd == "PRINT" then
		// print a series of expressions, separated by , or ;
		pos = 1
		needEOL = true
		while pos < tokens.len
			endPos = tokens.indexOfAny(",;", pos, tokens.len)
			value = evalTokens(tokens[pos:endPos])
			print value, ""
			if endPos < tokens.len then
				if tokens[endPos] == "," then print " ", ""
				needEOL = false
			else
				needEOL = true
			end if
			pos = endPos + 1
		end while
		if needEOL then print
	else if cmd == "GOTO" then
		if tokens.len != 2 or not (tokens[1] isa number) then
			return printErr("line number required for GOTO")
		end if
		machine.goTo tokens[1]
	else if cmd == "IF" then
		thenIdx = tokens.indexOf("THEN")
		if thenIdx == null then return printErr("THEN required after IF")
		if tokens.len != thenIdx + 2 then return printErr("line number required after THEN")
		value = evalTokens(tokens[1:thenIdx])
		if value != 0 then machine.goTo tokens[thenIdx+1]
	else if cmd == "LET" then
		if tokens.len < 4 or tokens[2] != "=" then return printErr("incomplete LET statement")
		if tokens[1] isa number or tokens[1][0] == """" then
			return printErr("can't assign to constant")
		end if
		if keywords.contains(tokens[1]) then return printErr("can't assign to keyword")
		machine.vars[tokens[1]] = evalTokens(tokens[3:])
	else if not keywords.contains(cmd) and tokens.len > 2 and tokens[1] == "=" then
		if tokens.len < 3 then return printErr("incomplete LET statement")
		if tokens[0] isa number or tokens[0][0] == """" then
			return printErr("can't assign to constant")
		end if
		if keywords.contains(tokens[0]) then return printErr("can't assign to keyword")
		machine.vars[tokens[0]] = evalTokens(tokens[2:])
	else if cmd == "FOR" then
		if tokens.len < 6 or tokens[2] != "=" then return printErr("incomplete FOR statement")
		if not isIdentifier(tokens[1]) then return printErr("invalid FOR loop variable")
		toPos = tokens.indexOf("TO")
		if toPos == null then return printErr("incomplete FOR statement")
		stepPos = tokens.indexOf("STEP"); if stepPos == null then stepPos = tokens.len
		var = tokens[1]
		fromVal = evalTokens(tokens[3:toPos])
		toVal = evalTokens(tokens[toPos+1:stepPos])
		step = 1
		if stepPos < tokens.len then
			if tokens.len < stepPos+2 then return printErr("incomplete FOR statement")
			step = evalTokens(tokens[stepPos+1:])
		end if
		// ToDo: ensure we aren't already looping with this variable
		machine.vars[var] = fromVal
		machine.forLoops.push ForLoopState.make(var, step, toVal)
		machine.forLoops[-1].topLineNum = machine.pc + 1
	else if cmd == "NEXT" then
		// ToDo: handle NEXT arguments (one or more variable names)
		if not machine.forLoops then return printErr("NEXT without FOR")
		fls = machine.forLoops[-1]
		machine.vars[fls.var] += fls.step
		if fls.step > 0 and machine.vars[fls.var] > fls.limit or
		   fls.step < 0 and machine.vars[fls.var] < fls.limit then
			machine.forLoops.pop
		else
			machine.nextPc = fls.topLineNum	// ToDo: and statement
		end if
	else if cmd == "CLEAR" then
		machine.vars = {}
	else if cmd == "HOME" then	// or CLS?
		clear
		text.row = 26
		text.color = "#00CC00FF"
		text.backColor = color.clear
		gfx.clear color.black
	else if cmd == "END" then
		machine.halt = true
	else if cmd == "REM" then
		// no action needed
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
			machine.program.remove lineNum
		else
			machine.program[lineNum] = tokens[1:]
		end if
	else if cmd == "NEW" then
		machine.reset
	else if cmd == "LIST" then
		listProgram
	else if cmd == "LISTREM" then	// why didn't anyone else think of this?
		listProgram true
	else if cmd == "RUN" then
		runProgram
	else
		execLine tokens
	end if
end function

listProgram = function(remarksOnly = false)
	machine.sortLines
	for lineNum in machine.lineNums
		tokens = machine.program[lineNum]
		if remarksOnly and tokens[0] != "REM" then continue
		print lineNum + " " + tokens.join(" ")
	end for
end function

runProgram = function
	machine.sortLines
	machine.halt = false
	machine.pc = 0
	while not machine.halt
		machine.nextPc = null
//		print "[" + machine.lineNums[machine.pc] + "] ", ""
		execLine machine.program[machine.lineNums[machine.pc]]
		if not machine.nextPc then
			machine.pc += 1
			if machine.pc >= machine.lineNums.len then break
//			print "Advancing to line index " + lineNumIdx + ", which is " + lineNums[lineNumIdx]
		else
			machine.pc = machine.nextPc
		end if		
	end while
end function

ForLoopState = {}
ForLoopState.var = ""
ForLoopState.topLineNum = 0
ForLoopState.topStatementNum = 0
ForLoopState.step = 1
ForLoopState.limit = 0
ForLoopState.make = function(var, step, limit)
	fls = new ForLoopState
	fls.var = var
	fls.step = step
	fls.limit = limit
	return fls
end function

// Machine State:
MachineState = {}
MachineState.program = {}		// key: line number; value: tokens
MachineState.lineNums = []		// sorted list of line numbers
MachineState.pc = 0				// index into lineNums for current line
MachineState.nextPc = 0			// index into lineNum for next line
MachineState.vars = {}			// key: identifier; value: value
MachineState.forLoops = []		// list of ForLoopState objects
MachineState.halt = false		// flag to cause program to stop
MachineState.sortLines = function
	self.lineNums = self.program.indexes
	self.lineNums.sort
end function
MachineState.goTo = function(lineNum)
	self.nextPc = self.lineNums.indexOf(lineNum)
	if self.nextPc == null then
		printErr "Invalid line number: " + lineNum
	end if
end function
MachineState.reset = function
	self.program = {}
	self.lineNums = []
	self.pc = 0
	self.vars = {}
	self.forLoops = []
end function
machine = new MachineState

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
	assertEqual tokenize("5-2"), [5, "-", 2]
	assertEqual tokenize("5*-2"), [5, "*", -2]
	assertEqual tokenize("5--2"), [5, "-", -2]	
end function


execLine ["HOME"]
runUnitTests

print "MiniBasic 0.01"

// HACK For testing
repl "10 if 2+2 = 4 AND 3+3 = 6 then 30"
repl "20 ? ""math is broken"""
repl "25 end"
repl "30 ? ""math works!"""
repl "5 REM This is just a little test program."
repl "50 for i = 1 to 4"
repl "60 print i"
repl "70 next"
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
