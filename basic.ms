// BASIC interpreter for Mini Micro

import "stringUtil"
import "listUtil"
import "mapUtil"
import "mathUtil"

//======================================================================
// Constants
//======================================================================

// Keywords, including all BASIC commands (but not including functions,
// which are defined as part of the Machine class):
keywords = "PRINT INPUT GOTO IF THEN ELSE FOR TO STEP NEXT END LET DIM REDIM".split +
  "COLOR LINE PLOT".split +
  "NEW LIST".split

// BASIC operators:
operators = "( ) EQV IMP XOR OR AND NOT = <> < > <= >= + - * / \ MOD ^".split

// Color palette: same as the C-64:
palette = ("#000000 #FFFFFF #880000 #AAFFEE #CC44CC #00CC55 #0000AA #EEEE77 " +
          "#DD8855 #664400 #FF7777 #333333 #777777 #AAFF66 #0088FF #BBBBBB").split


//======================================================================
// Small Helper Functions
//======================================================================

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

// int: lops of the decimal portion of the given number.
// This means rounding down for positive numbers, but
// rounding up for negative numbers.
int = function(x)
	if x >= 0 then return floor(x) else return ceil(x)
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

// findCloser: find the closing element that comes after the given
// opening position, properly skipping over nested pairs.  Note
// that we assume the opener is *before* startIdx.
list.findCloser = function(startIdx=0, opener="(", closer=")", endIndex=null)
	if endIndex == null then endIndex = self.len
	pos = startIdx
	numOpen = 0
	while pos < endIndex
		if self[pos] == opener then
			numOpen += 1
		else if self[pos] == closer then
			numOpen -= 1
			if numOpen < 0 then return pos
		end if
		pos += 1
	end while
end function

// findCloseParen: like findCloser, but special in that it checks for
// opening parens at the end of tokens, e.g. "A(".
list.findCloseParen = function(startIdx=0, endIndex=null)
	if endIndex == null then endIndex = self.len
	pos = startIdx
	numOpen = 0
	while pos < endIndex
		if self[pos] isa string and self[pos][-1] == "(" then
			numOpen += 1
		else if self[pos] == ")" then
			numOpen -= 1
			if numOpen < 0 then return pos
		end if
		pos += 1
	end while
end function

isIdentifier = function(s)
	if s isa number or not s then return false
	if keywords.contains(s) then return false
	return isIdentifierChar(s[0])
end function

isNumericId = function(s)
	return isIdentifier(s) and s[-1] != "$"
end function

isStringId = function(s)
	return isIdentifier(s) and s[-1] == "$"
end function

//======================================================================
// Lexer (i.e. tokenizer)
//======================================================================

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
			while p1 < lineLen and (isNumericChar(line[p1]) or line[p1] == ".")
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
			if p1 < lineLen and line[p1] == "$" then p1 += 1
			tok = line[p0:p1]
			upperTok = tok.upper
			if keywords.contains(upperTok) or operators.contains(upperTok) then tok = upperTok
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
			if p0+1 < lineLen and operators.contains(line[p0:p0+2]) then
				tokens.push line[p0:p0+2]
				p0 += 2
			else
				tokens.push line[p0]
				p0 += 1
			end if
		end if
	end while
	if tokens.len > 1 then
		// As a final pass, check for "-" before a number and after anything
		// except an identifier or number.  In that case, combine it with the
		// number (making it negative).  Also, combine '(' with a previous
		// identifier (this is a function call).
		for i in range(tokens.len-2, 0)
			if tokens[i] == "-" and tokens[i+1] isa number and
			  not (i > 0 and (tokens[i-1] isa number or isIdentifier(tokens[i-1]))) then
				tokens[i+1] = -tokens[i+1]
				tokens.remove i
			else if tokens[i+1] == "(" and isIdentifier(tokens[i]) then
				tokens[i] = tokens[i].upper + "("
				tokens.remove i+1
			end if
		end for
	end if
	return tokens
end function

//======================================================================
// Expression evaluation
//======================================================================

// evalTokens: evaluate a tokenized expression.
//  For example, given [6, "*", 7], return 42.
evalTokens = function(tokens)
//	print "evalTokens(" + tokens + ")"
	stack = []
	
	doBinop = function
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
		else
			return printErr("Unknown operator: " + op)
		end if
