/++
+/
module exactmath.ops.contains;

import openmethods;
mixin(registerMethods);

import exactmath.ast;

/++
Params:
    haystack = the expression that is searched in
    needle = the expression that is searched for
Returns:
    whether `haystack` contains `needle`
+/
bool contains(const Expr haystack, const Expr needle) pure
{
    return haystack.occurences(needle) > 0; // TODO could be more lazy
}

/++
Params:
    haystack = the expression that is searched in
    needle = the expression that is searched for
Returns:
    the number of occurences of `needle` in `haystack`
+/
uint occurences(const Expr haystack, const Expr needle) pure
{
    import exactmath.util : assumePure;
    
    return .equals(haystack, needle)
        ? 1
        : assumePure!impureOccurences(haystack, needle);
}

///
unittest
{
    updateMethods();
    
    auto y = cast(immutable) new UnknownExpr("y");
    auto x = new immutable LogExpr(
        new immutable PowExpr(IntExpr.one, IntExpr.two),
        new immutable DivExpr(IntExpr.two, y),
    );
    
    assert(x.occurences(y) == 1);
    assert(x.occurences(IntExpr.two) == 2);
    assert(x.b.occurences(IntExpr.two) == 1);
    assert(!x.contains(cast(immutable) new UnknownExpr("z")));
    
    auto tuple = new immutable TupleExpr([IntExpr.one, IntExpr.two]);
    assert(!tuple.contains(y));
}

private:

uint impureOccurences(const Expr haystack, const Expr needle)
{
    return occ(haystack, needle);
}

uint occ(virtual!(const(Expr)), const Expr);

pure:

/+ TODO stop supporting this -> move to TypeEquation
@method
uint _occ(const TypeExpr haystack, const Expr needle)
{
    return haystack.expr.contains(needle);
}+/

@method
uint _occ(const DotExpr haystack, const Expr needle)
{
    return haystack.expr.occurences(needle);
}

@method
uint _occ(const UnknownExpr haystack, const Expr needle)
{
    return 0;
}

@method
uint _occ(const LocalExpr haystack, const Expr needle)
{
    return 0;
}

@method
uint _occ(const LambdaExpr haystack, const Expr needle)
{
    return haystack.a.occurences(needle) + haystack.b.occurences(needle);
}

@method
uint _occ(const CallExpr haystack, const Expr needle)
{
    return haystack.func.occurences(needle) + haystack.arg.occurences(needle);
}

@method
uint _occ(const UnaryExpr expr, const Expr needle)
{
    return expr.value.occurences(needle);
}

@method
uint _occ(const BinaryExpr expr, const Expr needle)
{
    return expr.a.occurences(needle) + expr.b.occurences(needle);
}

@method
uint _occ(const IndexExpr expr, const Expr needle)
{
    return expr.indexed.occurences(needle) + expr.index.occurences(needle);
}

@method
uint _occ(const TupleExpr haystack, const Expr needle)
{
    uint result = 0;
    foreach (value; haystack.values)
        result += value.occurences(needle);
    return result;
}

@method
uint _occ(const SetExpr haystack, const Expr needle)
{
    return 0;
}

@method
uint _occ(const SingleExpr haystack, const Expr needle)
{
    return 0;
}
