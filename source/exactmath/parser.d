/++
+/
module exactmath.parser;

import exactmath.ast;
import exactmath.state;
import std.array : staticArray;
import std.range.primitives; // primitives and isInputRange

/++
+/
enum OpLevel : int
{
    ///
    comma = 0,
    
    ///
    lambda = 1,
    
    ///
    to = 2,
    
    ///
    add = 3,
    
    ///
    mul = 4,
    
    ///
    unary = 5,
    
    ///
    pow = 6,
    
    ///
    primary = 7,
}

/++
+/
static immutable keywords = [
    "in",
    "let",
    "or",
    "test",
    "to",
    "type",
].staticArray;

/++
+/
bool isIdentifier(string value) pure
{
    if (value.length == 0)
        return false;
    
    if ((value[0] < 'a' || value[0] > 'z') &&
        (value[0] < 'A' || value[0] > 'Z') &&
        (value[0] != '_'))
    {
        return false;
    }
    
    foreach (ch; value[1 .. $])
    {
        if ((ch < 'a' || ch > 'z') &&
            (ch < 'A' || ch > 'Z') &&
            (ch < '0' || ch > '9') &&
            ch != '_')
        {
            return false;
        }
    }
    
    foreach (keyword; keywords)
    {
        if (value == keyword)
            return false;
    }
    
    return true;
}

/+
We know when to use it and it's private, so `@trusted` is justified.
+/
private immutable(T) unique(T)(T value) @trusted
{
    return cast(immutable) value;
}