//		print "Applied " + op + " to " + opA + " and " + opB + " to get " + stack[-1]
	end function
	
	doUnaryOp = function
		opA = stack.pop
		op = stack.pop
		if op == "-" then
			stack.push -opA
		else if op == "NOT" then
			stack.push not (opA != 0)
		end if
//		print "Applied " + op + " to " + opA + " to get " + stack[-1]
	end function
	
	pos = 0
	tokensLen = tokens.len
	while pos < tokensLen
		tok = tokens[pos]
//		print stack + " <-- " + tok
		if tok isa string and tok.endsWith("(") then
			stack.push tok
		else if tok == ")" then
			// collapse stack back to opening "("
			while stack
//				print "Collapsing from (): " + stack
				if stack[-1] == "(" then
					stack.pop
					break
				else if stack.len > 1 and stack[-2] == "(" then
					stack.remove -2
					break
				else if stack.len > 1 and stack[-2] isa string and stack[-2].endsWith("(") then
					funcOrArrayName = stack[-2][:-1]
					stack.remove -2
					f = machine.fn.get(funcOrArrayName)
					array = machine.arrs.get(funcOrArrayName)
					if @f then
						stack[-1] = f(stack[-1])
					else if array != null then
						idx = stack[-1]
						if not idx isa number then return printErr("array index must be numeric")
						if idx < 0 or idx >= array.len then return printErr("out of bounds error on " + funcOrArrayName)
						stack[-1] = array[idx]
					else
						return printErr("unknown function or array " + funcName)
					end if
					break
				else if stack.len < 3 then
					return printErr("unmatched parentheses")
				end if
				doBinop
			end while
		else if tok isa number then
			// push a numeric operand
			stack.push tok
			if stack.len > 1 and stack[-2] == "-" and
					(stack.len == 2 or (stack[-3] isa string and 
					stack[-3].endsWith("("))) then
//				print "Doing unary op on: " + stack
				doUnaryOp
			end if
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
				doBinop
			end while
			// then push the new operator
			stack.push tok
			//print "Pushed operator: " + tok
		else
			// push the value of identifier
			if not machine.vars.hasIndex(tok) then
				// old BASICS assume a null value for undefined variables
				if tok.endsWith("$") then value = "" else value = 0
			else
				value = machine.vars[tok]
			end if
			stack.push value
			if stack.len > 1 and stack[-2] == "-" and
					(stack.len == 2 or (stack[-3] isa string and 
					stack[-3].endsWith("("))) then
//				print "Doing unary op on: " + stack	// ToDo: DRY
				doUnaryOp
			end if
		end if
		pos += 1
	end while
	// finally, collapse the stack (which should be in precedence order)
	while stack.len > 1
		if stack[-2] == "NOT" then
			doUnaryOp
		else if stack.len > 2 then
			doBinop
		else
			break
		end if
	end while
	return stack[0]
end function

//======================================================================
// Functions that use and/or modify the state of the virtual machine.
// (Includes the Machine class, but also some global helper methods.)
//======================================================================

printErr = function(err)
	print "Error: " + err
	exit
	machine.halt = true
end function

listProgram = function(remarksOnly = false)
	machine.sortLines
	for lineNum in machine.lineNums
		tokens = machine.program[lineNum]
		if remarksOnly and tokens[0] != "REM" then continue
		print lineNum + " " + tokens.join(" ")
	end for
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
		machine.runProgram
	else if cmd == "CAT" then
		dir
	else if cmd == "LOAD" then
		name = line[4:].trim + ".bas"
		lines = file.readLines(name)
		if lines == null then
			print "Unable to read program " + name
		else
			machine.reset
			for line in lines
				repl line
			end for
			print machine.program.len + " lines loaded from " + name
		end if
	else
		machine.doImmediate tokens
	end if
end function

ForLoopState = {}
ForLoopState.var = ""
ForLoopState.step = 1
ForLoopState.limit = 0
ForLoopState.topLineIdx = 0
ForLoopState.topTokenIdx = 0
ForLoopState.make = function(var, limit, step, topLine, topToken)
	fls = new ForLoopState
	fls.var = var
	fls.step = step
	fls.limit = limit
	fls.topLineIdx = topLine
	fls.topTokenIdx = topToken
	return fls
end function

