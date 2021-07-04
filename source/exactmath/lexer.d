/++

+/
module exactmath.lexer;

import std.exception : enforce;

/++

+/
struct Token
{
    /++
    
    +/
    static struct Loc
    {
        uint line;
        uint ch;
    }
    
    ///
    string value;
    //alias value this;
    
    ///
    Loc loc;
}

/++

+/
final class LexerException : Exception
{
    import std.exception : basicExceptionCtors;
    
    ///
    mixin basicExceptionCtors;
}

/++

+/
struct Delimiter
{
    ///
    string start;
    ///
    string end;
    ///
    string escape = null;
    ///
    Delimiter* nest = null;
}

/++

+/
struct TokenRange
{
private:
    immutable size_t length;
    size_t currentTokenStart = -1;
    size_t a;
    const string[] stoppers;
    const Delimiter[] delimiters;
    string searched;
    Token[] results; // TODO immutable?
                     // TODO use StackBuffer?
    
    Token.Loc loc1, loc2;
    
public:
    /++
    
    +/
    this(string searched, const string[] stoppers, const Delimiter[] delimiters) pure @safe
    {
        a = 0;
        this.searched = searched;
        this.stoppers = stoppers;
        this.delimiters = delimiters;
        this.length = searched.length;
        this.popFront(true); // initialise first results
    }
    
    /++
    Returns:
        the `Token` that is currently on the front.
    Throws:
        `LexerException` if the range is empty
    +/
    @property Token front() const return scope pure @safe
    {
        enforce!LexerException(!this.empty, "Tried to access the front of a TokenRange which was empty");
        return results[0];
    }
    
    /++
    Params:
        n = the number of tokens you want to peek n.
    Returns:
        whether it's good to call `peek(n)`.
    +/
    deprecated("handle peeking yourself")
    bool canPeek(size_t n = 1) const scope @nogc nothrow pure @safe
    {
        return results.length >= n + 1;
    }
    
    /++
    Peeks ahead `n` tokens. Can currently peek ahead at most 1 token.
    
    Throws:
        `LexerException` if it cannot be peeked
    See_Also:
        `jdc.lexer.TokenRange.canPeek`
    +/
    deprecated("handle peeking yourself")
    Token peek(size_t n = 1) const scope pure @safe
    {
        assert(n <= 1, "Cannot peek a TokenRange for more than 1 yet.");
        //assert(results.length > n, "Tried to peek a TokenRange which is not yet filled enough");
        enforce!LexerException(this.canPeek(), "Tried to peek for a token while unavailable");
        return results[n];
    }
    
    /++
    
