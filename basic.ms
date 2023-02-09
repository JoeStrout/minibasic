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
  "GOSUB RETURN DATA READ RESTORE".split +
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

// indexOfAny: return the smallest index of any of the options
// that occurs after the given startIdx;
// if none are found, return the given default.
list.indexOfAny = function(options, afterIdx=-1, defaultIfNotFound=null)
	bestResult = null
	for opt in options
		idx = self.indexOf(opt, afterIdx)
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
string.findCloser = @list.findCloser	// works for strings, too!

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

// indexOfAnyParenSavvy: just like indexOfAny, except that this method 
// ignores anything within pairs of parentheses (including tokens that
// end with an opening paren, like "ABS(").  This is often the right 
// way to find the comma that delineates the next argument to a function
// or whatever, as it will properly grab the entire expression, even
// if that expression contains function calls with commas in them.
list.indexOfAnyParenSavvy = function(options, afterIdx=-1, endIndex=null, defaultIfNotFound=null)
	if not options isa list then options = [options]
	if endIndex == null then endIndex = self.len
	pos = afterIdx + 1
	numOpen = 0
	while pos < endIndex
		item = self[pos]
		if numOpen == 0 and options.contains(item) then return pos
		if item isa string and item[-1] == "(" then
			numOpen += 1
		else if item == ")" then
			numOpen -= 1
		end if
		pos += 1
	end while
	return defaultIfNotFound
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

// Check tokens starting at startPos for one of these patterns:
//	fromNum, "-", toNum
//	"-", toNum
//	fromNum, "-"
//	fromAndToNum
// Return a little map with "from" and "to" keys set to the
// corresponding number, or null.
getRange = function(tokens, startPos=0)
	result = {"from":null, "to":null}
	if startPos >= tokens.len then return result
	if tokens.len == startPos+1 and tokens[-1] isa number and tokens[-1] < 0 then
		// special case: a pattern like "-42" has been lexed as a negative number.
		// But we want to treat it like ["-", 42]
		tokens.push abs(tokens[-1])
		tokens[-2] = "-"
	end if
	if tokens[startPos] == "-" then
		if tokens.len > startPos+1 then result.to = val(tokens[startPos+1])
		return result
	end if
	result.from = val(tokens[startPos])
	if tokens.len == startPos+1 then
		result.to = result.from
		return result
	end if
	if tokens.len <= startPos+2 or tokens[startPos+1] != "-" then return result
	result.to = val(tokens[startPos+2])
	return result		
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
		else if c >= "0" and c <= "9" or c == "." then
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

	debugPrint = function(s)
		//text.color = "#008800"; print s; text.color = gfx.color
	end function

	debugPrint "evalTokens(" + tokens + ")"
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
		debugPrint "Applied " + op + " to " + opA + " and " + opB + " to get " + stack[-1]
	end function
	
	doUnaryOp = function
		opA = stack.pop
		op = stack.pop
		if op == "-" then
			stack.push -opA
		else if op == "NOT" then
			stack.push not (opA != 0)
		end if
		debugPrint "Applied " + op + " to " + opA + " to get " + stack[-1]
	end function
	
	// Find the function call (or array lookup) in the stack; it will
	// be the thing closest to the top that looks like "ABC(".  Return
	// that, along with its arguments (stuff on the stack above that),
	// pulling all of these off the stack.  If no such thing is found
	// (before we get to an operator or start of stack), return null.
	pullCall = function
		pos = stack.len - 1
		while pos >= 0
			if stack[pos] isa string and stack[pos][-1] == "(" then
				// found it!  Grab the function and arguments, with commas...
				result = stack[pos:]
				// strip out the commas...
				for i in range(result.len-1, 1)
					if result[i] == "," then result.remove i
				end for
				// clear all that stuff off the stack
				while stack.len > pos; stack.pop; end while
				// and we're done
				return result
			end if
			pos -= 1
		end while
		return null
	end function

	// Collapse any binary and unary operators on the top of 
	// the stack.  This should proceed until we hit either the
	// bottom of the stack, or an open paren, or a comma.
	collapseStack = function
		debugPrint "Collapsing stack: " + stack
		while stack.len > 1
			if stack[-2] == "," then return
			if stack[-2] isa string and stack[-2][-1] == "(" then return			
			if stack[-2] == "NOT" or (stack.len > 2 and stack[-3][-1] == "(") then
				doUnaryOp
			else if stack.len > 2 then
				doBinop
			else
				break
			end if
		end while
		debugPrint "...collapsed to:  " + stack
	end function
	
	pos = 0
	tokensLen = tokens.len
	while pos < tokensLen
		tok = tokens[pos]
		debugPrint stack + " <-- " + tok
		if tok isa string and tok.endsWith("(") then
			stack.push tok
		else if tok == "," then
			// we've gotten a comma, which is a top-level grouper;
			// go ahead and collapse anything on the stack back to 
			// the previous comma or open-paren
			collapseStack
			stack.push tok
		else if tok == ")" then
			// collapse last argument, i.e. collapse stack back to opening "(" or ","
			collapseStack
			// Now, there are two cases.  Either this is a plain parenthesized
			// sub-expression, or it is a function/array call.
			// If it's a sub-expression, then the open paren must be the next-
			// to-last item in the stack.
			if stack[stack.len-2] == "(" then
				debugPrint "Ordinary parenthesized sub-expression found"
				// ...in this case, we just remove the open paren and we're done
				stack.remove stack.len-2
			else
				// otherwise, it should be a call
				call = pullCall
				if call then
					debugPrint "Evaluating a call: " + call
					funcOrArrayName = call[0][:-1]
					args = call[1:]; if args.len == 1 then args = args[0]
					f = machine.fn.get(funcOrArrayName)
					array = machine.arrs.get(funcOrArrayName)
					if @f then
						stack.push f(args)
					else if array != null then
						idx = args
						if not idx isa number then return printErr("array index must be numeric")
						if idx < 0 or idx >= array.len then return printErr("out of bounds error on " + funcOrArrayName)
						stack.push array[idx]
					else
						return printErr("unknown function or array " + funcOrArrayName)
					end if
				else if stack.len < 3 then
					return printErr("unmatched parentheses")
				end if
			end if
		else if tok isa number then
			// push a numeric operand
			stack.push tok
			if stack.len > 1 and stack[-2] == "-" and
					(stack.len == 2 or (stack[-3] isa string and 
					stack[-3].endsWith("("))) then
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
				doUnaryOp
			end if
		end if
		debugPrint "After handling " + tokens[pos] + ", stack is now: " + stack
		pos += 1
	end while
	// finally, collapse the stack (which should be in precedence order)
	collapseStack
	if stack.len > 1 then
		printErr "Syntax error -- extra stuff on stack: " + stack
	end if
	return stack[0]