// Machine State:
Machine = {}
Machine.program = {}		// key: line number; value: tokens
Machine.lineNums = []		// sorted list of line numbers
Machine.lineIdx = 0			// index into lineNums for current line
Machine.tokenIdx = 0		// which token starts the current statement in that line
Machine.nextLineIdx = 0		// index into lineNum for next line (if defined)
Machine.vars = {}			// key: identifier; value: value (scalars)
Machine.arrs = {}			// same, but for arrays (lists)
Machine.forLoops = []		// list of ForLoopState objects
Machine.halt = false		// flag to cause program to stop
Machine.inThen = false		// true while in a THEN of an if statement

// Define all the built-in functions
Machine.fn = {}
Machine.fn.ABS = function(n); return abs(n); end function
Machine.fn.ASC = function(s); return code(s); end function
Machine.fn.ATN = function(n); return atan(n); end function
Machine.fn["CHR$"] = function(n); return char(n); end function
Machine.fn.COS = function(n); return cos(n); end function
Machine.fn.EXP = function(n); return mathUtil.e ^ n; end function
Machine.fn.FIX = function(n); return int(n); end function
Machine.fn["INKEY$"] = function(z); return key.get; end function
Machine.fn.INT = function(n); return floor(n); end function
Machine.fn.LEN = function(s); return s.len; end function
Machine.fn.LOG = function(n); return mathUtil.ln(n); end function
Machine.fn.POS = function(z); return text.column; end function
Machine.fn.RND = function(n); if n < 0 then rnd(n); return rnd; end  function
Machine.fn.SGN = function(n); return sign(n); end function
Machine.fn.SIN = function(n); return sin(n); end function
Machine.fn["SPACES$"] = function(n); return " "*n; end function
Machine.fn.SPC = function(n); print " "*n,""; return ""; end function
Machine.fn.SQR = function(n); return sqrt(n); end function
Machine.fn["STR$"] = function(n); return str(n); end function
Machine.fn.TAB = function(n)
	if n > text.column then print
	text.column = n; 
	return ""
end function
Machine.fn.TAN = function(n); return tan(n); end function
Machine.fn.VAL = function(s); return val(s); end function

// Functions skipped for now -- maybe ToDo:
// HEX$ (convert number to hex)
// OCT$ (convert number to octal)
// INPUT$ (from MBASIC-80)
// INSTR (substring search)
// LEFT$, MID$, RIGHT$
// PEEK, POKE
// STRING$

// Define all the BASIC commands 
// (in alphabetical order below)
Machine.cmd = {}

Machine.cmd.CLEAR = function(tokens, startIdx, endIdx)
	machine.vars = {}
end function

Machine.cmd.COLOR = function(tokens, startIdx, endIdx)
	globals.arg = evalTokens(tokens[startIdx+1:endIdx])
	if arg isa number then
		gfx.color = palette[arg % palette.len]
	else if arg[0] == "#" then
		gfx.color = arg
	end if
	text.color = gfx.color
end function

Machine.cmd.DIM = function(tokens, startIdx, endIdx)
	if endIdx < startIdx + 2 then return printErr("incomplete DIM statement")
	pos = startIdx + 1
	while pos < endIdx
		name = tokens[pos]
		maxIndex = null
		if name[-1] == "(" then
			name = name[:-1]
			if pos+2 >= endIdx then return printErr("incomplete DIM statement")
			maxIndex = tokens[pos+1]
			if not maxIndex isa number then return printErr("DIM size must be a number")
			if tokens[pos+2] != ")" then return printErr("incomplete DIM statement")
			pos += 3
		else
			// no dimension given; default to 10
			maxIndex = 10
			pos += 1
		end if
		if not isIdentifier(name) then return printErr("identifier expected in DIM statement")
		if machine.arrs.hasIndex(name) then return printErr("array " + name + " already DIMensioned")
		if isNumericId(name) then
			machine.arrs[name] = [0] * (maxIndex+1)
		else
			machine.arrs[name] = [""] * (maxIndex+1)
		end if
		if pos < endIdx and tokens[pos] == "," then pos += 1
	end while
end function

Machine.cmd.END = function(tokens, startIdx, endIdx)
	machine.halt = true
end function
Machine.cmd.STOP = @Machine.cmd.END

