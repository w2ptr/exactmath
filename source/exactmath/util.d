/++
+/
module exactmath.util;

import std.range.primitives : isRandomAccessRange;

/++
Pretends a function is `pure` while it is not.

Parameters:
    fn = the function that is cast to pure
    T = the arg types
    args = the arguments passed to `fn`
Returns:
    the result of the call of `fn` with `args`
+/
template assumePure(alias fn)
{
    auto assumePure(T...)(auto ref T args) pure @system
    {
        import std.functional : forward;
        import std.traits : ReturnType, Parameters;
        return (cast(ReturnType!fn function(Parameters!fn) pure) &fn)(forward!args);
    }
}

/++
+/
string doubleToString(double num) pure
{
    import std.math : log10, floor;
    import std.conv : to;
    
    if (num == 0.0) return "0";
    if (num % 1.0 == 0.0)
        return to!string(cast(long) num);
    
    enum precision = 4;
    enum exp = 10 ^^ precision;
    immutable double n = num * exp;
    size_t digits = cast(size_t) floor(log10(num) + 1.0);
    string str = to!string(cast(long) n);
    return str[0 .. digits] ~ "." ~ str[digits .. $];
}

/++
Returns:
    an array with the mapped elements
+/
auto eagerMap(alias func, T)(immutable T[] array) pure //infer?
{
    //import std.exception : assumeUnique;
    import std.traits : ReturnType;
    
    ReturnType!((immutable T input) => func(input))[] result;
    result.reserve(array.length);
    foreach (value; array)
        result ~= func(value);
    return result;
}

/++
+/
immutable(Out) eagerReduce(alias func, In, Out)(immutable In[] array, auto ref immutable Out startingValue) pure //infer?
{
    import std.exception : assumeUnique;
    Out result = startingValue;
    foreach (value; array)
        result = func(result, value);
    return cast(immutable) result;
}

/// force something at ctfe
template ctfe(alias val)
{
    static if (is(typeof(val) == string))
    {
        static immutable typeof(mixin(val)) ctfe;
        shared static this()
        {
            ctfe = mixin(val);
        }
    }
    else
    {
        static shared immutable ctfe = val;
    }
}

/++
Converts the range to a string with to!string, but with separators in between.
Params:
    T = the type of range
    range = the input range
    separator = string that comes between all elements of the range
+/
string toStringSeparated(T)(T range, string separator) pure
{
    import std.range : empty;
    string result;
    result.reserve(range.length * 7);
    if (range.empty) return "";
    foreach (value; range)
    {
        static if (__traits(compiles, value.toString())) //because is pure
        {
            result ~= value.toString();
        }
        else
        {
            import std.conv : to;
            result ~= value.to!string;
        }
        result ~= separator;
    }
    return result[0 .. $ - separator.length];
}

/++
Permutates all possible combinations of a random access range.
Skips duplicate pairs/triples/...
+/
CoupleEach!(num, Range) coupleEach(uint num = 2, Range)(Range range)
    if (isRandomAccessRange!Range)
{
    return CoupleEach!(num, Range)(range);
}

/// ditto
private struct CoupleEach(uint num, T)
{
    this(inout T range) inout
    {
        _range = range;
    }
    
    void popFront()
    {
        assert(!empty, "Tried to pop the front of an empty CoupleEach range");
        long a = num - 1;
        while (true)
        {
            _current[a]++;
            
            if (_current[a] > dim)
            {
                _current[a] = 0;
                a--;
                continue; // proceed to next (well, previous) dimension
            }
            
            CheckAgain:
            foreach (checkedDim; 0 .. a)
            {
                assert(a != checkedDim);
                if (_current[a] == _current[checkedDim])
                {
                    _current[a]++;
                    goto CheckAgain;
                }
            }
            
            break;
        }
    }
    
    @property inout(T)[num] front() inout
    {
        import std.algorithm.iteration : map;
        import std.array : array;
        assert(!empty, "Tried to access the front of an empty CoupleEach range");
        return _current[].map!((x) => _range[x]).array;
    }
    
    @property bool empty() const
    {
        foreach (dim; _current)
        {
            if (dim > num)
                return true;
        }
        return false;
    }
    
private:
    uint[num] _current;
    T _range;
}