end function

//======================================================================
// Functions that use and/or modify the state of the virtual machine.
// (Includes the Machine class, but also some global helper methods.)
//======================================================================

printErr = function(err)
	print "Error: " + err
	machine.halt = true
end function

syntaxColor = {}
syntaxColor.number = "#AAAAFF"
syntaxColor.string = "#88FF88"
syntaxColor.operator = "#FFFF88"
syntaxColor.punctuation = "#88FFFF"
syntaxColor.lineNum = "#888888"
syntaxColor.lineNumTarget = "#BBBBBB"
syntaxColor.rem = "#666666"
syntaxColor.comment = "#FFFFFF"
syntaxColor.keyword = "#FF88FF"
syntaxColor.colon = syntaxColor.lineNum

listOneLine = function(lineNum, tokens)
	if machine.comeFrom.hasIndex(lineNum) then
		text.color = syntaxColor.lineNumTarget
	else
		text.color = syntaxColor.lineNum
	end if
	print lineNum, " "
	space = ""
	for tok in tokens
		if tok == "REM" then
			text.color = syntaxColor.rem
			print space + tok, " "
			text.color = syntaxColor.comment
			print tokens[-1], ""
			break
		else if keywords.contains(tok) then
			text.color = syntaxColor.keyword
			print space + tok, " "
			space = ""
		else if tok == ":" then
			text.color = syntaxColor.colon
			print space + tok + " ", ""
			space = ""
		else if tok == "," or tok == ";" or tok == "(" or tok == ")" then
			text.color = syntaxColor.punctuation
			print tok, ""
			space = " " * (tok != "(")
		else if tok[-1] == "(" then
			id = tok[:-1]
			if isStringId(id) then text.color = syntaxColor.string else text.color = syntaxColor.number
			print space + id, ""
			tok = tok[-1]
			text.color = syntaxColor.punctuation
			print tok, ""
			space = ""
		else if operators.contains(tok) then
			text.color = syntaxColor.operator
			print space + tok, ""
			space = " "
		else if tok isa number or isNumericId(tok) then
			text.color = syntaxColor.number
			print space + tok, ""
			space = " "
		else if tok.startsWith("""") or isStringId(tok) then
			text.color = syntaxColor.string
			print space + tok, ""
			space = " "
		else
			// what is this?!
			text.color = "#FFAAAA"
			print space + tok, ""
			space = " "
		end if
	end for
	text.color = gfx.color
	print
end function

listProgram = function(lineRange, remarksOnly = false)
	machine.sortLines
	machine.findComeFroms
	for lineNum in machine.lineNums
		if lineRange.from != null and lineNum < lineRange.from then continue
		if lineRange.to != null and lineNum > lineRange.to then continue
		tokens = machine.program[lineNum]
		if remarksOnly and tokens[0] != "REM" then continue
		listOneLine lineNum, tokens
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
			if lineNum < 0 then return printErr("Line numbers must be nonnegative.")
			machine.program[lineNum] = tokens[1:]
		end if
	else if cmd == "NEW" then
		machine.reset
	else if cmd == "LIST" then
		listProgram getRange(tokens, 1)
	else if cmd == "LISTREM" then	// why didn't anyone else think of this?
		listProgram getRange(tokens, 1), true
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

ReturnStackEntry = {}
ReturnStackEntry.lineIdx = 0
ReturnStackEntry.tokenIdx = 0

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
Machine.returnStack = []	// stack of places to RETURN to (from GOSUB)
Machine.data = []			// collected data from DATA statements
Machine.nextDataIdx = 0		// which element of self.data to READ next
Machine.halt = false		// flag to cause program to stop
Machine.inThen = false		// true while in a THEN of an if statement

// Define all the built-in functions
// (in alphabetical order below)
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
Machine.fn["LEFT$"] = function(args)
	if not args isa list then return args
	s = args[0]
	if args.len > 1 then length = args[1] else length = s.len
	return s[:length]
end function
Machine.fn.LEN = function(s); return s.len; end function
Machine.fn.LOG = function(n); return mathUtil.ln(n); end function
Machine.fn["MID$"] = function(args)
	if not args isa list then return args
	s = args[0]
	if args.len > 1 then startPos = args[1] else startPos = 1
	if args.len > 2 then length = args[2] else length = s.len
	return s[startPos-1:startPos-1+length]
end function
Machine.fn.POS = function(z); return text.column; end function
Machine.fn["RIGHT$"] = function(args)
	if not args isa list then return args
	s = args[0]
	if args.len > 1 then length = args[1] else length = s.len
	return s[-length:]
end function
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

Machine.cmd.GOSUB = function(tokens, startIdx, endIdx)
	if endIdx != startIdx + 2 or not (tokens[1] isa number) then
		return printErr("line number required for GOSUB")
	end if
	returnTo = new ReturnStackEntry
	if endIdx + 1 < tokens.len then
		returnTo.lineIdx = machine.lineIdx; returnTo.tokenIdx = endIdx + 1
	else
		returnTo.lineIdx = machine.lineIdx + 1
	end if
	machine.returnStack.push returnTo
	machine.goTo tokens[startIdx+1]
	return 0
end function

Machine.cmd.GOTO = function(tokens, startIdx, endIdx)
	if endIdx != startIdx + 2 or not (tokens[1] isa number) then
		return printErr("line number required for GOTO")
	end if
	machine.goTo tokens[startIdx+1]
	return 0
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
			return 0
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
						return 0
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
		endPos = tokens.indexOfAnyParenSavvy([",",";"], pos-1, endIdx, endIdx)
//		print "Now to print: " + tokens[pos:endPos]
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

Machine.cmd.READ = function(tokens, startIdx, endIdx)
	var = null
	if endIdx > startIdx + 1 then
		var = tokens[startIdx + 1]
		if not isIdentifier(var) then return printErr("invalid identifier for READ")
	end if
	if machine.nextDataIdx >= machine.data.len then return printErr("out of DATA")
	value = machine.data[machine.nextDataIdx]
	if value isa string and value[0] == """" and value[-1] == """" then
		value = value[1:-1]
	end if
	machine.nextDataIdx += 1
	if var then
		if var[-1] != "$" then value = val(value)
		machine.vars[var] = value
	end if
end function

Machine.cmd.REM = function(tokens, startIdx, endIdx)
	// no action needed!
end function

Machine.cmd.RESTORE = function(tokens, startIdx, endIdx)
	machine.nextDataIdx = 0
end function

Machine.cmd.RETURN = function(tokens, startIdx, endIdx)
	if not machine.returnStack then return printErr("RETURN without GOSUB")
	returnTo = machine.returnStack.pop
	machine.nextLineIdx = returnTo.lineIdx
	return returnTo.tokenIdx
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

Machine.runOneLine = function
	tokens = self.program[self.lineNums[self.lineIdx]]
	if self.tokenIdx == null then self.tokenIdx = 0
	self.nextLineIdx = null
	while self.tokenIdx < tokens.len
		self.nextLineIdx = null
		self.tokenIdx = self.runOneStatement(tokens, self.tokenIdx)
		if self.halt then return
		if self.nextLineIdx != null then break
	end while

	if not self.nextLineIdx then
		self.lineIdx += 1
		self.tokenIdx = 0
		if self.lineIdx >= self.lineNums.len then return
//		print "Advancing to line index " + self.lineIdx + ", which is " + self.lineNums[self.lineIdx]
	else
		self.lineIdx = self.nextLineIdx
//		print "Jumping to line index " + self.lineIdx + ", which is " + self.lineNums[self.lineIdx] +
//		 ", at token " + self.tokenIdx
	end if
end function

Machine.runProgram = function
	self.sortLines
	self.findData
	self.halt = false
	self.lineIdx = 0
	self.inThen = false
	while not self.halt and self.lineIdx < self.lineNums.len
		self.runOneLine
	end while
end function

Machine.sortLines = function
	self.lineNums = self.program.indexes
	self.lineNums.sort
end function

// Gather all the data tokens in DATA statements into our Machine.data
// array.  NOTE: assumes that our lineNums array is up-to-date (i.e.
// that sortLines has already been called).
Machine.findData = function
	self.data = []
	for lineNum in self.lineNums
		line = self.program[lineNum]
		pos = 0
		while pos < line.len
			endPos = line.indexOf(":", pos)
			if endPos == null then endPos = line.len
			if line[pos] == "DATA" then
				for p in range(pos+1, endPos-1)
					if line[p] != "," then self.data.push line[p]
				end for
			end if
			pos = endPos + 1
		end while
	end for
end function

Machine.findComeFroms = function
	self.comeFrom = {}
	for kv in self.program
		lineNum = kv.key
		line = kv.value
		for i in range(0, line.len-2)
			if line[i] == "GOTO" then
				for j in range(i+1, line.len-1)
					target = line[j]
					if target == ":" then break
					if target isa number then self.comeFrom[target] = self.comeFrom.get(target, []) + [lineNum]
				end for
			else if line[i] == "GOSUB" or line[i] == "THEN" then
				target = line[i+1]
				if not target isa number then continue
				self.comeFrom[target] = self.comeFrom.get(target, []) + [lineNum]
			end if
		end for
	end for
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
			globals.actual = actual
			globals.expected = expected
		end if
	end function

	assertEqual tokenize("10print""Hello""+42"), [10, "PRINT", """Hello""", "+", 42]
	assertEqual tokenize("10 ?""Hello""  +   42"), [10, "PRINT", """Hello""", "+", 42]
	assertEqual tokenize("5-2"), [5, "-", 2]
	assertEqual tokenize("5*-2"), [5, "*", -2]
	assertEqual tokenize("5--2"), [5, "-", -2]
	assertEqual tokenize("INT (6 * RND(1))"), ["INT(", 6, "*", "RND(", 1, ")", ")"]
	
	a = tokenize("INT (6 * RND(1))")
	assertEqual a.indexOfAny([")", "*"]), 2
	assertEqual a.indexOfAny([")", "*"], 2), 5
	assertEqual a.indexOfAny([")", "*"], 5), 6
	assertEqual a.indexOfAny([")", "*"], 6), null
	assertEqual a.indexOfAny([")", "*"], 6, -1), -1
	assertEqual a.findCloseParen(1), 6
	
	a = tokenize("PRINT LEFT$(A$,5), MID$(A$,LEN(A$)/2), RIGHT$(A$,F(X,4))")
	assertEqual a.indexOfAnyParenSavvy(","), 6
	assertEqual a.indexOfAnyParenSavvy(",", 1), 3
	assertEqual a.indexOfAnyParenSavvy(",", 6), 16
	assertEqual a.indexOfAnyParenSavvy(",", 16), null
	
	assertEqual getRange([10, "-", 20]), {"from":10, "to":20}
	assertEqual getRange(["-", 20]), {"from":null, "to":20}
	assertEqual getRange([10, "-"]), {"from":10, "to":null}
	assertEqual getRange([10]), {"from":10, "to":10}
	assertEqual getRange([-20]), {"from":null, "to":20}
	
	if errorCount then exit
end function

//======================================================================
// Main Program
//======================================================================

machine.reset
machine.cmd.HOME
runUnitTests

print "MiniBasic 0.04"

// HACK For testing
repl "10 gosub 100: if 2+2 = 4 AND COS(0) = 1 then print ""Yep!"": GOTO 30"
repl "20 ? ""math is broken"""
repl "25 end"
repl "30 ? ""math works!"""
repl "40 gosub 100"
repl "5 REM This is just a little test program."
repl "8 print ""Ready..."";: ?""Set..."""
repl "50 A$ = ""Hello world!"""
repl "60 print LEFT$(A$, 5) + RIGHT$(A$, 1)"
repl "70 if SIN(1.5) < 0 THEN 20"
repl "80 END"
repl "100 REM Test Subroutine"
repl "110 print: print ""====="": print"
repl "120 return"
repl "90 DATA ""hello bob"", 123.45, -43"
repl "200 DATA 42, test, ""test with space"""
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