Machine.cmd.FOR = function(tokens, startIdx, endIdx)
	if tokens.len < startIdx + 6 or tokens[startIdx+2] != "=" then
		return printErr("incomplete FOR statement")
	end if
	var = tokens[1]
	if not isIdentifier(var) then return printErr("invalid FOR loop variable")
	toPos = tokens.indexOf("TO", startIdx+3)
	if toPos == null or toPos >= endIdx then return printErr("incomplete FOR statement")
	stepPos = tokens.indexOf("STEP", startIdx+4)
	if stepPos == null or stepPos > endIdx then stepPos = endIdx
	fromVal = evalTokens(tokens[startIdx+3:toPos])
	toVal = evalTokens(tokens[toPos+1:stepPos])
	step = 1 // Too cool for BASIC: if fromVal >= toVal then step = 1 else step = -1
	if stepPos < endIdx then
		if tokens.len < stepPos+2 then return printErr("incomplete FOR statement")
		step = evalTokens(tokens[stepPos+1:endIdx])
	end if
	// ToDo: ensure we aren't already looping with this variable
	machine.vars[var] = fromVal
	if endIdx + 1 < tokens.len then
		lineIdx = machine.lineIdx; tokenIdx = endIdx + 1
	else
		lineIdx = machine.lineIdx + 1; tokenIdx = 0
	end if
	machine.forLoops.push ForLoopState.make(var, toVal, step, lineIdx, tokenIdx)
end function

Machine.cmd.GOTO = function(tokens, startIdx, endIdx)
	if endIdx != startIdx + 2 or not (tokens[1] isa number) then
		return printErr("line number required for GOTO")
	end if
	machine.goTo tokens[startIdx+1]	
end function

Machine.cmd.HOME = function(tokens, startIdx, endIdx)
	clear
	text.row = 26
	text.color = palette[5]
	gfx.color = text.color
	text.backColor = color.clear
	gfx.clear color.black
	gfx.plotPos = [0,0]
end function
Machine.cmd.CLS = @Machine.cmd.HOME

Machine.cmd.IF = function(tokens, startIdx, endIdx)
	// This seems like a very tricky case, because of multiple statements
	// per THEN and ELSE clause, and the possibility of nested IF-THEN-ELSE
	// statements.  But it's not so bad.  The rules are:
	//  1. If the condition is true, proceed to the nearest THEN,
	// 	   and when we hit ELSE, skip to the next line.
	//  2. If the condition is false, then find the matching ELSE
	//	   token, discounting as many ELSEs as we see THENs on the way.

	if endIdx >= tokens.len or tokens[endIdx] != "THEN" then	
		return printErr("THEN required after IF")
	end if
	if tokens.len < endIdx + 2 then
		return printErr("incomplete THEN clause")
	end if
	value = evalTokens(tokens[startIdx+1:endIdx])
	if value != 0 then
		// condition is true!  If THEN is followed by a number,
		// treat it as a GoTo; otherwise jump to that statement.
		machine.inThen = true
		if tokens[endIdx+1] isa number then
			machine.goTo tokens[endIdx+1]
			return
		else
			return endIdx + 1
		end if
	else
		// condition is false!  Find the matching ELSE clause, if any.
		extraElses = 0
		i = endIdx + 1
		while i < tokens.len
			if tokens[i] == "THEN" then extraElses += 1
			if tokens[i] == "ELSE" then
				extraElses -= 1
				if extraElses < 0 then
					// Found it!  If followed by a number,
					// treat it as a GoTo; otherwise jump to that statement.
					if tokens[i+1] isa number then
						machine.goTo tokens[i+1]
						return
					else
						return i+1
					end if
				end if
			end if
			i += 1
		end while
		// if we couldn't find a matching ELSE clause, then skip
		// the rest of this line
		return tokens.len
	end if
end function

Machine.cmd.INPUT = function(tokens, startIdx, endIdx)
	var = null
	if endIdx > startIdx + 1 then
		var = tokens[startIdx + 1]
		if not isIdentifier(var) then return printErr("invalid identifier for INPUT")
	end if
	value = input("?")
	if var then
		if var[-1] != "$" then value = value.val
		machine.vars[var] = value
	end if
end function