/++
+/
struct Parser(T)
if (isInputRange!T)
{
    import exactmath.lexer : Token;
    
pure:
    private this(T input)
    {
        _tokenCount = 2;
        _input = input;
    }
    
    /++
    +/
    Statement parseStatement()
    {
        log();
        
        if (front.value == "type")
        {
            popFront();
            auto type = parseType().unique;
            if (front.value == "=")
            {
                popFront();
                assert(false, "type alias statements unimplemented");
            }
            return Statement(TypeStatement(type));
        }
        
        if (front.value == "[")
            return Statement(EquationStatement(parseEquation().unique));
        
        auto expr = parseExpr().unique;
        
        if (front.value == "=" || front.value == "!=" || front.value == ">" ||
            front.value == ">=" || front.value == "<" || front.value == "<=")
        {
            return Statement(EquationStatement(parseEquation(expr).unique));
        }
        
        return Statement(ExprStatement(expr.unique)); // just a single expression
    }
    
    Equation parseEquation()
    {
        log();
        
        return parseEquation(parseExpr().unique);
    }
    
    private Equation parseEquation(immutable Expr firstExpr)
    {
        auto result = parseMultiEquation(firstExpr);
        if (front.value == "=>")
        {
            popFront();
            return new ImpliesEquation(
                result.unique,
                parseMultiEquation(parseExpr().unique).unique,
            );
        }
        return result;
    }
    
    private Equation parseMultiEquation(immutable Expr firstExpr)
    {
        log();
        
        auto first = parseCmpEquation(firstExpr);
        
        if (front.value == ";")
        {
            auto result = [ first ];
            while (front.value == ";")
            {
                popFront();
                result ~= parseCmpEquation();
            }
            return new AndEquation(result.unique);
        }
        
        if (front.value == "or")
        {
            auto result = [ first ];
            while (front.value == "or")
            {
                popFront();
                result ~= parseCmpEquation();
            }
            return new OrEquation(result.unique);
        }
        
        return first;
    }
    
    private Equation parseCmpEquation()
    {
        log();
        
        if (front.value == "[")
        {
            popFront();
            auto result = parseEquation();
            if (front.value != "]")
                throw new ParseException("wrong syntax: `]` expected after `[`");
            
            return result;
        }
        
        return parseCmpEquation(parseExpr().unique);
    }
    
    private Equation parseCmpEquation(immutable Expr first)
    {
        log();
        
        switch (front.value)
        {
        case "=":
            popFront();
            return new EqualEquation(first, parseExpr().unique);
            
        case "!=":
            popFront();
            return new NotEquation(cast(immutable) new EqualEquation(first, parseExpr().unique).unique);
            
        case "<":
            popFront();
            //return new LTEquation(first, parseExpr());
            assert(false, "unimplemented");
            
        case "<=":
            popFront();
            //return new LEEquation(first, parseExpr());
            assert(false, "unimplemented");
            
        case ">":
            popFront();
            //return new GTEquation(first, parseExpr());
            assert(false, "unimplemented");
            
        case ">=":
            popFront();
            //return new GEEquation(first, parseExpr());
            assert(false, "unimplemented");
            
        default:
            throw new ParseException("Unexpected token after expression: " ~ front.value);
        }
    }
    
    /++
    +/
    Expr parseExpr()
    {
        return parseLambdaExpr();
    }
    
    private Expr parseLambdaExpr()
    {
        log();
        
        auto result = parseToExpr();
        
        if (front.value == "->") // right-associative
        {
            popFront();
            return new LambdaExpr(result.unique, parseLambdaExpr().unique);
        }
        
        return result;
    }
    
    private Expr parseToExpr()
    {
        log();
        
        auto result = parseAddExpr();
        
        while (true)
        {
            if (front.value == "to")
            {
                popFront();
                result = new ToExpr(result.unique, parseAddExpr().unique);
                continue;
            }
            
            return result;
        }
        
        assert(false, "unreachable");
    }
    
    private Expr parseAddExpr()
    {
        log();
        
        auto result = parseMulExpr();
        
        while (true)
        {
            if (front.value == "+")
            {
                popFront();
                result = new AddExpr(result.unique, parseMulExpr().unique);
                continue;
            }
            
            if (front.value == "-")
            {
                popFront();
                result = new SubExpr(result.unique, parseMulExpr().unique);
                continue;
            }
            
            return result;
        }
        
        assert(false, "unreachable");
    }
    
    /+
    GRAMMAR.md: MulExpr
    +/
    private Expr parseMulExpr()
    {
        log();
        
        auto result = parseUnaryExpr();
        assert(result !is null);
        
        if (isIdentifier(front.value)) // UnaryExpr UnitExpr
            result = new MulExpr(result.unique, parseUnitExpr().unique);
        
        while (true)
        {
            switch (front.value)
            {
            case "*":
                popFront();
                result = new MulExpr(result.unique, parseUnaryExpr().unique);
                break;
                
            case "/":
                popFront();
                result = new DivExpr(result.unique, parseUnaryExpr().unique);
                break;
                
            case "%":
                popFront();
                result = new ModExpr(result.unique, parseUnaryExpr().unique);
                break;
                
            default:
                return result;
            }
        }
        
        assert(false, "unreachable");
    }
    
    private Expr parseUnaryExpr()
    {
        log();
        
        if (front.value == "-")
        {
            popFront();
            return new NegExpr(parseUnaryExpr().unique);
        }
        
        return parsePowExpr();
    }
    
    private Expr parsePowExpr()
    {
        log();
        
        auto result = parsePrimaryExpr();
        if (front.value == "^")
        {
            popFront();
            return new PowExpr(result.unique, parseUnaryExpr().unique); // TODO make this parsePowExponent according to grammar
        }
        return result;
    }
    
    private Expr parsePrimaryExpr()
    {
        log();
        
        auto result = {
            switch (front.value)
            {
            case "(": // tuple OR other parenthesised expression
                popFront();
                bool trailingComma; //out
                auto args = parseArgList(trailingComma);
                if (front.value != ")")
                    throw new ParseException("Unexpected token in parenthesised expression instead of ')'");
                popFront();
                if (args.length == 1 && !trailingComma)
                    return args[0];
                return new TupleExpr(args.unique);
                
            case "{": // list/collection
                throw new ParseException("`{` is reserved for collections");
                
            case "test":
                throw new ParseException("`test` is a reserved keyword");
                
            case "let":
                throw new ParseException("`let` is a reserved keyword");
            case "in":
                throw new ParseException("`in` is a reserved keyword");
                
                // all kinds of built-in AST nodes
            case "__neg":
            case "__ln":
            case "__sin":
            case "__cos":
            case "__tan":
            case "__add":
            case "__min":
            case "__mul":
            case "__div":
            case "__mod":
            case "__pow":
            case "__log":
            case "__deriv":
                throw new ParseException("`__` prefixed identifiers are reserved");
                
            default:
                if (front.value[0] >= '0' && front.value[0] <= '9') // number
                {
                    import std.conv : parse;
                    
                    auto digits = front.value;
                    popFront();
                    if (front.value == ".")
                    {
                        popFront();
                        digits ~= ".";
                        digits ~= front.value;
                        popFront();
                        return new NumExpr(parse!double(digits));
                    }
                    return new IntExpr(parse!ulong(digits));
                }
                
                auto id = front.value; // TODO verify identifier
                popFront();
                if (id[0] == '$')
                    return new LocalExpr(id[1 .. $]);
                else
                    return new UnknownExpr(id); // identifier
            }
        }();
        
        while (true)
        {
            switch (front.value)
            {
            case ".":
                popFront();
                auto id = front.value;
                popFront();
                result = new DotExpr(result.unique, id);
                break;
                
            case "(":
                popFront();
                auto arg = parseExpr();
                if (front.value != ")")
                    throw new ParseException("Expected ')' after function call");
                popFront();
                
                result = new CallExpr(result.unique, arg.unique);
                break;
                
            case "[":
                popFront();
                auto index = parseExpr();
                if (front.value != "]")
                    throw new ParseException("Expected ']' after indexing");
                popFront();
                
                result = new IndexExpr(result.unique, index.unique);
                break;
                
            case "'":
                popFront();
                result = new AccentExpr(result.unique);
                break;
                
            default:
                return result;
            }
        }
        
        assert(false, "unreachable");
    }
    
    private Expr parseUnitExpr()
    in (isIdentifier(front.value))
    {
        auto id = front.value;
        auto firstUnknown = new UnknownExpr(id);
        popFront();
        
        if (front.value == "^")
        {
            popFront();
            auto exponent = parseUnaryExpr();
            if (isIdentifier(front.value))
            {
                return new MulExpr(
                    new immutable PowExpr(firstUnknown.unique, exponent.unique),
                    parseUnitExpr().unique,
                );
            }
            return new PowExpr(firstUnknown.unique, exponent.unique);
        }
        
        if (isIdentifier(front.value))
            return new MulExpr(firstUnknown.unique, parseUnitExpr().unique);
        return firstUnknown;
    }
    
    /+
    GRAMMAR.md: ArgList
    
    Always ends before `)`, `]` or `}`.
    +/
    private Expr[] parseArgList(out bool trailingComma)
    {
        log();
        
        trailingComma = false;
        if (front.value != ")" && front.value != "]" && front.value != "}")
        {
            Expr[] result = [ parseExpr() ];
            while (front.value == ",")
            {
                popFront();
                if (front.value == ")" || front.value == "}" || front.value == "}")
                {
                    trailingComma = true;
                    break;
                }
                result ~= parseExpr();
            }
            return result;
        }
        
        return [];
    }
    
    /+--- types ---+/
    
    /++
    +/
    Type parseType()
    {
        log();
        
        auto result = parseSumType();
        
        if (front.value == "->")
        {
            popFront();
            return new LambdaType(result.unique, parseType().unique);
        }
        
        return result;
    }
    
    private Type parseSumType()
    {
        log();
        
        auto first = parseProductType();
        
        if (front.value == "+")
        {
            immutable(Type)[] subTypes = [ first.unique ];
            do
            {
                popFront();
                subTypes ~= parseProductType().unique;
            }
            while (front.value == "+");
            
            return new SumType(subTypes.unique);
        }
        
        return first;
    }
    
    private Type parseProductType()
    {
        log();
        
        auto first = parsePrimaryType();
        
        if (front.value == "*")
        {
            immutable(Type)[] subTypes = [ first.unique ];
            do
            {
                popFront();
                subTypes ~= parsePrimaryType().unique;
            }
            while (front.value == "*");
            
            return new ProductType(subTypes.unique);
        }
        
        return first;
    }
    
    private Type parsePrimaryType()
    {
        log();
        
        /+
        if (front.value == "Any")
        {
            popFront();
            return AnyType.instance;
        }
        +/
        
        if (front.value == "typeof")
        {
            popFront();
            return new TypeofType(parseExpr().unique);
        }
        
        if (front.value == "in")
        {
            popFront();
            return new InType(parseExpr().unique);
        }
        
        auto id = front.value;
        return new UnknownType(id);
    }
    
private:
    void log(string s = __FUNCTION__, uint line = __LINE__)
    {
        debug
        {
            //import std.conv : to;
            //_logger("in " ~ s ~ " at " ~ front.value ~ " at line " ~ line.to!string);
        }
    }
    
    // just forward range functions to `_input` because lookahead is not
    // necessary (yet)
    
    void popFront(uint line = __LINE__)
    {
        log(__FUNCTION__, line);
        
        if (this.empty)
            throw new ParseException("Unexpected end of input after " ~ _lastTokens[0] ~ " " ~ _lastTokens[1]);
        
        _input.popFront();
        
        _lastTokens[0] = _lastTokens[1];
        _lastTokens[1] = this.front.value;
    }
    
    @property Token front()
    {
        if (this.empty)
            return Token("");
        //assert(!empty, "Cannot access the front of an empty Parser");
        return _input.front;
    }
    
    @property bool empty() const
    {
        return _input.empty;
    }
    
    string[2] _lastTokens;
    T _input;
    uint _tokenCount;
}

/++
+/
final class ParseException : Exception
{
    import std.exception : basicExceptionCtors;
    
    ///
    mixin basicExceptionCtors;
}

/++
Parses a math expression from a string.

Throws:
    `ParseException` on illegal input
Params:
    str = the string to be parsed
Returns:
    The `Statement` parsed
+/
Statement parseMathStatement(string str)
{
    import exactmath.lexer : splitIntoTokens, Token, TokenRange;
    import std.array : array;
    import std.algorithm.iteration : map;
    import std.conv : to;
    
    auto tokens = splitIntoTokens(
        str ~ " ", // hack (*)
        [" ", ";", "->", "<=", ">=", "!=", "=>", ",", "+", "-", "*", "/", "%", "^", ".", "'", ":", "=", "<", ">", "(", ")", "[", "]", "{", "}"],
        [] // delimiters
    );
    
    // (*)
    // PROBLEM: the lexer doesn't get the last token!
    // SOLUTION: fix the lexer
    // FOR NOW: add a bit of whitespace to the end.
    
    auto parser = Parser!TokenRange(tokens);
    return parser.parseStatement();
}