    +/
    void popFront(bool firstTime = false) /+scope @safe+/ pure @trusted
    {
        // `@trusted` and not `scope` because DIP1000 doesn't allow temporary dynamic arrays
        
        import std.algorithm.iteration : filter, map;
        import std.algorithm.searching : all, startsWith;
        import std.ascii : isWhite;
        import std.array : array;
        import std.range : chain;
        import std.string : strip;
        
        enforce!LexerException(this.hasCached || this.hasLeft,
            "Tried to advance a token range that is empty: unexpected end of input!");
        
        const(Delimiter)[] delimStack = []; // TODO make this a hybrid stack/malloc allocator (StackBuffer)
        
        void updateLoc1(size_t pos)
        {
            if (searched[pos] == '\n' || (pos < searched.length + 1 && searched[pos .. pos + 2] == "\r\n"))
            {
                loc1.line++;
                loc1.ch = 0;
            }
            else
                loc1.ch++;
        }
        
        // stops when it has enough results OR when there is nothing left to tokenize.
        for (; !(this.results.length > 2 /+ 1 +/ || !this.hasLeft); a++)
        {
            bool starts(const Delimiter range)
            {
                return (
                    searched.length > a + range.start.length && // the delimiter fits in the string
                    //(range.escape.length == 0 || a >= range.escape.length && searched[a - range.escape.length .. a] != range.escape) && // it doesn't have the escape chars in front of it
                    searched[a .. a + range.start.length] == range.start // the searched starts with the delimiter's start
                );
            }
            
            /+auto checkedRanges = delimiters.filter!((range) { return
                searched.length > a + range.start.length && // the delimiter fits in the string
                (!range.escape || a >= range.escape.length && searched[a - range.escape.length .. a] != range.escape) && // it doesn't have the escape chars in front of it
                searched[a .. a + range.start.length] == range.start // the searched starts with the delimiter's start
            ;});+/
            auto checkedRanges = (delimStack.length && delimStack[$ - 1].nest ? chain(delimiters, [*delimStack[$ - 1].nest]).array() : delimiters).filter!starts;
            
            if (!checkedRanges.empty && // if getting into range
                (delimStack.length == 0 || delimStack[$ - 1].nest && starts(*delimStack[$ - 1].nest)))
            {
                delimStack ~= checkedRanges.front;
                a += checkedRanges.front.start.length - 1;
                continue;
            }
            else if (delimStack.length > 0 && // if getting out of a range
                    (delimStack[$ - 1].escape == "" || a > delimStack[$ - 1].escape.length && // (validate (current range).escape)
                    searched[a - delimStack[$ - 1].escape.length .. a] != delimStack[$ - 1].escape) && // it is not being escaped
                    (searched.length > a + delimStack[$ - 1].end.length &&
                    searched[a .. $].startsWith(delimStack[$ - 1].end))) // current range is present starting from index `a`
            {
                auto previousEndLength = delimStack[$ - 1].end.length;
                a += previousEndLength - 1; // skip to after the found token
                delimStack = delimStack[0 .. $ - 1];
                if (delimStack.length == 0)
                {
                    results ~= Token(
                        searched[currentTokenStart + 1 .. a + previousEndLength].strip,
                        loc1
                    );
                    foreach (pos; currentTokenStart .. a)
                        updateLoc1(pos);
                    // loc2 needs to be updated for a later iteration, since it isn't used here anyway
                    loc2 = loc1;
                    currentTokenStart = a;
                }
                continue;
            }
            
            if (delimStack.length == 0)
            {
                auto foundToken = stoppers.filter!((string stopper) => a + stopper.length <= searched.length && searched[a .. a + stopper.length] == stopper);
                if (!foundToken.empty) // if it found a stopper
                {
                    foreach (pos; currentTokenStart .. a)
                        updateLoc1(pos);
                    
                    // add all before stopper
                    results ~= Token(
                        searched[currentTokenStart + 1 .. a].strip,
                        loc2
                    );
                    
                    // then stopper itself
                    results ~= Token(
                        searched[a .. a + foundToken.front.length].strip,
                        loc1
                    );
                    a += foundToken.front.length - 1; // skip to after the found token
                    currentTokenStart = a;
                    loc2 = loc1;
                }
            }
        }
        if (!firstTime) results = results[1 .. $];
        // TODO: make this use "isWhite" instead
        if (this.hasCached && (this.front.value == " " || this.front.value == "" || this.front.value == "\r" || this.front.value == "\n" || this.front.value == "\r\n")) this.popFront();
        assert(!this.hasLeft || this.hasCached, "TokenRange has no results, but isn't done???");
    }
    
    @property bool hasCached() const scope @nogc nothrow pure @safe
    {
        return results.length > 0;
    }
    @property bool hasLeft() const scope @nogc nothrow pure @safe
    {
        return a < length;
    }
    
    /++
    Returns:
        whether this `TokenRange` is done lexing
    +/
    @property bool empty() const scope @nogc nothrow pure @safe
    {
        return !this.hasCached;
    }
}

// TODO make parameter `searched` an input range too

/++
Returns a range that lazily lexes the input string.

Params:
    searched = the string that is being lexed
    stoppers = the set of tokens that will be separated from the rest
    delimiters = the delimited ranges
Returns:
    a new `TokenRange` with the appropriate properties
+/
auto splitIntoTokens(string searched, const string[] stoppers, const Delimiter[] delimiters) pure @safe
{
    return TokenRange(searched, stoppers, delimiters);
    
    /+static if (skipNewlines) return result.map!((token) => token.filter!((x) => x != '\n' && x != '\r').array.to!string);
    else return result;+/
}

