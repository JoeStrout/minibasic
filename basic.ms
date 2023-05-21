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
keywords = "PRINT INPUT ON GOTO IF THEN ELSE FOR TO STEP NEXT END LET DIM REDIM DEF FN".split +
  "GOSUB RETURN DATA READ RESTORE REM STOP".split +
  "BREAK CLEAR CLS HOME HTAB VTAB OFF GET WAIT SOUND OPEN CLOSE PRINT# INPUT# GET#".split +
  "COLOR LINE PLOT FILL RECT ELLIPSE POLY IMAGE PEN".split +
  "NEW LIST LISTREM CD PWD DIR CAT CATALOG LOAD SAVE RUN RENUMBER EDIT".split

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

stripQuotes = function(s)
	if s isa string and s.len > 1 and s[0] == """" and s[-1] == """" then return s[1:-1]
	return s
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
string.indexOfAny = @list.indexOfAny	// works for both!  :)

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
		if isOpenParen(self[pos]) then
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
		if isOpenParen(item) then
			numOpen += 1
		else if item == ")" then
			numOpen -= 1
		end if
		pos += 1
	end while
	return defaultIfNotFound
end function

isIdentifier = function(s)
	if not s isa string or not s then return false
	if keywords.contains(s) then return false
	return isIdentifierChar(s[0])
end function

isNumericId = function(s)
	return isIdentifier(s) and s[-1] != "$"
end function

isStringId = function(s)
	return isIdentifier(s) and s[-1] == "$"
end function

isStringLiteral = function(s)
	return s isa string and s and s[0] == """" and s[-1] == """"
end function

isOpenParen = function(tok)
	return tok isa string and tok and tok[-1] == "("
end function

// Make a multidimensional array, whose dimensions are defined
// by the given list.  E.g. when dims == [10,20,30], then the
// top-level resulting list has 11 elements (index 0 through 10),
// each of those has 21 elements, and each of *those* has 31
// elements initially set to the given defaultValue.
makeMultiDimArray = function(dims, defaultValue)
	if dims.len == 1 then return [defaultValue] * (dims[0] + 1)
	result = []
	remainingDims = dims[1:]
	for idx in range(0, dims[0])
		result.push makeMultiDimArray(remainingDims, defaultValue)
	end for
	return result
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

controlCPressed = function
	return key.pressed("c") and (key.pressed("left ctrl") or key.pressed("right ctrl"))
end function

inputOrControlC = function(prompt="")
	print prompt, ""
	// flash cursor until control-C pressed, or some other key is available
	t0 = time
	cursorOn = false
	showCursor = char(134) + " " + char(135) + char(8)
	hideCursor = " " + char(8)
	while true
		if controlCPressed then
			if cursorOn then print hideCursor, ""
			key.clear
			return char(3)
		end if
		if key.available then
			if cursorOn then print hideCursor, ""
			return input
		end if
		if time - t0 < 0.8 and not cursorOn then
			print showCursor, ""
			cursorOn = true
		end if
		if time - t0 >= 0.8 and cursorOn then
			print hideCursor, ""
			cursorOn = false
		end if
		if time - t0 > 1 then t0 += 1
		yield
	end while
end function

//======================================================================
// A little class to represent a "statement address" we can jump to
// (i.e., a line and statement index within that line)
//======================================================================
Address = {}; Address._name = "Address"
Address.lineIndex = 0
Address.statementIndex = 0
Address.make = function(lineIndex, statementIndex=0)
	result = new Address
	result.lineIndex = lineIndex
	result.statementIndex = statementIndex
	return result
end function
Address.next = function
	return Address.make(self.lineIndex, self.statementIndex + 1)
end function
Address.str = function
	return self.lineIndex + "#" + self.statementIndex
end function
Address.displayStr = function
	s = machine.lineNums[self.lineIndex]
	if self.statementIndex > 0 then s += "#" + self.statementIndex
	return s
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
	isData = false
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
			if isData then	// for DATA, continue to next comma or EOL
				isNumeric = true
				while p1 < lineLen and line[p1] != ","
					if not isWhitespaceChar(line[p1]) then isNumeric=false
					p1 +=1
				end while
				tok = line[p0:p1].trimRight
				if isNumeric then tok = tok.val
				tokens.push tok
			else
				tokens.push line[p0:p1].val
			end if
			p0 = p1
		else if isIdentifierChar(c) then
			// lex an identifier or keyword
			p1 = p0 + 1
			while p1 < lineLen and isIdentifierChar(line[p1])
				p1 += 1
			end while
			if isData then	// for DATA, continue to next comma or EOL
				while p1 < lineLen and line[p1] != ","; p1 +=1; end while
				tok = line[p0:p1]
			else
				if p1 < lineLen and (line[p1] == "$" or line[p1] == "#") then p1 += 1
				tok = line[p0:p1]
				upperTok = tok.upper
				if keywords.contains(upperTok) or operators.contains(upperTok) or
				  machine.fn.hasIndex(upperTok) then tok = upperTok
			end if
			tokens.push tok
			p0 = p1
			if tok == "REM" then
				// special case: rest of the line is a remark
				if p0 < lineLen and line[p0] == " " then p0 += 1
				if p0 < lineLen then tokens.push line[p0:]
				p0 = lineLen
			else if tok == "DATA" then
				// another special case: after DATA, we do very limited tokenizing,
				// taking everything between commas as a string (ignoring only 
				// commas in quotes)
				isData = true
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
		else if c == "?" and not isData then
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
		// except an identifier, number, or right paren.  In that case, combine it
		// with the number (making it negative).  Also combine "FN" with the following
		// identifier (these are user-defined functions).  Also, combine '(' with a 
		// previous identifier (this is a function call), and look for two-operator
		// combos (like "<" ">") which should be combined ("<>").
		for i in range(tokens.len-2, 0)
			toki = tokens[i]
			tokj = tokens[i+1]
			if toki == "-" and tokj isa number and
			  not (i > 0 and (tokens[i-1] isa number or tokens[i-1]==")" or isIdentifier(tokens[i-1]))) then
				tokens[i+1] = -tokens[i+1]
				tokens.remove i
			else if toki == "FN" and tokj isa string then
				tokens[i] = toki + " " + tokj
				tokens.remove i+1
			end if
			if i+1 >= tokens.len then continue
			tokj = tokens[i+1]
			if tokens[i+1] == "(" and isIdentifier(toki) and not operators.contains(toki) then
				tokens[i] = toki + "("
				tokens.remove i+1
			else if (toki == ">" or toki == "<") and "<>=".contains(tokj) then
				tokens[i] = toki + tokj
				tokens.remove i+1
			end if
		end for
	end if
	return tokens
end function

//======================================================================
// Syntax Tree Nodes (can be evaluated efficiently once built)
//======================================================================
SyntaxNode = {}
SyntaxNode.str = function
	return mapName(self.__isa)
end function

SNLiteral = new SyntaxNode
SNLiteral.value = null	// number or string, or null
SNLiteral.eval = function(customLocals); return self.value; end function
SNLiteral.str = function; return super.str + "(" + self.toCode + ")"; end function
SNLiteral.toCode = function
	if self.value isa number then return str(self.value)
	if self.value isa string then return """" + self.value.replace("""", """""") + """"
	return str(self.value)
end function
SNLiteral.make = function(value)
	result = new SNLiteral
	result.value = value
	return result
end function
SNLiteral.zero = SNLiteral.make(0)
SNLiteral.one = SNLiteral.make(1)

SNIdentifier = new SyntaxNode
SNIdentifier.ident = ""   // actual identifier, e.g. "X"
SNIdentifier.eval = function(customLocals); return getValue(self.ident, customLocals); end function
SNIdentifier.str = function; return self.ident.upper; end function
SNIdentifier.toCode = @SNIdentifier.str
SNIdentifier.make = function(ident)
	result = new SNIdentifier
	result.ident = ident
	return result
end function

SNBinop = new SyntaxNode
SNBinop.op = "?"
SNBinop.lhs = null
SNBinop.rhs = null
SNBinop.str = function
	return super.str + "(" + self.lhs.str + ", " + self.rhs.str + ")"
end function
SNBinop.make = function(class, a, op, b)
	result = new class
	result.lhs = a; result.op = op; result.rhs = b
	return result
end function

SNAdd = new SNBinop
SNAdd.eval = function(c); return self.lhs.eval(c) + self.rhs.eval(c); end function
SNAdd.make = function(a,b); return SNBinop.make(SNAdd, a, "+", b); end function

SNMult = new SNBinop
SNMult.eval = function(c); return self.lhs.eval(c) * self.rhs.eval(c); end function
SNMult.make = function(a,b); return SNBinop.make(SNMult, a, "*", b); end function

SNSub = new SNBinop
SNSub.eval = function(c); return self.lhs.eval(c) - self.rhs.eval(c); end function
SNSub.make = function(a,b); return SNBinop.make(SNSub, a, "-", b); end function

SNDiv = new SNBinop
SNDiv.eval = function(c); return self.lhs.eval(c) / self.rhs.eval(c); end function
SNDiv.make = function(a,b); return SNBinop.make(SNDiv, a, "/", b); end function