Machine.cmd.LET = function(tokens, startIdx, endIdx)
	if tokens[startIdx] == "LET" then startIdx += 1  // (skip LET, if present)
	lvar = tokens[startIdx]
	if lvar isa number or lvar[0] == """" then
		return printErr("can't assign to constant")
	end if
	if keywords.contains(lvar) then return printErr("can't assign to keyword")
	if lvar[-1] == "(" then
		// array element assignment
		// ToDo: rework this when our expression parser can report
		// how much it consumed.  For now:
		closeParenIdx = tokens.indexOf(")", startIdx+1)
		if closeParenIdx == null or endIdx < closeParenIdx+2 or tokens[closeParenIdx+1] != "=" then
			return printErr("incomplete LET statement")
		end if
		index = evalTokens(tokens[startIdx+1:closeParenIdx])
		lvar = lvar[:-1]
		array = machine.arrs.get(lvar)
		if array == null then return printErr("No array " + lvar + " has been DIMensioned")
		if index < 0 or index >= array.len then printErr("Out of bounds error on " + lvar)
		array[index] = evalTokens(tokens[closeParenIdx+2:endIdx])
	else
		// normal (scalar) assignment
		if endIdx < startIdx+2 or tokens[startIdx+1] != "=" then
			return printErr("incomplete LET statement")
		end if
		machine.vars[lvar] = evalTokens(tokens[startIdx+2:endIdx])
	end if
end function

Machine.cmd.LINE = function(tokens, startIdx, endIdx)
	// ToDo: when we have functions that take multiple arguments (and
	// so involve commas), we will need to change how this works.  We
	// really need our expression parser to just grab all it can, and
	// then return where it left off.
	// But for now, a quick hack:
	commaPos = tokens.indexOf(",", startIdx)
	if commaPos == null or commaPos >= endIdx then
		return printErr("Incomplete PLOT statement")
	end if
	x = evalTokens(tokens[startIdx+1:commaPos])
	y = evalTokens(tokens[commaPos+1:endIdx])
	gfx.line machine.plotPos[0], machine.plotPos[1], x, y, gfx.color
	machine.plotPos = [x,y]
end function

Machine.cmd.NEXT = function(tokens, startIdx, endIdx)
	// ToDo: handle NEXT arguments (one or more variable names)
	if not machine.forLoops then return printErr("NEXT without FOR")
	fls = machine.forLoops[-1]
	machine.vars[fls.var] += fls.step
	if fls.step > 0 and machine.vars[fls.var] > fls.limit or
	   fls.step < 0 and machine.vars[fls.var] < fls.limit then
		machine.forLoops.pop
	else
//		print "Sending machine to " + machine.lineNums[fls.topLineIdx] + " token " + fls.topTokenIdx
		machine.nextLineIdx = fls.topLineIdx
		return fls.topTokenIdx
	end if	
end function

Machine.cmd.PLOT = function(tokens, startIdx, endIdx)
	// ToDo: when we have functions that take multiple arguments (and
	// so involve commas), we will need to change how this works.  We
	// really need our expression parser to just grab all it can, and
	// then return where it left off.
	// But for now, a quick hack:
	commaPos = tokens.indexOf(",", startIdx)
	if commaPos == null or commaPos >= endIdx then
		return printErr("Incomplete PLOT statement")
	end if
	x = evalTokens(tokens[startIdx+1:commaPos])
	y = evalTokens(tokens[commaPos+1:endIdx])
	gfx.setPixel x, y, gfx.color
	machine.plotPos = [x,y]
end function

Machine.cmd.PRINT = function(tokens, startIdx, endIdx)
	// print a series of expressions, separated by , or ;
//	print "Printing " + tokens + " " + startIdx+":"+endIdx
	pos = startIdx + 1
	needEOL = true
	while pos < endIdx
		endPos = tokens.indexOfAny(",;", pos, tokens.len)
		if endPos > endIdx then endPos = endIdx
		value = evalTokens(tokens[pos:endPos])
//		print "Tokens " + pos + ":" + endPos + " evaluates to " + value
		print value, ""
		if endPos < endIdx then
			if tokens[endPos] == "," then print " ", ""
			needEOL = false
		else
			needEOL = true
		end if
		pos = endPos + 1
	end while
	if needEOL then print
end function

Machine.cmd.REM = function(tokens, startIdx, endIdx)
	// no action needed!
end function


// Run one statement within the given set of tokens,
// returning the token that starts the NEXT statement
// within the same set, or null if there are no more.
Machine.runOneStatement = function(tokens, startTokenIndex)
	if startTokenIndex >= tokens.len then return null
	cmd = tokens[startTokenIndex]
	if isIdentifier(cmd) then
		// check for the special case of an assignment statement without LET
		if cmd[-1] == "(" then
			assignPos = tokens.findCloseParen(startTokenIndex + 1) + 1
		else
			assignPos = startTokenIndex + 1
		end if
		if assignPos < tokens.len and tokens[assignPos] == "=" then cmd = "LET"
	end if
	statementEnd = tokens.indexOfAny([":","THEN","ELSE"], startTokenIndex)
	if statementEnd == null then statementEnd = tokens.len
	f = self.cmd.get(cmd)
//	print "calling cmd." + cmd + " with " + tokens + "[" + startTokenIndex + ":" + statementEnd + "]"
	if @f then
		// Most commands don't alter the next statement to run,
		// but a few do.  Give each one a chance to return the
		// next token index; but if they don't, just advance
		// past the delimiter (unless it's ELSE).
		nextStart = f(tokens, startTokenIndex, statementEnd)
		if nextStart == null then
			if statementEnd < tokens.len and tokens[statementEnd] == "ELSE" then
				if not machine.inThen then return printErr("Unexpected ELSE")
				nextStart = tokens.len
			else
				nextStart = statementEnd + 1
			end if
		end if
		return nextStart
	else
		printErr "Unknown command: " + cmd
		return null
	end if
end function

Machine.doImmediate = function(tokens)
	self.inThen = false
	self.halt = false
	self.tokenIdx = 0
	self.lineIdx = null
	while not self.halt and self.tokenIdx < tokens.len
		self.nextLineIdx = null
		self.tokenIdx = self.runOneStatement(tokens, self.tokenIdx)
		if self.lineIdx != null or self.nextLineIdx != null then break
	end while
end function

Machine.runProgram = function
	self.sortLines
	self.halt = false
	self.lineIdx = 0
	self.inThen = false
	while not self.halt and self.lineIdx < self.lineNums.len
		tokens = self.program[self.lineNums[self.lineIdx]]
		self.tokenIdx = 0
		while not self.halt and self.tokenIdx < tokens.len
			self.nextLineIdx = null
			self.tokenIdx = self.runOneStatement(tokens, self.tokenIdx)
			if self.nextLineIdx != null then break
		end while

		if not self.nextLineIdx then
			self.lineIdx += 1
			if self.lineIdx >= self.lineNums.len then break
//			print "Advancing to line index " + self.lineIdx + ", which is " + self.lineNums[self.lineIdx]
		else
			self.lineIdx = self.nextLineIdx
//			print "Jumping to line index " + self.lineIdx + ", which is " + self.lineNums[self.lineIdx]
		end if		
	end while
end function

Machine.sortLines = function
	self.lineNums = self.program.indexes
	self.lineNums.sort
end function

Machine.goTo = function(lineNum)
	self.nextLineIdx = self.lineNums.indexOf(lineNum)
	if self.nextLineIdx == null then
		printErr "Invalid line number: " + lineNum
	end if
end function

Machine.reset = function
	self.program = {}
	self.lineNums = []
	self.lineIdx = 0
	self.vars = {}
	self.forLoops = []
	self.plotPos = [0,0]
end function

machine = new Machine

//======================================================================
// Unit Tests.
// (...we should probably have many more of these!)
//======================================================================

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
	assertEqual tokenize("INT (6 * RND(1))"), ["INT(", 6, "*", "RND(", 1, ")", ")"]
end function

//======================================================================
// Main Program
//======================================================================

machine.reset
machine.cmd.HOME
runUnitTests

print "MiniBasic 0.02"

// HACK For testing
repl "10 if 2+2 = 4 AND 3+3 = 6 then print ""Yep!"": GOTO 30"
repl "20 ? ""math is broken"""
repl "25 end"
repl "30 ? ""math works!"""
repl "5 REM This is just a little test program."
repl "8 print ""Ready.."": ?""Set..."""
repl "50 for i = 1 to 4"
repl "60 print i"
repl "70 next"
repl "list"

basic = function
	reset
	load "/usr/basic"
	run
end function
_savedGlobals.basic = @basic

cd "/usr/programs"

// Main loop (invoking the REPL until done)
while true
	line = input(">")
	if line.lower == "exit" then break
	repl line
end while