SNIDiv = new SNBinop
SNIDiv.eval = function(c); return int(int(self.lhs.eval) / int(self.rhs.eval)); end function
SNIDiv.make = function(a,b); return SNBinop.make(SNIDiv, a, "\", b); end function

SNMod = new SNBinop
SNMod.eval = function(c); return self.lhs.eval(c) % self.rhs.eval(c); end function
SNMod.make = function(a,b); return SNBinop.make(SNMod, a, "%", b); end function

SNPow = new SNBinop;
SNPow.eval = function(c); return self.lhs.eval(c) ^ self.rhs.eval(c); end function
SNPow.make = function(a,b); return SNBinop.make(SNPow, a, "^", b); end function

SNEq = new SNBinop
SNEq.eval = function(c); return self.lhs.eval(c) == self.rhs.eval(c); end function
SNEq.make = function(a,b); return SNBinop.make(SNEq, a, "=", b); end function

SNNotEq = new SNBinop
SNNotEq.eval = function(c); return self.lhs.eval(c) != self.rhs.eval(c); end function
SNNotEq.make = function(a,b); return SNBinop.make(SNNotEq, a, "<>", b); end function

SNLT = new SNBinop
SNLT.eval = function(c); return self.lhs.eval(c) < self.rhs.eval(c); end function
SNLT.make = function(a,b); return SNBinop.make(SNLT, a, "<", b); end function

SNGT = new SNBinop
SNGT.eval = function(c); return self.lhs.eval(c) > self.rhs.eval(c); end function
SNGT.make = function(a,b); return SNBinop.make(SNGT, a, ">", b); end function

SNLE = new SNBinop
SNLE.eval = function(c); return self.lhs.eval(c) <= self.rhs.eval(c); end function
SNLE.make = function(a,b); return SNBinop.make(SNLE, a, "<=", b); end function

SNGE = new SNBinop
SNGE.eval = function(c); return self.lhs.eval(c) >= self.rhs.eval(c); end function
SNGE.make = function(a,b); return SNBinop.make(SNGE, a, ">=", b); end function

SNEQV = new SNBinop
SNEQV.eval = function(c)
	opA = self.lhs.eval(c); opB = self.rhs.eval
	return (opA != 0) == (opB != 0)
end function
SNEQV.make = function(a,b); return SNBinop.make(SNEQV, a, "EQV", b); end function

SNIMP = new SNBinop
SNIMP.eval = function(c)
	opA = self.lhs.eval(c); opB = self.rhs.eval
	return (opA == 0) or (opA != 0 and opB != 0)
end function
SNIMP.make = function(a,b); return SNBinop.make(SNIMP, a, "IMP", b); end function

SNXOR = new SNBinop
SNXOR.eval = function(c)
	opA = self.lhs.eval(c); opB = self.rhs.eval
	return (opA == 0) != (opB == 0)
end function
SNXOR.make = function(a,b); return SNBinop.make(SNXOR, a, "XOR", b); end function

SNOR = new SNBinop
SNOR.eval = function(c)
	opA = self.lhs.eval(c); opB = self.rhs.eval
	return (opA != 0) or (opB != 0)
end function
SNOR.make = function(a,b); return SNBinop.make(SNOR, a, "OR", b); end function

SNAND = new SNBinop
SNAND.eval = function(c)
	opA = self.lhs.eval(c); opB = self.rhs.eval
	return (opA != 0) and (opB != 0)
end function
SNAND.make = function(a,b); return SNBinop.make(SNAND, a, "AND", b); end function

SNNOT = new SyntaxNode
SNNOT.eval = function(c)
	opA = self.operand.eval
	return not (opA != 0)
end function
SNNOT.str = function
	return super.str + "(" + self.operand.str + ")"
end function
SNNOT.make = function(x)
	result = new SNNOT
	result.operand = x
	return result
end function

SNArrayOrCall = new SyntaxNode
SNArrayOrCall.allowArrayRefs = false
SNArrayOrCall.eval = function(c)
	Evaluator.debugPrint "Evaluating a call: " + self.name
	funcOrArrayName = self.name
	args = []
	for n in self.args; args.push n.eval(c); end for
	f = machine.fn.get(funcOrArrayName)
	array = machine.arrs.get(funcOrArrayName)
	if @f == null and array == null then
		// Make sure the user isn't trying an invalid custom FN.
		if funcOrArrayName.len > 2 and funcOrArrayName[:2] == "FN" then
			printErr "Unknown custom function:" + funcOrArrayName
			return
		end if
		// old-BASIC quirk: even arrays exist automatically, as soon as they are
		// referenced, with 1 dimension and a size of 10.
		if isNumericId(funcOrArrayName) then array = [0]*11 else array = [""]*11
		machine.arrs[funcOrArrayName] = array
	end if
	if @f then
		// it's a function — invoke it!
		if not args then return printErr("argument required for function call")
 		if args.len == 1 then args = args[0]	// (pass single argument as scalar)
 		result = f(args)
 		if machine.halt then return
 		return result
	else if array != null then
		// it's an array; look up the value (walking through dimensions
		// of the array one at a time, until we have just a scalar left)
		for idx in args
			if not array isa list then return printErr("too many array indexes")
			if not idx isa number then return printErr("array index must be numeric")
			if idx < 0 or idx >= array.len then return printErr("out of bounds error on " + funcOrArrayName)
			array = array[idx]
		end for
		if array isa list and not self.allowArrayRefs then return printErr("not enough array indexes")
		return array
	else
		return printErr("unknown function or array " + funcOrArrayName)
	end if
end function
SNArrayOrCall.str = function
	strArgs = []
	for n in self.args; strArgs.push n.str; end for
	return self.name + "(" + join(strArgs, ",") + ")"
end function
SNArrayOrCall.make = function(name, indexNodes, allowArrayRefs=false)
	result = new SNArrayOrCall
	if name.len > 2 and name[:2] == "FN" and name[2] != " " then
		// normalize, e.g., FNSQ --> FN SQ
		name = "FN " + name[2:]
	end if
	result.name = name
	result.args = indexNodes
	if allowArrayRefs then result.allowArrayRefs = true
	return result
end function

//======================================================================
// Expression parser
//======================================================================

// SE (Stack Entry) class: represents one item (typically a SyntaxNode, 
//	raw value, operator, or identifier) in our stack.
SE = {}			// class to represent an operator (including `(` and `)`) on the stack
SE.content = null	// actual value or identifier or whatever
SE.type = null	// one of the following:
SE.node = "node"
SE.identifier = "identifier"
SE.number = "number"
SE.string = "string"
SE.list = "list"
SE.operator = "operator"
SE.paren = "paren"		// includes both '(' and ')', but not, e.g., 'ABS('.
SE.comma = "comma"
SE.make = function(content, type)
	result = new SE
	result.type = type
	result.content = content
	return result
end function
SE.makeVal = function(v)
	result = new SE
	se.type = se.node
	se.content = SNLiteral.make(v)
end function
SE.isValue = function
	return self.type == SE.node // ...or SE.number or self.type == SE.string or self.type == SE.list
end function
SE.isOpenParen = function
	return (self.type == SE.paren and self.content == "(") or
	  (self.type == SE.identifier and self.content[-1] == "(")
end function
SE.isOperator = function(op=null)
	if self.type != SE.operator then return false
	return op == null or self.content == op
end function
SE.toString = function
	if self.type == SE.node then return self.content.str
	return self.type + "(" + self.content + ")"
end function

Evaluator = {}
Evaluator.tokens = []
Evaluator.nextTokIdx = 0
Evaluator.endIdx = 0
Evaluator.done = function; return self.nextTokIdx >= self.endIdx; end function
Evaluator.stack = null	// list of SE
Evaluator.allowArrayRefs = false	// if true, let user pass entire array, e.g. A()

Evaluator.make = function(tokens, startIdx=0, endIdx=null)
	eval = new Evaluator
	eval.tokens = tokens
	eval.nextTokIdx = startIdx
	if endIdx == null then eval.endIdx = tokens.len else eval.endIdx = endIdx
	eval.stack = []
	return eval
end function

Evaluator.debugPrint = function(s)
	// Uncomment this line to see lots of helpful debugging output:
//	text.color = "#008800"; print s; text.color = gfx.color
end function

Evaluator.stackStr = function
	result = []
	for item in self.stack; result.push item.toString; end for
	return "[" + result.join(", ") + "]"
end function

Evaluator.push = function(content, type)
	if type == null then
		print "Invalid call to Evaluator.push"
		pprint stackTrace
		exit
	end if
	se = new SE
	se.content = content
	se.type = type
	self.stack.push se
end function

Evaluator.pushValue = function(value)
	if value isa number or value isa string then
		return self.push(SNLiteral.make(value), SE.node)
	else if value isa SyntaxNode then
		return self.push(value, SE.node)
	end if
	print "Invalid call to Evaluator.pushValue; got " + value
	pprint stackTrace
	exit
end function

Evaluator.popValue = function
	if not self.stack then return printErr("stack underflow")
	se = self.stack.pop
	if se.type == SE.node or se.type == SE.identifier then return se.content
	if se.type == SE.comma then return printErr("missing argument")
	print "Type mismatch in popValue; got: " + se
	pprint stackTrace
	exit
end function

Evaluator.popOperator = function
	if not self.stack then return printErr("stack underflow")
	se = self.stack.pop
	if se.type == SE.operator then return se.content
	print "Expected operator, got " + se.type + " in popOperator"
	pprint stackTrace
	exit
end function

Evaluator.doBinop = function
	opB = self.popValue
	if machine.halt then return
	op = self.popOperator
	if machine.halt then return
	opA = self.popValue
	if op == "+" then
		self.pushValue SNAdd.make(opA, opB)
	else if op == "-" then
		self.pushValue SNSub.make(opA, opB)
	else if op == "*" then
		self.pushValue SNMult.make(opA, opB)
	else if op == "/" then
		self.pushValue SNDiv.make(opA, opB)
	else if op == "\" then
		self.pushValue SNIDiv.make(opA, opB)
	else if op == "MOD" then
		self.pushValue SNMod.make(opA, opB)
	else if op == "^" then
		self.pushValue SNPow.make(opA, opB)
	else if op == "=" then
		self.pushValue SNEq.make(opA, opB)
	else if op == "<>" then
		self.pushValue SNNotEq.make(opA, opB)
	else if op == "<" then
		self.pushValue SNLT.make(opA, opB)
	else if op == ">" then
		self.pushValue SNGT.make(opA, opB)
	else if op == "<=" then
		self.pushValue SNLE.make(opA, opB)
	else if op == ">=" then
		self.pushValue SNGE.make(opA, opB)
	else if op == "EQV" then
		self.pushValue SNEQV.make(opA, opB)
	else if op == "IMP" then
		self.pushValue SNIMP.make(opA, opB)
	else if op == "XOR" then
		self.pushValue SNXOR.make(opA, opB)
	else if op == "OR" then
		self.pushValue SNOR.make(opA, opB)
	else if op == "AND" then
		self.pushValue SNAND.make(opA, opB)
	else
		return printErr("Unknown operator: " + op)
	end if
	self.debugPrint "Applied " + op + " to " + opA + " and " + opB + " to get " + self.stack[-1]
end function

Evaluator.doUnaryOp = function
	opA = self.popValue
	if machine.halt then return
	op = self.popOperator
	if machine.halt then return
	if op == "-" then
		self.pushValue SNSub.make(SNLiteral.zero, opA)
	else if op == "NOT" then
		self.pushValue SNNOT.make(opA)
	end if
	self.debugPrint "Applied " + op + " to " + opA + " to get " + self.stack[-1]
end function

// Find the function call (or array lookup) in the stack; it will
// be the thing closest to the top that looks like "ABC(".  Return
// that, along with its arguments (stuff on stack above that),
// pulling all of these off the stack.  If no such thing is found
// (before we get to an operator or start of stack), return null.
Evaluator.pullCall = function
	pos = self.stack.len - 1
	while pos >= 0
		if self.stack[pos].isOpenParen then
			// found it!  Grab the function and arguments, with commas...
			result = self.stack[pos:]
			// strip out the commas, and extract the values...
			if result.len > 1 then
				for i in range(result.len-1, 1)
					if result[i].type == SE.comma then
						result.remove i
					else if result[i].isValue then
						result[i] = result[i].content
					else
						return printErr("Unexpected type in call argument: " + result[i])
					end if
				end for
			end if
			// clear all that stuff off stack
			while self.stack.len > pos; self.stack.pop; end while
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
Evaluator.collapseStack = function
	self.debugPrint "Collapsing self.stack: " + self.stackStr
	while self.stack.len > 1 and not machine.halt
		if self.stack[-2].type == SE.comma then return
		if self.stack[-2].isOpenParen then return
		if self.stack[-2].isOperator("NOT") or (self.stack.len > 2 and self.stack[-3].isOpenParen) then
			self.doUnaryOp
		else if self.stack.len > 2 then
			self.doBinop
		else if self.stack[-2].isOperator("-") then
			self.doUnaryOp
		else
			break
		end if
	end while
	self.debugPrint "...collapsed to:  " + self.stackStr
end function

// parse: evaluate a tokenized expression, returning a SyntaxNode that
// represents its whole parse tree.
Evaluator.parse = function()
	self.debugPrint "Evaluator.parse(" + self.tokens[self.nextTokIdx:self.endIdx] + ")"
	self.stack = []
	canBail = false	// marks points where we can bail out if we start a new value

	pos = self.nextTokIdx
	while pos < self.endIdx
		tok = self.tokens[pos]
		self.debugPrint self.stackStr + " <-- " + tok
		if tok == "(" then
			if canBail then break
			self.push tok, SE.paren
			canBail = false
		else if tok isa string and tok.endsWith("(") then	// e.g. ABS(
			if canBail then break
			self.push tok, SE.identifier		// ToDo: reconsider
			canBail = false
		else if tok == "," then
			// we've gotten a comma, which is a top-level grouper;
			// go ahead and collapse anything on stack back to 
			// the previous comma or open-paren
			self.collapseStack
			self.push tok, SE.comma
			canBail = false
		else if tok == ")" then
			// collapse last argument, i.e. collapse self.stack back to opening "(" or ","
			self.collapseStack
			// Now, there are two cases.  Either this is a plain parenthesized
			// sub-expression, or it is a function/array call.
			// If it's a sub-expression, then the open paren must be the next-
			// to-last item in stack.
			nextToLast = self.stack[self.stack.len-2]
			if nextToLast.type == SE.paren and nextToLast.content == "(" then
				self.debugPrint "Ordinary parenthesized sub-expression found"
				// ...in this case, we just remove the open paren and we're done
				self.stack.remove self.stack.len-2
			else
				// otherwise, it should be a call (or array lookup)
				call = self.pullCall
				if call then
					self.debugPrint "Evaluating a call: " + call
					funcOrArrayName = call[0].content[:-1].upper
					args = call[1:]
					self.pushValue SNArrayOrCall.make(funcOrArrayName, args, self.allowArrayRefs)
				else if self.stack.len < 3 then
					return printErr("unmatched parentheses")
				end if
			end if
			canBail = true
		else if tok isa number then
			// push a numeric operand
			if canBail then break
			self.pushValue tok
			if self.stack.len > 1 and self.stack[-2] == "-" and
					(self.stack.len == 2 or (self.stack[-3] isa string and 
					self.stack[-3].isOpenParen)) then
				self.doUnaryOp
			end if
			canBail = true
		else if tok[0] == """" then
			// push a string literal
			if canBail then break
			self.pushValue stripQuotes(tok)
			canBail = true
		else if operators.contains(tok) then
			// get an operator...
			opIdx = operators.indexOf(tok)
			if self.stack and not self.stack[-1].isOpenParen then
				while self.stack.len >= 2 and self.stack[-2].isOperator
					// process any higher-precedence operators already on stack
					prevOp = self.stack[-2].content
					prevOpIdx = -1
					if self.stack.len > 1 then prevOpIdx = operators.indexOf(prevOp)
					self.debugPrint "at op " + opIdx + ", considering " + prevOpIdx
					if opIdx > prevOpIdx then break
					if prevOp == "NOT" then self.doUnaryOp else self.doBinop
				end while
			end if
			// then push the new operator
			self.push tok, SE.operator
			canBail = false
			self.debugPrint "Pushed operator: " + tok
		else
			// push an identifier			
			if canBail then break
			self.push SNIdentifier.make(tok), SE.node
//			if customLocals != null and customLocals.hasIndex(tok) then
//				value = customLocals[tok]
//			else
//				value = getValue(tok)
//				if value == null then return null
//			end if
//			self.pushValue value
			if self.stack.len > 1 and self.stack[-2] == "-" and
					(self.stack.len == 2 or (self.stack[-3] isa string and 
					self.stack[-3].endsWith("("))) then
				self.doUnaryOp
			end if
			canBail = true
		end if
		if machine.halt then return null
		self.debugPrint "After handling " + self.tokens[pos] + ", self.stack is now: " + self.stackStr
		pos += 1
		self.nextTokIdx = pos		
	end while
	// finally, collapse stack (which should be in precedence order)
	self.collapseStack
	if self.stack.len > 1 then
		printErr "Syntax error -- extra stuff on self.stack: " + self.stackStr
	end if
	if self.stack then return self.popValue
end function

// evaluate: evaluate a tokenized expression, all the way to a value.
//  For example, given [6, "*", 7], return 42.
Evaluator.evaluate = function(customLocals=null)
	machine.halt = false
	parseTree = self.parse
	if parseTree then return parseTree.eval(customLocals)
end function
// Evaluate the given string of tokens, which should comprise a single expression.
evalTokens = function(tokens, customLocals=null)
	eval = Evaluator.make(tokens)
	return eval.evaluate(customLocals)
end function

// Parse the given string of tokens, assuming that is a comma-separated
// list of expressions of unknown length.  Stop when we hit the end of the
// token list, or a ":" (statement separator).  This is commonly used to get
// the arguments to a BASIC command.  Return argument expressions as a list.
getArguments = function(tokens, startIdx, allowArrayRefs = false)
	result = []
	pos = startIdx
	eval = Evaluator.make(tokens)
	eval.allowArrayRefs = allowArrayRefs
	while pos < tokens.len
		if tokens[pos] == ":" then break
		argEndPos = tokens.indexOfAnyParenSavvy([":",","], pos-1, tokens.len, tokens.len)
		eval.nextTokIdx = pos
		eval.endIdx = argEndPos
		result.push eval.parse
		if argEndPos == tokens.len or tokens[argEndPos] == ":" then break
		pos = argEndPos + 1
	end while
	return result
end function

// A special version of getArguments used for LINE, RECT, and ELLIPSE,
// where we expect args of the form: x1,y1 TO x2,y2
// (but allow another comma to replace the TO), or just [TO] x2, y2
// (and x1,y1 is then fetched from machine.plotPos).
// Returns null in case of invalid syntax.
getDrawingArgs = function(tokens, startIdx, allowArrayRefs = false, assumeFrom = true)
	result = []
	pos = startIdx
	eval = Evaluator.make(tokens)
	eval.allowArrayRefs = allowArrayRefs
	toPos = null
	if tokens[startIdx] == "TO" then
		toPos = 0
		pos += 1
		assumeFrom = true
	end if
	while pos < tokens.len
		if tokens[pos] == ":" then break
		argEndPos = tokens.indexOfAnyParenSavvy([":",",","TO"], pos-1, tokens.len, tokens.len)
		if argEndPos < tokens.len and tokens[argEndPos] == "TO" then
			if toPos != null then return null	// syntax error to have more than one TO
			toPos = result.len + 1	// remember where we saw the TO
		end if
		eval.nextTokIdx = pos
		eval.endIdx = argEndPos
		result.push eval.parse
		if argEndPos == tokens.len or tokens[argEndPos] == ":" then break
		pos = argEndPos + 1
	end while
	// validate the syntax
	if result.len == 2 then
		if toPos != null and toPos != 0 then return null
		if assumeFrom then
			result.insert 0, SNArrayOrCall.make("PLOTPOS", [SNLiteral.zero])
			result.insert 1, SNArrayOrCall.make("PLOTPOS", [SNLiteral.one])
		end if
	else if result.len == 4 then
		if toPos != null and toPos != 2 then return null
	else
		return null
	end if
	return result
end function

// Helper function to find the file handle for a PRINT#, INPUT#, or GET# command.
// Look for a "#" at the end of the token at startIdx.  If not found, return [null,startIdx+1].
// If found, return the file ID and the new startIdx after the ID token(s) as
// [file, newStart].  In case of error, print error and return null.
getFile = function(tokens, startIdx)
	if startIdx >= tokens.len or tokens[startIdx][-1] != "#" then return [null, startIdx+1]
	if startIdx+1 == tokens.len then return printErr("syntax error")
	tok = tokens[startIdx+1]
	result = null
	if tok isa number then
		result = [tok, startIdx+2]
	else if isOpenParen(tok) then
		closePos = tokens.findCloseParen(startIdx+2)
		if closePos == null then return printErr("unbalanced parentheses")
		fileId = evalTokens(tokens[startIdx+2:closePos])
		if not fileId isa number then return printErr("file ID must be numeric")
		result = [fileId, closePos+1]
	else if isIdentifier(tok) then
		fileId = getValue(tok)
		if not fileId isa number then return printErr("file ID must be numeric")
		result = [fileId, startIdx+2]		
	end if
	if result == null or not machine.files.hasIndex(result[0]) then return printErr("invalid file ID")
	result[0] = machine.files[result[0]]
	if result[1] < tokens.len and tokens[result[1]] == "," then result[1] += 1
	return result
end function

//======================================================================
// Functions that use and/or modify the state of the virtual machine.
// (Includes the Machine class, but also some global helper methods.)
//======================================================================

printErr = function(err)
	addr = machine.address
	loc = ""
	if addr.lineIndex >= 0 and machine.lineNums.hasIndex(addr.lineIndex) and
			machine.lineNums[addr.lineIndex] >= 0 then
		loc = " in line " + machine.lineNums[addr.lineIndex]
		if addr.statementIndex > 0 then loc += "(" + addr.statementIndex + ")"
	end if
	print char(7) + "Error: " + err + loc
	machine.halt = true
//	pprint stackTrace; exit
end function

getValue = function(identifier, customLocals=null)
	upperId = identifier.upper
	if customLocals and customLocals.hasIndex(upperId) then
		return customLocals[upperId]
	else if machine.vars.hasIndex(upperId) then
		return machine.vars[upperId]
	else if identifier.len < 3 then
		if isNumericId(identifier) then return 0 else return ""
	else
		return printErr("undefined identifier '" + identifier + "'")
	end if
end function

requireNum = function(value)
	if not value isa number then return printErr("type mismatch")
	return true
end function

requireStr = function(value)
	if not value isa string then return printErr("type mismatch")
	return true
end function


// Assign a value to the given lvar.  Returns true on success,
// false if failed.
setValue = function(lvar, value)
	upperId = lvar.id.upper
	if isNumericId(lvar.id) != (value isa number) then return printErr("type mismatch")
	if lvar.isArrayElem then
		if not machine.arrs.hasIndex(upperId) then
			// old-BASIC quirk: even arrays exist automatically, as soon as they are
			// referenced, with 1 dimension and a size of 10.  But we do this only
			// for identifiers less than 3 characters long.
			if lvar.id.len > 2 then return printErr("Undefined identifier")
			if isNumericId(lvar.id) then arr = [0]*11 else arr = [""]*11
			machine.arrs[upperId] = arr
		end if
		arr = machine.arrs[upperId]
		index = lvar.index
		if index isa list then
			// dereference all but the LAST index 
			// (which we'll use to assign the new value)
			for idx in index[:-1]
				idx = idx.eval
				if idx < 0 or idx >= arr.len then
					printErr "array index (" + idx + ") out of bounds (0-" + (arr.len-1) + ")"
					return false
				end if
				arr = arr[idx]
			end for
			index = index[-1]
		end if
		index = index.eval
		if not index isa number then
			printErr "array index must be a number"
			return false
		end if
		if index < 0 or index >= arr.len then
			printErr "array index (" + index + ") out of bounds (0-" + (arr.len-1) + ")"
			return false
		end if
		arr[index] = value
	else
		machine.vars[upperId] = value
	end if
	return true
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

// Convert the given line of the program to plain text.  This is similar
// to listOneLine, but without syntax coloring (and it returns the string
// instead of printing it).
getLineAsText = function(lineNum, tokens)
	result = []
	result.push str(lineNum) + " "
	space = ""
	for tok in tokens
		if tok == "REM" then
			result.push space + tok + " "
			if tokens.len > 1 then result.push tokens[-1]
			break
		else if keywords.contains(tok) then
			result.push space + tok + " "
			space = ""
		else if tok == ":" then
			result.push space + tok + " "
			space = ""
		else if tok == "," or tok == ";" or tok == "(" or tok == ")" then
			result.push tok
			space = " " * (tok != "(")
		else if tok[-1] == "(" then
			id = tok[:-1]
			result.push space + id
			tok = tok[-1]
			result.push tok
			space = ""
		else if operators.contains(tok) then
			result.push space + tok
			space = " "
		else if tok isa number or isNumericId(tok) then
			result.push space + tok
			space = " "
		else if tok.startsWith("""") or isStringId(tok) then
			result.push space + tok
			space = " "
		else
			result.push space + tok
			space = " "
		end if
	end for
	return result.join("")
end function

// Print the given line of the program, with syntax coloring.
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
			if tokens.len > 1 then print tokens[-1], ""
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
		if lineNum < 0 then continue
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
	if not line then return
	tokens = tokenize(line)
	if not tokens then 
		print "Error in: " + line
		return
	end if
	if tokens[0] isa number then
		lineNum = tokens[0]
		if tokens.len == 1 then
			machine.program.remove lineNum
		else
			if lineNum < 0 then return printErr("Line numbers must be nonnegative.")
			machine.program[lineNum] = tokens[1:]
		end if
		return
	end if
	
	// for immediate mode, store it as "line number" -2,
	// and then run just that (without clearing data).
	machine.program[-2] = tokens
	machine.program[-1] = ["END"]
	machine.runProgram -2, false
end function

// ForLoopState: represents the state of one active FOR loop,
// including the loop variable, loop bounds, step, etc.
ForLoopState = {}
ForLoopState.var = ""
ForLoopState.step = 1
ForLoopState.limit = 0
ForLoopState.topAddress = null
ForLoopState.make = function(var, limit, step, topAddress)
	fls = new ForLoopState
	fls.var = var.upper
	fls.step = step
	fls.limit = limit
	fls.topAddress = topAddress
	return fls
end function
ForLoopState.done = function
	curVal = machine.vars[self.var]
	if self.step >= 0 then return curVal > self.limit
	return curVal < self.limit
end function

// Lvar class: represents a value on the left-hand side of an 
// assignment, i.e., something that can be assigned a value.  This is
// either a regular variable reference, or an array + index.
Lvar = {}
Lvar.isArrayElem = false
Lvar.id = ""			// identifier, i.e. variable or array name
Lvar.index = null		// index value, in the case of an array element

Lvar.str = function
	s = self.id
	if self.isArrayElem then s += "(" + self.index + ")"
	return s
end function

// make an Lvar from the given set of tokens, starting at startPos
// (which should be the identifier) and going up to endPos (which 
// should be the first position after the `)` or variable name).
Lvar.make = function(tokens, startPos, endPos, dummyArg=false)
	lvar = new Lvar
	lvar.id = tokens[startPos]
	if not isIdentifier(lvar.id) then return printErr("identifier expected")
	if isOpenParen(lvar.id) then
		if tokens[endPos-1] != ")" then return printErr("unmatched parentheses")
		lvar.id = lvar.id[:-1]
		lvar.isArrayElem = true
		if dummyArg then
			if startPos+1 != endPos-2 or
			 not isIdentifier(tokens[startPos+1]) then return printErr("invalid dummy argument")
			lvar.index = tokens[startPos+1]
		else
			lvar.index = []
			eval = Evaluator.make(tokens, startPos+1, endPos-1)
			pos = startPos+1
			while pos < endPos-1
				argEndPos = tokens.indexOfAnyParenSavvy([")",","], pos-1, endPos-1, endPos-1)
				eval.nextTokIdx = pos
				eval.endIdx = argEndPos
				idx = eval.parse
				lvar.index.push idx				
				if argEndPos == tokens.len or tokens[argEndPos] == ")" then break
				pos = argEndPos + 1
			end while
		end if
	else
		if endPos > startPos+1 then return printErr("syntax error")
	end if
	if lvar.id isa number or lvar.id[0] == """" then return printErr("can't assign to constant")
	if keywords.contains(lvar) then return printErr("can't assign to keyword")
	return lvar
end function


// Machine State:
Machine = {}
Machine.program = {}		// key: line number; value: tokens
Machine.programPath = ""	// where this path was stored on disk
Machine.lineNums = []		// sorted list of line numbers
Machine.address = new Address		// current line/statement we're on
Machine.nextAddress = new Address	// next line/statement to execute
Machine.vars = {}			// key: identifier; value: value (scalars)
Machine.arrs = {}			// same, but for arrays (lists)
Machine.forLoops = []		// list of ForLoopState objects
Machine.returnStack = []	// stack of places to RETURN to (from GOSUB)
Machine.data = []			// collected data from DATA statements
Machine.nextDataIdx = 0		// which element of self.data to READ next
Machine.halt = false		// flag to cause program to stop
Machine.inThen = false		// true while in a THEN of an if statement
Machine.trace = false		// if on, print line numbers as we execute them
Machine.fill = false		// whether shape-drawing routines should fill
Machine.pen = 1				// line thickness for drawing routines
Machine.files = {}			// open files

Machine.resetData = function
	self.vars = {"ON":1, "OFF":0, "TRUE":1, "FALSE":0, "PI":pi}
	self.arrs = {}
	self.forLoops = []
	self.nextDataIdx = 0
	self.images = {}
	self.plotPos = [0,0]
	self.fill = false
	self.pen = 1
	self.images = {}
	gfx.color = palette[5]
	for fileHandle in self.files.values
		fileHandle.close
	end for
	self.files = {}
end function

Machine.reset = function
	self.program = {}
	self.programPath = ""
	self.lineNums = []
	self.lineIdx = 0
	self.programPath = ""
	self.trace = false
	self.resetData
end function

Machine.forLoopForVariable = function(varName)
	varName = varName.upper
	i = self.forLoops.len - 1
	while i >= 0
		if self.forLoops[i].var == varName then return self.forLoops[i]
		i = i - 1
	end while
	return null
end function


// Define all the built-in functions
// (in alphabetical order below)
Machine.fn = {}
Machine.fn.ABS = function(n); if requireNum(n) then return abs(n); end function
Machine.fn.ASC = function(s); if requireStr(s) then return code(s); end function
Machine.fn.ATN = function(n); if requireNum(n) then return atan(n); end function
Machine.fn["CHR$"] = function(n); if requireNum(n) then return char(n); end function
Machine.fn.COS = function(n); if requireNum(n) then return cos(n); end function
Machine.fn.EXP = function(n); if requireNum(n) then return mathUtil.e ^ n; end function
Machine.fn.FIX = function(n); if requireNum(n) then return int(n); end function
Machine.fn["INKEY$"] = function(z);	if key.available then return key.get; return ""; end function
Machine.fn.INT = function(n); if requireNum(n) then return floor(val(n)); end function
Machine.fn.INSTR = function(args)
	if not args isa list or args.len < 2 or args.len > 3 then return printErr("invalid arguments to INSTR")
	if args.len == 2 then
		start = 1
		s = args[0]
		substr = args[1]
	else
		start = args[0]
		s = args[1]
		substr = args[2]
	end if
	if requireNum(start) and requireStr(s) and requireStr(substr) then
		result = s.indexOf(substr, start-2) + 1
		if result == null then result = 0
		return result
	end if
end function
Machine.fn["LEFT$"] = function(args)
	if not args isa list then return args
	s = args[0]
	if args.len > 1 then length = args[1] else length = s.len
	if requireStr(s) and requireNum(length) then return s[:length]
end function
Machine.fn.LEN = function(s); if requireStr(s) then return len(s); end function
Machine.fn.LOG = function(n); if requireNum(n) then return mathUtil.ln(n); end function
Machine.fn["LOWER$"] = function(s); if requireStr(s) then return lower(s); end function
Machine.fn["MID$"] = function(args)
	if not args isa list then return args
	s = args[0]
	if args.len > 1 then startPos = args[1] else startPos = 1
	if args.len > 2 then length = args[2] else length = s.len
	if requireStr(s) and requireNum(startPos) and requireNum(length) then
		return s[startPos-1:startPos-1+length]
	end if
end function
Machine.fn.PIXEL = function(xy)
	if not xy isa list or len(xy) != 2 then return printErr("invalid arguments to PIXEL")
	x = xy[0]; y = xy[1]
	if not requireNum(x) or not requireNum(y) then return null
	c = gfx.pixel(x,y)
	colorNum = palette.indexOf(c[:7])
	if colorNum == null then return -1
	return colorNum
end function
Machine.fn["PIXEL$"] = function(xy)
	if not xy isa list or len(xy) != 2 then return printErr("invalid arguments to PIXEL$")
	x = xy[0]; y = xy[1]
	if not requireNum(x) or not requireNum(y) then return null
	return gfx.pixel(x,y)[:7]
end function
Machine.fn.POS = function(n)
	if round(n) % 2 then return 26 - text.row else return text.column + 1
end function
Machine.fn.PLOTPOS = function(n)
//	print "in PLOTPOS with arg " + n
	if round(n) % 2 then return machine.plotPos[1] else return machine.plotPos[0]
end function
Machine.fn["RIGHT$"] = function(args)
	if not args isa list then return args
	s = args[0]
	if args.len > 1 then length = args[1] else length = s.len
	if requireStr(s) and requireNum(length) then return s[-length:]
end function
Machine.fn.RND = function(n)
	if not requireNum(n) then return null
	if n < 0 then rnd(n)		// (negative argument seeds; non-negative argument ignored)
	return rnd;
end function
Machine.fn.SGN = function(n); if requireNum(n) then return sign(n); end function
Machine.fn.SIN = function(n); if requireNum(n) then return sin(n); end function
Machine.fn["SPACES$"] = function(n); if requireNum(n) then return " "*n; end function
Machine.fn.SPC = function(n); if requireNum(n) then print " "*n,""; return ""; end function
Machine.fn.SQR = function(n); if requireNum(n) then return sqrt(n); end function
Machine.fn["STR$"] = function(n); if requireNum(n) then return str(n); end function
Machine.fn.TAB = function(n)
	if n isa list then
		// With 2 or more arguments, take these as COL, ROW,
		// and *always* move the cursor
		if n.len != 2 then return printErr("invalid arguments to TAB")
		if not requireNum(n[0]) or not requireNum(n[1]) then return
		text.column = val(n[0]) - 1
		text.row = 26 - val(n[1])
	else
		// With just 1 argument, it's column, and we move
		// only if the current position is left of that.
		if requireNum(n) and n > text.column then text.column = n - 1; 
	end if
	return ""
end function
Machine.fn.TAN = function(n); if requireNum(n) then return tan(n); end function
Machine.fn.TIME = function(n)
	requireNum n
	if n % 2 then return time - machine.timeAtRun
	return time - machine.timeAtStart
end function
Machine.fn["UPPER$"] = function(s); if requireStr(s) then return upper(s); end function
Machine.fn.VAL = function(s); if requireStr(s) then return val(s); end function

// Functions skipped for now -- maybe ToDo:
// HEX$ (convert number to hex)
// OCT$ (convert number to octal)
// INPUT$ (from MBASIC-80)
// PEEK, POKE
// STRING$

// Define all the BASIC commands 
// (in alphabetical order below)

Command = {}
Command.parse = function(tokens, startIdx, endIdx, address)
	// default parse expects no arguments, and just returns
	// an instance of this command class.
	if endIdx > startIdx+1 then return printErr("syntax error in " + 
	  cmd.indexOf(self) + " command")		
	return new self
end function
Command.run = null
cmd = {}

Machine.cmd = {}	// ToDo: delete this!

cmd.BREAK = new Command; cmd.BREAK._name = "cmd.BREAK"
cmd.BREAK.run = function(tokens, startIdx, endIdx)
	print
	if machine.lineIdx >= 0 and machine.lineIdx < machine.lineNums.len and
			machine.lineNums[machine.lineIdx] >= 0 then
		print "BREAK at line " + machine.lineNums[machine.lineIdx]
	else
		print "BREAK"
	end if
	machine.halt = true
	while controlCPressed; yield; end while
end function

cmd.CD = new Command; cmd.CD._name = "cmd.CD"
cmd.CD.parse = function(tokens, startIdx, endIdx, address)
	args = tokens[startIdx+1:endIdx]
	args.apply(@stripQuotes)
	path = args.join("").trim
	result = new cmd.CD
	result.path = path
	return result
end function
cmd.CD.run = function(tokens, startIdx, endIdx)
	cd self.path
end function

cmd.CLEAR = new Command; cmd.CLEAR._name = "cmd.CLEAR"
cmd.CLEAR.run = function
	machine.vars = {}
	machine.arrs = {}
end function

cmd.COLOR = new Command; cmd.COLOR._name = "cmd.COLOR"
cmd.COLOR.parse = function(tokens, startIdx, endIdx, address)
	result = new cmd.COLOR
	result.arg = Evaluator.make(tokens, startIdx+1, endIdx).parse
	return result
end function
cmd.COLOR.run = function
	arg = self.arg.eval
	if arg isa number then
		gfx.color = palette[arg % palette.len]
	else if arg[0] == "#" then
		gfx.color = arg
	end if
	text.color = gfx.color
end function

cmd.DATA = new Command; cmd.DATA._name = "cmd.DATA"
cmd.DATA.parse = function(tokens, startIdx, endIdx, address)
	// As a command, this is a no-op.  (Though it still needs to be
	// a unique instance so we can store its endTokenIdx.)
	return new cmd.DATA
end function

cmd.DEF = new Command; cmd.DEF._name = "cmd.DEF"
cmd.DEF.parse = function(tokens, startIdx, endIdx, address)
	result = new cmd.DEF
	startIdx += 1	// skip DEF
	// grab the function name and dummy argument
	varEndPos = startIdx + 1
	if isOpenParen(tokens[startIdx]) then
		varEndPos = tokens.findCloseParen(startIdx+1, endIdx) + 1
		if varEndPos == null then return printErr("unmatched parentheses")
	end if
	result.lvar = Lvar.make(tokens, startIdx, varEndPos, true)
	if result.lvar == null then return
	if not result.lvar.isArrayElem then return printErr("user function requires 1 argument")
	// next should be the `=`
	if varEndPos >= endIdx or tokens[varEndPos] != "=" then return printErr("incomplete DEF FN")
	// and the rest of the line is the expression
	result.exprToks = tokens[varEndPos+1:endIdx]
	if not result.exprToks then return printErr("incomplete DEF FN")
	return result
end function
cmd.DEF.run = function
	// Build a function and stuff it into the machine.
	// (ToDo: be sure we clear these out with CLEAR.)
	exprToks = self.exprToks
	lvar = self.lvar
	machine.fn[lvar.id] = function(arg)
		return evalTokens(exprToks, {lvar.index:arg})
	end function
end function

cmd.DIM = new Command; cmd.DIM._name = "cmd.DIM"
cmd.DIM.redim = false
cmd.DIM.parse = function(tokens, startIdx, endIdx, address)
	result = new self
	result.nameToDims = {}	// key: array name; value: array dimensions
	if endIdx < startIdx + 2 then return printErr("incomplete DIM statement")
	pos = startIdx + 1
	while pos < endIdx
		name = tokens[pos].upper
		dims = [10]	// default to one dimension, max index of 10
		pos += 1
		if isOpenParen(name) then
			name = name[:-1]
			if pos+1 >= endIdx then return printErr("incomplete DIM statement")
			dims = []
			while pos+1 < endIdx
				nextPos = tokens.indexOfAnyParenSavvy([",", ")"], pos, endIdx)
				if nextPos == null then return printErr("incomplete DIM statement")
				maxIndex = Evaluator.make(tokens, pos, nextPos).evaluate
				if not maxIndex isa number then return printErr("DIM size must be a number")
				dims.push maxIndex
				pos = nextPos+1
				if tokens[nextPos] == ")" then break
				if tokens[nextPos] != "," then return printErr("syntax error in DIM statement")
			end while
		end if
		if not isIdentifier(name) then return printErr("identifier expected in DIM statement")
		
		result.nameToDims[name] = dims	
		if pos < endIdx and tokens[pos] == "," then pos += 1
	end while
	return result
end function
cmd.DIM.run = function
	for kv in self.nameToDims
		name = kv.key
		dims = kv.value
		if isNumericId(name) then defaultVal = 0 else defaultVal = ""
		oldArr = null
		if machine.arrs.hasIndex(name) then
			if not self.redim then return printErr("array " + name + " already DIMensioned")
			oldArr = machine.arrs[name]
		end if
		
		machine.arrs[name] = makeMultiDimArray(dims, defaultVal)
		// ToDo: maybe copy old data from oldArr, as much as possible?
	end for
end function

cmd.DIR = new Command; cmd.DIR._name = "cmd.DIR"
cmd.DIR.parse = function(tokens, startIdx, endIdx, redim=false)
	result = new cmd.DIR
	// NOTE: DIR is different from other commands; it cannot take
	// a variable as an argument (but, it does not require you
	// to put quotes around the path)
	args = tokens[startIdx+1:endIdx]
	args.apply(@stripQuotes)
	result.path = args.join("").trim
	return result
end function
cmd.DIR.run = function
	dir self.path
end function
cmd.CAT = cmd.DIR		// CAT and CATALOG are aliases for DIR
cmd.CATALOG = cmd.DIR

cmd.CLOSE = new Command; cmd.CLOSE._name = "cmd.CLOSE"
cmd.CLOSE.parse = function(tokens, startIdx, endIdx, address)
	// ToDo: fix this after doing OPEN
	return printErr("CLOSE not finished yet")
	
	if startIdx+1 >= endIdx then return printErr("incomplete CLOSE statement")
	args = getArguments(tokens, startIdx+1, endIdx)
	if args == null or args.len != 1 then return printErr("invalid arguments to CLOSE")
	fileId = args[0]
	if not fileId isa number or fileId == 0 then return printErr("invalid file ID in CLOSE")
	if machine.files.hasIndex(fileId) then
		machine.files[fileId].close
		machine.files.remove fileId
	end if
end function

cmd.EDIT = new Command; cmd.EDIT._name = "cmd.EDIT"
cmd.EDIT.parse = function(tokens, startIdx, endIdx, address)
	result = new cmd.EDIT
	result.arg = Evaluator.make(tokens, startIdx+1, endIdx).parse
	return result
end function
cmd.EDIT.run = function
	lineNum = self.arg.eval
	if not machine.program.hasIndex(lineNum) then return printErr("invalid line number")
	lineText = getLineAsText(lineNum, machine.program[lineNum])
	if not key.hasIndex("put") then
		return printErr("feature not available (newer version of Mini Micro required)")
	else
		key.put lineText
		line = inputOrControlC(">")
		if line == char(3) then cmd.BREAK.run else repl line
	end if
end function

cmd.ELSE = new Command; cmd.ELSE._name = "cmd.ELSE"
cmd.ELSE.parse = function(tokens, startIdx, endIdx, address)
	result = new cmd.ELSE
	result.jumpToAddress = Address.make(address.lineIndex+1)
	return result
end function
cmd.ELSE.run = function
	machine.jumpTo self.jumpToAddress
end function

cmd.ELLIPSE = new Command; cmd.ELLIPSE._name = "cmd.ELLIPSE"
cmd.ELLIPSE.parse = function(tokens, startIdx, endIdx, address)
	if startIdx+1 >= endIdx then return printErr("incomplete ELLIPSE statement")
	args = getDrawingArgs(tokens, startIdx+1)
	if args == null then return printErr("syntax error in ELLIPSE")
	if args.len != 4 then return printErr("invalid arguments to ELLIPSE")
	result = new cmd.ELLIPSE
	result.args = args
	return result
end function
cmd.ELLIPSE.run = function
	args = self.args
	x = [args[0].eval, args[2].eval];	x.sort
	y = [args[1].eval, args[3].eval]; y.sort
	if machine.fill then
		gfx.fillEllipse x[0], y[0], x[1] - x[0], y[1] - y[0]
	else
		gfx.drawEllipse x[0], y[0], x[1] - x[0], y[1] - y[0], gfx.color, machine.pen
	end if
	machine.plotPos = [x[1], y[1]]
end function

cmd.END = new Command; cmd.END._name = "cmd.END"
cmd.END.run = function
	machine.halt = true
end function
cmd.STOP = cmd.END

cmd.FILL = new Command; cmd.FILL._name = "cmd.FILL"
cmd.FILL.parse = function(tokens, startIdx, endIdx, address)
	if tokens.len < startIdx + 1 then
		return printErr("incomplete FILL statement")
	end if
	result = new cmd.FILL
	result.mode = Evaluator.make(tokens, startIdx+1, endIdx).parse
	return result
end function
cmd.FILL.run = function
	machine.fill = (self.mode.eval != 0)
end function

cmd.FOR = new Command; cmd.FOR._name = "cmd.FOR"
cmd.FOR.parse = function(tokens, startIdx, endIdx, address)
	if tokens.len < startIdx + 6 or tokens[startIdx+2] != "=" then
		return printErr("incomplete FOR statement")
	end if
	result = new cmd.FOR
	result.var = tokens[startIdx + 1].upper
	if not isIdentifier(result.var) then return printErr("invalid FOR loop variable " + var)
	toPos = tokens.indexOf("TO", startIdx+3)
	if toPos == null or toPos >= endIdx then return printErr("incomplete FOR statement")
	stepPos = tokens.indexOf("STEP", startIdx+4)
	if stepPos == null or stepPos > endIdx then stepPos = endIdx
	result.fromExpr = Evaluator.make(tokens, startIdx+3, toPos).parse
	result.toExpr = Evaluator.make(tokens, toPos+1, stepPos).parse
	result.stepExpr = SNLiteral.one // Too cool for BASIC: if fromVal >= toVal then step = 1 else step = -1
	if stepPos < endIdx then
		if tokens.len < stepPos+2 then return printErr("incomplete FOR statement")
		result.stepExpr = Evaluator.make(tokens, stepPos+1, endIdx).parse
	end if
	result.address = address
	return result
end function
cmd.FOR.run = function
	machine.vars[self.var] = self.fromExpr.eval
	machine.forLoops.push ForLoopState.make(self.var, 
	  self.toExpr.eval, self.stepExpr.eval, self.address.next)
end function

cmd.GET = new Command; cmd.GET._name = "cmd.GET"
cmd.GET.parse = function(tokens, startIdx, endIdx, address)
	// ToDo: deal with file #
	fileAndPos = getFile(tokens, startIdx)
	if fileAndPos == null then return
	f = fileAndPos[0]; pos = fileAndPos[1]
	
	result = new cmd.GET
	result.lvar = Lvar.make(tokens, pos, endIdx)
	if result.lvar == null then return printErr("incomplete GET statement")
	return result
end function
cmd.GET.run = function	
	if false then
		k = f.read(1)
		if k == null then
			if isNumericId(lvar.id) then k = -1 else k = ""
		else
			if isNumericId(lvar.id) then k = k.code
		end if
	else
		k = key.get
		if isNumericId(self.lvar.id) then k = k.code
	end if
	setValue self.lvar, k
end function
cmd[new "GET#"] = cmd.GET

cmd.GOSUB = new Command; cmd.GOSUB._name = "cmd.GOSUB"
cmd.GOSUB.parse = function(tokens, startIdx, endIdx, address)
	if endIdx != startIdx + 2 or not (tokens[startIdx+1] isa number) then
		return printErr("line number required for GOSUB")
	end if
	result = new cmd.GOSUB
	returnTo = address.next
	result.jumpTo = tokens[startIdx+1]
	result.returnTo = returnTo
	return result
end function
cmd.GOSUB.run = function
	machine.returnStack.push self.returnTo
	machine.goTo self.jumpTo
	return 0
end function

cmd.GOTO = new Command; cmd.GOTO._name = "cmd.GOTO"
cmd.GOTO.parse = function(tokens, startIdx, endIdx, address)
	if endIdx != startIdx + 2 or not (tokens[startIdx+1] isa number) then
		return printErr("line number required for GOTO")
	end if
	result = new cmd.GOTO
	result.jumpTo = tokens[startIdx+1]
	return result
end function
cmd.GOTO.run = function
	machine.goTo self.jumpTo
	return 0
end function

cmd.HOME = new Command; cmd.HOME._name = "cmd.HOME"
cmd.HOME.run = function
	clear
	text.row = 26; text.column = 0
	text.color = palette[5]
	gfx.color = text.color
	text.backColor = color.clear
	gfx.clear color.black
	gfx.plotPos = [0,0]
end function
cmd.CLS = cmd.HOME		// CLS is an alias for HOME

cmd.HTAB = new Command; cmd.HTAB._name = "cmd.HTAB"
cmd.HTAB.parse = function(tokens, startIdx, endIdx, address)
	result = new self
	result.arg = Evaluator.make(tokens, startIdx+1, endIdx).parse
	return result
end function
cmd.HTAB.run = function
	text.column = val(self.arg.eval) - 1
end function

cmd.IF = new Command; cmd.IF._name = "cmd.IF"
cmd.IF.parse = function(tokens, startIdx, endIdx, address)
	// This seems like a very tricky case, because of multiple statements
	// per THEN and ELSE clause, and the possibility of nested IF-THEN-ELSE
	// statements.  But it's not so bad.  The rules are:
	//  1. If the condition is true, proceed to the nearest THEN,
	// 	   and when we hit ELSE, skip to the next line.
	//  2. If the condition is false, then find the matching ELSE
	//	   token, discounting as many ELSEs as we see THENs on the way.

	result = new self
	
	if endIdx >= tokens.len or tokens[endIdx] != "THEN" then	
		return printErr("THEN required after IF")
	end if
	if tokens.len < endIdx + 2 then
		return printErr("incomplete THEN clause")
	end if
	result.condition = Evaluator.make(tokens, startIdx+1, endIdx).parse
	result.endTokenIdx = endIdx
	
	// Find the end of the "then" statement(s).  This will be the
	// end of the line, or the "ELSE" token that matches up with
	// our "THEN" token.
	elsePos = tokens.len
	i = endIdx + 1
	extraElses = 0
	while i < tokens.len
		if tokens[i] == "THEN" then extraElses += 1
		if tokens[i] == "ELSE" then
			extraElses -= 1
			if extraElses < 0 then
				// Found it!
				elsePos = i
				break
			end if
		end if
		i += 1
	end while
	
	// Now, handle two cases: if what we have after THEN is a
	// number, treat it as a GOTO; otherwise, it's a statement
	// we should jump to.
	if tokens[endIdx+1] isa number then
		result.thenJumpTo = Address.make(machine.lineNums.indexOf(tokens[endIdx+1]))
		result.endTokenIdx = endIdx + 2
	else
		result.thenJumpTo = address.next
	end if

	// Now, find the matching ELSE clause to jump to if the condition is false.
	extraElses = 0
	statementIdx = address.statementIndex + 1
	i = endIdx + 1
	result.elseJumpTo = Address.make(address.lineIndex+1)
	while i < tokens.len
		if tokens[i] == "THEN" then
			extraElses += 1
			statementIdx += 1
		else if tokens[i] == "ELSE" then
			statementIdx += 1
			extraElses -= 1
			if extraElses < 0 then
				// Found it!  If followed by a number,
				// treat it as a GoTo; otherwise jump to that statement.
				if tokens[i+1] isa number then
					result.elseJumpTo = Address.make(machine.lineNums.indexOf(tokens[i+1]))
					result.endTokenIdx = i + 2
				else
					result.elseJumpTo = Address.make(address.lineIndex, statementIdx+1)
				end if
				break
			end if
			statementIdx += 1
		else if tokens[i] == ":" then
			statementIdx += 1
		end if
		i += 1
	end while
	return result
end function
cmd.IF.run = function
	value = self.condition.eval
	machine.statementIdx = 0
	if value != 0 then
		// condition is true! Jump to the "then" address
		machine.jumpTo self.thenJumpTo
	else
		// condition is false!  Jump to the "else" address
		machine.jumpTo self.elseJumpTo
	end if
end function

cmd.IMAGE = new Command; cmd.IMAGE._name = "cmd.IMAGE"
cmd.IMAGE.parse = function(tokens, startIdx, endIdx, address)
	if startIdx+2 >= endIdx then return printErr("incomplete IMAGE statement")
	commaPos = tokens.indexOfAnyParenSavvy([",", "TO"], startIdx+1, endIdx, endIdx)
	result = new self
	result.path = Evaluator.make(tokens, startIdx+1, commaPos).parse
	startIdx = commaPos + (tokens[commaPos] == ",")
	result.args = getDrawingArgs(tokens, startIdx, false, false)
	return result
end function
cmd.IMAGE.run = function
	path = self.path.eval	
	if not path isa string then return printErr("type mismatch error in IMAGE")
	if machine.images.hasIndex(path) then
		image = machine.images[path]
	else
		image = file.loadImage(path)
		if not image then return printErr("no image found at """ + path + """")
	end if
	args = self.args[:]
	if args == null then return printErr("syntax error in IMAGE")
	for i in args.indexes; args[i] = args[i].eval; end for
	if args.len == 2 then
		// draw centered on the given coordinates
		gfx.drawImage image, args[0] - image.width/2, args[1] - image.height/2
		machine.plotPos = args
	else
		// draw to fill the given bounds
		if args.len != 4 then return printErr("invalid arguments to IMAGE")
		x = [args[0], args[2]] //;	x.sort
		y = [args[1], args[3]] //; y.sort
		gfx.drawImage image, x[0], y[0], x[1] - x[0], y[1] - y[0]
		machine.plotPos = args[2:]
	end if
end function

cmd.INPUT = new Command; cmd.INPUT._name = "cmd.INPUT"
cmd.INPUT.parse = function(tokens, startIdx, endIdx, address)
	// Another quirky function (http://basic4all.epizy.com/index.php?topic=372).
	// Our version:
	//		- prints "?" if no prompt, or if prompt is followed by ";"
	//		- add nothing to the prompt if followed by ","
	//		- when inputting a number, trims and stops at whitespace or comma
	//		- when inputting a string, stops at comma UNLESS it is the last
	//		  variable in the input list, in which case it continues to EOL.
	
	// ToDo: file support
	fileAndPos = getFile(tokens, startIdx)
	if fileAndPos == null then return
	f = fileAndPos[0]; pos = fileAndPos[1]
	
	result = new self
	
	// Start by finding the prompt (which must be a string literal)
	if pos < endIdx and isStringLiteral(tokens[pos]) then
		result.prompt = stripQuotes(tokens[pos])
		if endIdx <= startIdx+3 then return printErr("incomplete INPUT statement")
		if tokens[pos+1] != "," and tokens[pos+1] != ";" then printErr("comma or semicolon expected")
		if tokens[pos+1] == ";" then result.prompt += "?"
		pos += 2
	else
		result.prompt = "?"
	end if
	
	// Then, collect variables
	result.lvars = []
	remainingInput = ""
	while pos < endIdx
		varEndPos = pos + 1
		if isOpenParen(tokens[pos]) then
			varEndPos = tokens.findCloseParen(pos+1, endIdx) + 1
			if varEndPos == null then return printErr("unmatched parentheses")
		end if
		lvar = Lvar.make(tokens, pos, varEndPos)
		if lvar == null then break
		result.lvars.push lvar
		if varEndPos >= endIdx then break
		if tokens[varEndPos] != "," then printErr("comma expected")
		pos = varEndPos + 1
	end while
	return result
end function	
cmd.INPUT.run = function
	// Loop over variables, gathering input for each one, asking for more as needed
	f = null // ToDo: file support!
	remainingInput = ""
	prompt = self.prompt
	for lvarIdx in self.lvars.indexes
		lvar = self.lvars[lvarIdx]
		varIsNumeric = isNumericId(lvar.id)
		while not remainingInput
			if f then remainingInput = f.readLine else remainingInput = inputOrControlC(prompt)
			if remainingInput == char(3) then return machine.cmd.BREAK
			if varIsNumeric then remainingInput = remainingInput.trimLeft
			prompt = "??"
			if not varIsNumeric then break  // empty string is OK input for a string
		end while
		if varIsNumeric then
			// numeric var: grab up to the next whitespace or comma
			delimPos = remainingInput.indexOfAny(", ", -1, remainingInput.len)
			value = val(remainingInput[:delimPos])
			remainingInput = remainingInput[delimPos+1:].trimLeft
		else
			// string var: grab up to the next comma, unless this is the final variable
			if lvarIdx < self.lvars.len-1 then
				delimPos = remainingInput.indexOfAny(",", -1, remainingInput.len)
				value = remainingInput[:delimPos]
				remainingInput = remainingInput[delimPos+1:]
			else
				value = remainingInput
				remainingInput = ""
			end if
		end if
		setValue lvar, value
	end for
end function
cmd["INPUT#"] = @cmd.INPUT

cmd.LET = new Command; cmd.LET._name = "cmd.LET"
cmd.LET.parse = function(tokens, startIdx, endIdx, address)
	if tokens[startIdx] == "LET" then startIdx += 1  // (skip LET, if present)
	result = new cmd.LET
	varEndPos = startIdx + 1
	if isOpenParen(tokens[startIdx]) then
		varEndPos = tokens.findCloseParen(startIdx+1, endIdx) + 1
		if varEndPos == null then return printErr("unmatched parentheses")
	end if
	result.lvar = Lvar.make(tokens, startIdx, varEndPos)
	if result.lvar == null then return null
	
	if tokens[varEndPos] != "=" then return printErr("syntax error in assignment")
	result.rhs = Evaluator.make(tokens, varEndPos+1, endIdx).parse
	return result
end function
cmd.LET.run = function
	setValue self.lvar, self.rhs.eval
end function

cmd.LINE = new Command; cmd.LINE._name = "cmd.LINE"
cmd.LINE.parse = function(tokens, startIdx, endIdx, address)
	if startIdx+1 >= endIdx then return printErr("incomplete LINE statement")
	result = new self
	result.args = getDrawingArgs(tokens, startIdx+1)
	return result
end function
cmd.LINE.run = function
	args = self.args[:]
	if args == null then return printErr("syntax error in LINE")
	for i in args.indexes; args[i] = args[i].eval; end for
	machine.plotPos = args[:2]
	x = args[2]; y = args[3]
	if requireNum(x) and requireNum(y) then
		gfx.line machine.plotPos[0], machine.plotPos[1], x, y, gfx.color, machine.pen
		machine.plotPos = [x,y]
	end if
end function

cmd.LIST = new Command; cmd.LIST._name = "cmd.LIST"
cmd.LIST.remOnly = false
cmd.LIST.parse = function(tokens, startIdx, endIdx, address)
	result = new self
	result.range = getRange(tokens[startIdx+1:endIdx])
	return result
end function
cmd.LIST.run = function
	listProgram self.range, self.remOnly
end function

cmd.LISTREM = new cmd.LIST
cmd.LISTREM.remOnly = true

cmd.LOAD = new Command; cmd.LOAD._name = "cmd.LOAD"
cmd.LOAD.parse = function(tokens, startIdx, endIdx, address)
	// like DIR, this command is special; it can't take a variable
	// as an argument, but you don't need to use quotation marks.
	result = new self
	args = tokens[startIdx+1:endIdx]
	args.apply(@stripQuotes)
	path = args.join("").trim
	result.path = path - ".bas" + ".bas"
	return result
end function
cmd.LOAD.run = function
	lines = file.readLines(self.path)
	if lines == null then
		print "Unable to read program " + self.path
	else
		machine.reset
		for line in lines
			repl line
		end for
		print machine.program.len + " lines loaded from " + self.path
		machine.programPath = self.path	// ToDo: get full path
	end if
end function

cmd.NEXT = new Command; cmd.NEXT._name = "cmd.NEXT"
cmd.NEXT.parse = function(tokens, startIdx, endIdx, address)
	result = new cmd.NEXT
	result.args = tokens[startIdx+1:endIdx]
	result.args.removeVal ",", true
	return result
end function
cmd.NEXT.run = function
	// find a list of FOR loop variables to consider
	args = self.args
	if not machine.forLoops then return printErr("NEXT without FOR")
	if not args then
		// (...if none is given, then pick the most recent one)
		args = [machine.forLoops[-1].var]
	end if
	// Now, for each of those, in order, find the corresponding for loop entry.
	// If its complete, move on to the next one.  For the first one that's  not
	// yet finished, apply the step and return to the top.
	for varName in args
		fls = machine.forLoopForVariable(varName)
		if fls == null then return printErr("NEXT without FOR")
		machine.vars[fls.var] += fls.step
		if fls.step > 0 and machine.vars[fls.var] > fls.limit or
		   fls.step < 0 and machine.vars[fls.var] < fls.limit then
			// this one is done; pop the for loop back past this point
			while machine.forLoops
				if machine.forLoops.pop == fls then break
			end while
			continue
		end if
		// this one is not done; send machine to the top of the loop
		machine.jumpTo fls.topAddress
		break
	end for
end function

cmd.NEW = new Command; cmd.NEW._name = "cmd.NEW"
cmd.NEW.run = function
	machine.reset
end function

cmd.ON = new Command; cmd.ON._name = "cmd.ON"
cmd.ON.parse = function(tokens, startIdx, endIdx, address)
	goPos = tokens.indexOfAnyParenSavvy(["GOTO", "GOSUB"], startIdx, endIdx, endIdx)
	if goPos == endIdx then return printErr("Incomplete ON statement")
	result = new self
	result.arg = Evaluator.make(tokens, startIdx+1, goPos).parse
	result.targets = []		// line numbers we could jump to (0-based list)
	result.gosub = (tokens[goPos] == "GOSUB")
	if result.gosub then result.returnTo = address.next
	pos = goPos + 1
	while pos < endIdx
		targetLineNum = tokens[pos]
		if not targetLineNum isa number then return printErr("Line numbers must be numeric")
		result.targets.push targetLineNum
		if pos+1 < endIdx and tokens[pos+1] != "," then return printErr("Syntax error in ON statement")
		pos += 2
	end while
	return result
end function
cmd.ON.run = function
	targetIndex = self.arg.eval - 1
	if targetIndex < 0 or targetIndex >= self.targets.len then return
	if self.gosub then machine.returnStack.push self.returnTo
	return machine.goTo(self.targets[targetIndex])
end function

// ToDo: file support!
Machine.cmd.OPEN = function(tokens, startIdx, endIdx)
	// syntax: OPEN fileId, [mode,] path
	//	fileId: a unique nonzero number to identify the open file
	//	mode: a file mode string like "r" or "a+", or a number: 0="r", 1="w"
	// Note that we do NOT have or support the "device number" second
	// parameter which you may see in C64 BASIC2 programs.  Just leave it out.
	args = getArguments(tokens, startIdx+1, endIdx)
	if args.len < 2 then return printErr("incomplete OPEN command")
	if args.len > 3 then return printErr("too many arguments to OPEN")
	fileId = args[0]
	if not fileId isa number or fileId == 0 then return printErr("invalid file ID in OPEN")
	if args.len == 3 then mode = args[1] else mode = "r"
	if mode isa number then
		if mode == 0 then mode = "r" else mode = "w"
	end if
	path = args[-1]
	if machine.files.hasIndex(fileId) then return printErr("file " + fileId + " already open")
	f = file.open(path, mode)
	if f isa string then return printErr(f)
	machine.files[fileId] = f
end function

cmd.PEN = new Command; cmd.PEN._name = "cmd.PEN"
cmd.PEN.parse = function(tokens, startIdx, endIdx, address)
	result = new self
	result.args = getArguments(tokens, startIdx+1, endIdx)
	if result.args.len != 1 then return printErr("invalid arguments to PEN")
	return result
end function
cmd.PEN.run = function
	arg = self.args[0].eval
	if arg < 0 then return printErr("invalid arguments to PEN")	
	if not requireNum(arg) then return
	machine.pen = arg
end function

cmd.PLOT = new Command; cmd.PLOT._name = "cmd.PLOT"
cmd.PLOT.parse = function(tokens, startIdx, endIdx, address)
	result = new self
	result.args = getArguments(tokens, startIdx+1, true)
	if result.args.len != 2 then return printErr("invalid arguments to PLOT")
	return result
end function
cmd.PLOT.run = function
	x = self.args[0].eval; y = self.args[1].eval
	if x isa list and y isa list then
		if x.len > y.len then maxi = x.len-1 else maxi = y.len-1
		if maxi < 0 then return
		if not requireNum(x[0]) or not requireNum(y[0]) then return
		if machine.pen > 0.5 and machine.pen < 1.5 then
			for i in range(0, maxi)
				gfx.setPixel x[i], y[i], gfx.color
			end for
		else
			w = machine.pen
			hw = w/2
			for i in range(0, maxi)
				gfx.fillEllipse x[i]-hw, y[i]-hw, w, w
			end for
		end if
		machine.plotPos = [x[-1], y[-1]]
	else if requireNum(x) and requireNum(y) then
		if machine.pen > 0.5 and machine.pen < 1.5 then
			gfx.setPixel x, y, gfx.color
		else
			w = machine.pen
			hw = w/2
			gfx.fillEllipse x-hw, y-hw, w, w
		end if
		machine.plotPos = [x,y]
	end if
end function

cmd.POLY = new Command; cmd.POLY._name = "cmd.POLY"
cmd.POLY.parse = function(tokens, startIdx, endIdx, address)
	result = new self
	result.args = getArguments(tokens, startIdx+1, true)
	if result.args.len != 2 then return printErr("invalid arguments to POLY")
	return result
end function
cmd.POLY.run = function
	x = self.args[0].eval; y = self.args[1].eval
	if not x isa list or not y isa list then return printErr("type mismatch error in POLY")
	if x.len > y.len then maxi = x.len-1 else maxi = y.len-1
	if maxi < 0 then return
	if not requireNum(x[0]) or not requireNum(y[0]) then return
	xy = []
	for i in range(0, maxi)
		xy.push [x[i], y[i]]
	end for
	if machine.fill then
		gfx.fillPoly xy, gfx.color
	else
		gfx.drawPoly xy, gfx.color, machine.pen
	end if
	machine.plotPos = [x[-1], y[-1]]
end function

cmd.PRINT = new Command; cmd.PRINT._name = "cmd.PRINT"
cmd.PRINT.parse = function(tokens, startIdx, endIdx, address)
	// print a series of expressions, separated by , or ; or even just whitespace.
	result = new cmd.PRINT
	result.args = []
	result.delims = []
	fileAndPos = getFile(tokens, startIdx)
	if fileAndPos == null then return
	f = fileAndPos[0]; pos = fileAndPos[1]
	
	needEOL = true
	eval = Evaluator.make(tokens, startIdx, endIdx)
	
	while eval.nextTokIdx < endIdx
		// Grab complete expressions even if they aren't separated
		// by any delimiters.  This is weird, but something old BASICS did,
		// and you can find old BASIC programs that actually use this.  :(		
		endPos = tokens.indexOfAnyParenSavvy([",",";"], pos-1, endIdx, endIdx)
		if pos == endIdx then break			
//		print "Now to print: " + tokens[pos:endPos]
		eval.nextTokIdx = pos
		eval.endIdx = endPos
		arg = eval.parse
//		print "Tokens " + pos + ":" + endPos + " parses to " + arg
		if arg == null then break
		result.args.push arg
		if eval.nextTokIdx < endIdx then
			nextTok = tokens[eval.nextTokIdx]
			if nextTok == "," then
				result.delims.push " "	// ...or char(9)?
			else
				result.delims.push ""
			end if
			if nextTok == "," or nextTok == ";" then eval.nextTokIdx += 1
			needEOL = false
		else if tokens[pos] == "TAB(" then
			// weird quirk of old BASIC: the TAB function acts like a semicolon
			result.delims.push ""
			needEOL = false
		else
			needEOL = true
		end if
		pos = eval.nextTokIdx
	end while
	if needEOL then result.delims.push char(10)
	return result
end function
cmd.PRINT.run = function
	i = -1
	for i in self.args.indexes
		print self.args[i].eval, self.delims[i]
	end for
	if i+1 < self.delims.len then print self.delims[-1], ""
end function

cmd.PWD = new Command; cmd.PWD._name = "cmd.PWD"
cmd.PWD.run = function
	print file.curdir
end function

cmd.READ = new Command; cmd.READ._name = "cmd.READ"
cmd.READ.parse = function(tokens, startIdx, endIdx, address)
	result = new self
	result.lvars = []
	pos = startIdx + 1
	while pos < endIdx
		varEndPos = pos + 1
		if isOpenParen(tokens[pos]) then
			varEndPos = tokens.findCloseParen(pos+1, endIdx) + 1
			if varEndPos == null then return printErr("unmatched parentheses")
		end if
		lvar = Lvar.make(tokens, pos, varEndPos)
		if lvar == null then break
		result.lvars.push lvar
		if varEndPos >= endIdx or tokens[varEndPos] != "," then break
		pos = varEndPos + 1
	end while
	return result
end function
cmd.READ.run = function
	for lvar in self.lvars
		if machine.nextDataIdx >= machine.data.len then return printErr("out of DATA")
		value = stripQuotes(machine.data[machine.nextDataIdx])
//		print "READ " + machine.nextDataIdx + ": " + lvar.str + " = " + value
		machine.nextDataIdx += 1
		if isStringId(lvar.id) and not value isa string then value = str(value)
		setValue lvar, value
	end for
end function

cmd.RECT = new Command; cmd.RECT._name = "cmd.RECT"
cmd.RECT.parse = function(tokens, startIdx, endIdx, address)
	if startIdx+1 >= endIdx then return printErr("incomplete RECT statement")
	result = new self
	result.args = getDrawingArgs(tokens, startIdx+1)
	if result.args == null then return printErr("syntax error in RECT")
	if result.args.len != 4 then return printErr("invalid arguments to RECT")
	return result
end function
cmd.RECT.run = function
	args = self.args
	x = [args[0].eval, args[2].eval]; x.sort
	y = [args[1].eval, args[3].eval]; y.sort
	if machine.fill then
		gfx.fillRect x[0], y[0], x[1] - x[0], y[1] - y[0]
	else
		gfx.drawRect x[0], y[0], x[1] - x[0], y[1] - y[0], gfx.color, machine.pen
	end if
	machine.plotPos = [x[1], y[1]]
end function

cmd.REDIM = new cmd.DIM
cmd.REDIM.redim = true

cmd.REM = new Command; cmd.REM._name = "cmd.REM"
cmd.REM.parse = function(tokens, startIdx, endIdx, address)
	// no-op
	return new cmd.REM
end function

cmd.RENUMBER = new Command; cmd.RENUMBER._name = "cmd.RENUMBER"
cmd.RENUMBER.parse = function(tokens, startIdx, endIdx, address)
	result = new self
	toPos = tokens.indexOf("TO")
	if toPos == null or toPos >= endIdx-1 then return printErr("incomplete RENUMBER command")
	result.startRange = getRange(tokens[startIdx+1:toPos])
	result.destStart = tokens[toPos+1]
	if not result.destStart isa number then return printErr("type mismatch error in RENUMBER command")
	result.destEnd = result.destStart
	
	result.step = 10
	stepPos = tokens.indexOf("STEP", toPos)
	if stepPos >= endIdx-1 then return printErr("incomplete RENUMBER command")
	if stepPos != null then result.step = tokens[stepPos+1]
	if not result.step isa number then return printErr("type mismatch error in RENUMBER command")
	if result.step < 1 then return printErr("invalid STEP in RENUMBER command")
	return result
end function
cmd.RENUMBER.run = function
	machine.sortLines
	if not machine.lineNums then; print "Program empty."; return; end if
	
	startRange = new self.startRange
	if startRange.from == null then startRange.from = 0
	if startRange.to == null then startRange.to = machine.lineNums[-1]

	// start by finding our source lines and building a map to new lines
	remap = {}	// key: old line number; value: new line number
	newPgm = {}	// key: new line number; value: tokens for that line
	destLineNum = self.destStart
	for lineNum in machine.lineNums
		if lineNum < 0 or lineNum < startRange.from then continue
		if lineNum > startRange.to then break
		remap[lineNum] = destLineNum
		newPgm[destLineNum] = machine.program[lineNum]
		print lineNum + " --> " + destLineNum
		destEnd = destLineNum
		destLineNum += self.step
	end for
	
	// next, ensure that the destination area does not overlap any existing lines
	for lineNum in machine.lineNums
		if remap.hasIndex(lineNum) then continue
		if lineNum >= self.destStart and lineNum <= self.destEnd then
			print "Remapped lines would overlap existing line " + lineNum + ";"
			print "operation canceled."
			return
		end if
	end for
	
	// remove the old lines, and add the new ones to the program
	for lineNum in remap.indexes
		machine.program.remove(lineNum)
	end for
	machine.program += newPgm
	
	// and then, update all references (GOTO, GOSUB, RESTORE, THEN)
	for kv in machine.program
		lineNum = kv.key
		line = kv.value
		for i in range(0, line.len-2)
			if line[i] == "GOTO" or line[i] == "GOSUB" then
				for j in range(i+1, line.len-1)
					target = line[j]
					if target == ":" then break
					if target isa number and remap.hasIndex(target) then 
						line[j] = remap[target]
					end if
				end for
			else if i+1 < line.len and (line[i] == "THEN" or line[i] == "RESTORE") then
				target = line[i+1]
				if target isa number and remap.hasIndex(target) then
					line[i+1] = remap[target]
				end if
			end if
		end for
	end for
	
	print "Renumbered " + remap.len + " line" + "s"*(remap.len!=1) + 
	  " to " + self.destStart + "-" + self.destEnd
	
	machine.sortLines
	machine.findComeFroms
end function

cmd.RESTORE = new Command; cmd.RESTORE._name = "cmd.RESTORE"
cmd.RESTORE.parse = function(tokens, startIdx, endIdx, address)
	result = new self
	result.args = getArguments(tokens, startIdx+1)
	return result
end function
cmd.RESTORE.run = function
	if not self.args then
		machine.nextDataIdx = 0
	else if self.args.len > 1 then
		return printErr("Too many arguments to RESTORE command")
	else
		lineNum = val(self.args[0].eval)
		if machine.lineNumToDataIdx.hasIndex(lineNum) then
			machine.nextDataIdx = machine.lineNumToDataIdx[lineNum]
		else
			// the specified line number doesn't have any DATA, so search
			// ahead until we find the next one that does
			lineIdx = machine.lineNums.indexOf(lineNum)
			if lineIdx == null then return printErr("Undefined statement in RESTORE")
			for lineNum in machine.lineNums[lineIdx+1:]
				if machine.lineNumToDataIdx.hasIndex(lineNum) then
					machine.nextDataIdx = machine.lineNumToDataIdx[lineNum]
					return
				end if
			end for
			return printErr("No DATA found at/after line " + args[0])
		end if
	end if
end function

cmd.RETURN = new Command; cmd.RETURN._name = "cmd.RETURN"
cmd.RETURN.run = function
	if not machine.returnStack then return printErr("RETURN without GOSUB")
	returnTo = machine.returnStack.pop
	machine.jumpTo returnTo
end function

cmd.RUN = new Command; cmd.RUN._name = "cmd.RUN"
cmd.RUN.run = function
	machine.halt = true
	machine.doRunRunRun = true
end function

cmd.SAVE = new Command; cmd.SAVE._name = "cmd.SAVE"
cmd.SAVE.parse = function(tokens, startIdx, endIdx, address)
	// like DIR and LOAD, the SAVE command takes a path
	// without quotation marks (and so cannot use an expression)
	result = new self
	args = tokens[startIdx+1:endIdx]
	args.apply(@stripQuotes)
	result.path = args.join("").trim
	return result
end function
cmd.SAVE.run = function
	path = self.path
	if not path then path = machine.programPath
	path = path - ".bas" + ".bas"
	if not path then
		print "No path specified; unable to save"
	else
		pgm = []
		for lineNum in machine.program.sortedIndexes
			if lineNum < 0 then continue
			pgm.push getLineAsText(lineNum, machine.program[lineNum])
		end for
		err = file.writeLines(path, pgm)
		if err then
			print err
		else
			print pgm.len + " lines saved to " + path
			machine.programPath = path	// ToDo: get full path
		end if
	end if
end function

cmd.SOUND = new Command; cmd.SOUND._name = "cmd.SOUND"
cmd.SOUND.parse = function(tokens, startIdx, endIdx, address)
	result = new self
	result.args = getArguments(tokens, startIdx + 1, true)
	if result.args.len > 4 then return printErr("invalid arguments to SOUND command")
	return result
end function
cmd.SOUND.run = function
	// SOUND arguments (all optional):
	frequency = 440 // (in Hz, if positive; or -MIDI note numbers, if negative)
	duration = 0.5	// (in seconds)
	volume = 1		// volume (0-1)
	waveform = 1	// 0=sine, 1=triangle, 2=sawtooth, 3=square, 4=noise
	// Note that frequency and volume can take arrays instead of scalar values.
	
	args = self.args[:]
	for i in args.indexes; args[i] = args[i].eval; end for
	if args.len > 0 then
		frequency = args[0]
		if frequency isa list then
			for i in frequency.indexes
				frequency[i] = val(frequency[i])
				if frequency[i] <= 0 then frequency[i] = noteFreq(-frequency[i])
			end for
		else
			frequency = val(frequency)
			if frequency <= 0 then frequency = noteFreq(-frequency)
		end if
	end if
	if args.len > 1 then
		duration = val(args[1])
		if duration isa list then return printErr("SOUND duration must be a number")
	end if
	if args.len > 2 then
		volume = args[2]
		if volume isa list then
			for i in volume.indexes; volume[i] = val(volume[i]); end for
		else
			volume = val(volume)
		end if
	end if
	if args.len > 3 then waveform = args[3]
	if waveform isa list then
		wave = waveform
	else
		waveform = val(waveform)
		options = [Sound.sineWave, Sound.triangleWave, Sound.sawtoothWave, 
					Sound.squareWave, Sound.noiseWave]
		if waveform < 0 then waveform = 0
		if waveform >= options.len then waveform = options.len - 1
		wave = options[waveform]
	end if
	
	snd = new Sound
	snd.init duration, frequency, volume, wave
	snd.play
end function

cmd.VTAB = new Command; cmd.VTAB._name = "cmd.VTAB"
cmd.VTAB.parse = function(tokens, startIdx, endIdx, address)
	result = new self
	result.arg = Evaluator.make(tokens,startIdx+1, endIdx).parse
	return result
end function
cmd.VTAB.run = function
	text.row = 26 - val(self.arg.eval)
end function

cmd.WAIT = new Command; cmd.WAIT._name = "cmd.WAIT"
cmd.WAIT.duration = SNLiteral.one
cmd.WAIT.parse = function(tokens, startIdx, endIdx, address)
	result = new self
	if startIdx+1 < endIdx then
		result.duration = Evaluator.make(tokens, startIdx+1, endIdx).parse
	end if
	return result
end function
cmd.WAIT.run = function
	wait val(self.duration.eval)
end function


// Run one statement within the given set of tokens,
// returning the token that starts the NEXT statement
// within the same set, or null if there are no more.
Machine.runOneStatement = function(tokens, startTokenIndex)
	if startTokenIndex >= tokens.len then return null
	cmdName = tokens[startTokenIndex]
	if isIdentifier(cmdName) then
		// check for the special case of an assignment statement without LET
		if isOpenParen(cmdName) then
			assignPos = tokens.findCloseParen(startTokenIndex + 1) + 1
		else
			assignPos = startTokenIndex + 1
		end if
		if assignPos < tokens.len and tokens[assignPos] == "=" then cmdName = "LET"
	end if
	statementEnd = tokens.indexOfAny([":","THEN","ELSE"], startTokenIndex)
	if statementEnd == null then statementEnd = tokens.len
	cmdObj = cmd.get(cmdName)
	if cmdObj == null then
		printErr "Command not found: " + cmdName
		return null
	end if
//	print "found parse." + cmdName
	cmdRunner = cmdObj.parse(tokens, startTokenIndex, statementEnd)
//	print "calling cmd." + cmd + " with " + tokens + "[" + startTokenIndex + ":" + statementEnd + "]"
	if cmdRunner then
		// Most commands don't alter the next statement to run,
		// but a few do.  Give each one a chance to return the
		// next token index; but if they don't, just advance
		// past the delimiter (unless it's ELSE).
		nextStart = cmdRunner.run
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
		printErr "Unknown command: " + cmdName
		return null
	end if
end function

Machine.doImmediate = function(tokens)
	self.inThen = false
	self.halt = false
	self.tokenIdx = 0
	self.lineIdx = null
	while not self.halt and self.tokenIdx < tokens.len
		self.nextAddress = null
		// ToDo: fix this!
		self.tokenIdx = self.runOneStatement(tokens, self.tokenIdx)
		if self.lineIdx != null or self.nextAddress != null then break
	end while
end function

//Machine.runStatements = function(code, lineNum)
//	if self.trace and lineNum >= 0 then print "#" + lineNum + " ", ""
//	self.address.statementIndex = 0
//	while self.address.statementIndex < code.len
//		self.nextAddress = null
//		code[self.statementIdx].run
//		if controlCPressed then
//			cmd.BREAK.run
//			while controlCPressed; yield; end while
//		end if
//		if self.halt then return
//		if self.nextAddress != null then break
//		self.address.statementIndex += 1
//	end while
//end function

// Compile one statement in the given set of tokens.
// Return AST adorned with two additional values:
//		startTokenIdx
//		endTokenIdx
Machine.compileStatement = function(tokens, startIdx, address)
	cmdName = tokens[startIdx]
	if isIdentifier(cmdName) then
		// check for the special case of an assignment statement without LET
		if isOpenParen(cmdName) then
			assignPos = tokens.findCloseParen(startIdx + 1) + 1
		else
			assignPos = startIdx + 1
		end if
		if assignPos < tokens.len and tokens[assignPos] == "=" then cmdName = "LET"
	end if
	statementEnd = tokens.indexOfAny([":","THEN","ELSE"], startIdx)
	if statementEnd == null then statementEnd = tokens.len
	cmdObj = cmd.get(cmdName)
	if cmdObj == null then
		printErr "Command not found: " + cmdName + " in " + address.displayStr
		return null
	end if
	result = cmdObj.parse(tokens, startIdx, statementEnd, address)
	result.startTokenIdx = startIdx
	if not result.hasIndex("endTokenIdx") then result.endTokenIdx = statementEnd
	return result
end function

Machine.compile = function
	self.code = {}  // key: line number; value: list of parse trees (one per statement)
	for i in self.lineNums.indexes
		lineNum = self.lineNums[i]
		self.code[lineNum] = []
		tokens = self.program[lineNum]
		tokenIdx = 0
		statementIdx = 0
		openIf = 0
		while tokenIdx < tokens.len
			ast = Machine.compileStatement(tokens, tokenIdx, Address.make(i, statementIdx))
			if self.halt then return
			self.code[lineNum].push ast
			if ast isa cmd.IF then openIf += 1
			if ast isa cmd.ELSE then
				if not openIf then return printErr("Unexpected ELSE")
			end if
			if ast.endTokenIdx < tokens.len and tokens[ast.endTokenIdx] == "ELSE" then
				// parse "ELSE" as a statement of its own, even if not preceded by ':'
				if not openIf then return printErr("Unexpected ELSE")
				self.code[lineNum].push cmd.ELSE.parse(tokens, ast.endTokenIdx, ast.endTokenIdx, Address.make(i))
				statementIdx += 1
			end if
			tokenIdx = ast.endTokenIdx + 1
			statementIdx += 1
		end while
	end for
end function

Machine.runProgram = function(startLineNum=0, clearData=true)
	if clearData then self.resetData
	self.sortLines
	if clearData then self.findData
	self.halt = false
	self.inThen = false
	self.nextAddress = null
	if not self.lineNums then return
	self.compile
	self.timeAtRun = time
//	machine.trace = true
	if self.halt and startLineNum >= 0 then return
	idx = 0
	while idx < self.lineNums.len and self.lineNums[idx] < startLineNum
		idx += 1
	end while
	if idx >= self.lineNums.len then return
	self.address = Address.make(idx)
	self.halt = false
	while not self.halt
		self.runOneLine
	end while
end function

// Execute all the statements in the current line, returning when
// we run out of statements or when some command jumps us to a
// different address.  End by updating self.address to the next
// address to be executed.
Machine.runOneLine = function
	addr = self.address
	if addr.lineIndex < 0 or addr.lineIndex >= self.lineNums.len then
		self.halt = true
		return
	end if
	if not addr isa Address or not addr.lineIndex isa number then
		print "Bogus address:"
		pprint addr
		pprint stackTrace
		exit
	end if
	lineNum = self.lineNums[addr.lineIndex]
	code = self.code[lineNum]

	while addr.statementIndex < code.len	
		if self.trace and lineNum >= 0 then print addr.displayStr
		self.nextAddress = null
		code[addr.statementIndex].run
		if controlCPressed then
			cmd.BREAK.run
			while controlCPressed; yield; end while
		end if
		if self.halt then return
		if self.nextAddress != null then break
		addr.statementIndex += 1
	end while
	
	if self.nextAddress == null then
		addr.lineIndex += 1
		addr.statementIndex = 0
	else
		addr.lineIndex = self.nextAddress.lineIndex
		addr.statementIndex = self.nextAddress.statementIndex
		// ToDo: correctly handle IF that specifies a THEN target that does not exist!
		if addr.lineIndex < self.lineNums.len and 
		   addr.statementIndex >= self.code[self.lineNums[addr.lineIndex]].len then
			addr.lineIndex += 1
			addr.statementIndex = 0
		end if
	end if
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
	self.lineNumToDataIdx = {}
	for lineNum in self.lineNums
		line = self.program[lineNum]
		pos = 0
		while pos < line.len
			endPos = line.indexOf(":", pos)
			if endPos == null then endPos = line.len
			if line[pos] == "DATA" then
				if not self.lineNumToDataIdx.hasIndex(lineNum) then
					self.lineNumToDataIdx[lineNum] = self.data.len
				end if
				for p in range(pos+1, endPos-1)
					if line[p] != "," then self.data.push line[p]
					if line[p] == "DATA" then
						print "wtf? pushing DATA for token " + p + " of line " + lineNum + ": " + line
						exit
					end if
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
			if line[i] == "GOTO" or line[i] == "GOSUB" then
				for j in range(i+1, line.len-1)
					target = line[j]
					if target == ":" then break
					if target isa number then self.comeFrom[target] = self.comeFrom.get(target, []) + [lineNum]
				end for
			else if i+1 < line.len and line[i] == "THEN" then
				target = line[i+1]
				if not target isa number then continue
				self.comeFrom[target] = self.comeFrom.get(target, []) + [lineNum]
			end if
		end for
	end for
end function

Machine.goTo = function(lineNum)
	lineIdx = self.lineNums.indexOf(lineNum)
	if lineIdx == null then
		printErr "Invalid line number: " + lineNum
		self.halt
	else
		self.nextAddress = Address.make(lineIdx)
	end if
	return 0
end function

Machine.jumpTo = function(address)
	self.nextAddress = address
end function

machine = new Machine
machine.timeAtStart = time

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
	assertEqual tokenize("B(J)=A1(J)-48"), ["B(", "J", ")", "=", "A1(", "J", ")", "-", 48]
	
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
	
	e = Evaluator.make(["""foo""", 42, "+", 3, """bar"""])
	assertEqual e.evaluate, "foo"
	assertEqual e.nextTokIdx, 1
	assertEqual e.evaluate, 45
	assertEqual e.nextTokIdx, 4
	assertEqual e.evaluate, "bar"
	assertEqual e.nextTokIdx, 5
	
	//args = getArguments(["FOO", 47, "-", 5, ",", """foo"""], 1)
//	assertEqual args, [42, "foo"]
//	args = getArguments(["FOO", 47, "-", 5, ",", """foo""", ":", "REM"], 1)
//	assertEqual args, [42, "foo"]
	
	if errorCount then exit
end function

//======================================================================
// Main Program
//======================================================================

runMainLoop = function
//	env.bootOpts.controlC = false
	machine.reset
	cmd.HOME.run
	runUnitTests

	print "MiniBASIC 0.9.6"

	globals.basic = function
		reset
		load "/usr/basic"
		run
	end function
	_savedGlobals.basic = @basic

	cd "/usr/programs"

	// Main loop (invoking the REPL until done)
	while true
		if text.column > 0 then print
		machine.doRunRunRun = false
		line = inputOrControlC(">")
		if line == char(3) then
			print "BREAK"
			_printMark "(To exit MiniBASIC, type: `exit`)", color.orange
			while controlCPressed; yield; end while
			continue
		end if
		if line.lower == "exit" then break
		repl line
		if machine.doRunRunRun then machine.runProgram
	end while
	
	print "Exiting MiniBASIC."
	print "You are now at the MiniScript (not MiniBASIC!) prompt."
	_printMark "To return to MiniBASIC, type: `basic`", "#00FF00"
	_printMark "For other useful commands, type: `help`", "#FFCC00"
	text.color = color.orange
	env.bootOpts.controlC = true
end function

if locals == globals then runMainLoop