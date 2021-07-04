/++
Attempts to constant-fold all literals and numbers to create a smaller
structure.

Usually, these functions are called from `simplify`, after numbers have been
brought together as much as possible.

This module is part of the exactmath rewriting functionality.
+/
module exactmath.ops.simplify.constfold;

/// Can fold simple arithmetic
pure unittest
{
    import exactmath.init : initMath;
    initMath();
    
    // 5 * 0 = 0
    auto expr1 = new immutable MulExpr(IntExpr.literal!5, IntExpr.zero);
    assert(.equals(expr1.constFold(), IntExpr.literal!0));
    
    // 5 + 0 = 5
    auto expr2 = new immutable AddExpr(IntExpr.literal!5, IntExpr.zero);
    assert(.equals(expr2.constFold(), IntExpr.literal!5));
}

/// Can fold fractions with numbers
pure unittest
{
    import exactmath.init : initMath;
    initMath();
    
    // 1 / 2 * 3 / 4 = 3 / 8
    auto expr = new immutable MulExpr(
        new immutable DivExpr(IntExpr.literal!1, IntExpr.literal!2),
        new immutable DivExpr(IntExpr.literal!3, IntExpr.literal!4),
    );
    auto cmp = new immutable DivExpr(
        IntExpr.literal!3, IntExpr.literal!8,
    );
    assert(.equals(expr.constFold(), cmp));
}

///
pure unittest
{
    import exactmath.init : initMath;
    initMath();
    
    auto arg = cast(immutable) new LocalExpr("arg");
    
    // ($arg -> $arg + 2)(5) = 7
    auto expr = cast(immutable) new CallExpr(
        cast(immutable) new LambdaExpr(
            arg,
            new immutable AddExpr(arg, IntExpr.two),
        ),
        IntExpr.literal!5,
    );
    assert(.equals(expr.constFold(), IntExpr.literal!7));
}

///
pure unittest
{
    import exactmath.init : initMath;
    initMath();
    
    auto x = cast(immutable) new UnknownExpr("x");
    auto expr = new immutable TupleExpr([ // -> (24, 0)
        new immutable MulExpr( // -> 24
            new immutable AddExpr( // -> 6
                new immutable LnExpr(Constant.e), // -> 1
                new immutable PowExpr( // -> 5
                    IntExpr.literal!5,
                    IntExpr.one,
                ),
            ),
            new immutable SubExpr( // -> 4
                new immutable DivExpr( // -> 5
                    NumExpr.literal!(5.0),
                    IntExpr.one,
                ),
                new immutable NegExpr( // -> 1
                    new immutable NegExpr(
                        new immutable PowExpr(
                            x,
                            NumExpr.zero,
                        ),
                    ),
                ),
            ),
        ),
        new immutable AddExpr( // -> 0
            IntExpr.zero,
            new immutable MulExpr( // -> 0
                new immutable MulExpr( // -> 0
                    x,
                    IntExpr.zero,
                ),
                IntExpr.one,
            ),
        ),
    ]);
    auto res = expr.constFold();
    auto cmp = new immutable TupleExpr([IntExpr.literal!24, IntExpr.zero]);
    import exactmath.ops.tostring : toFullString;
    assert(.equals(res, cmp), res.toFullString());
}

///
public import exactmath.ops.simplify.basicops;
///
public import exactmath.ops.simplify.calls;

import openmethods;
mixin(registerMethods);

import exactmath.ast;
import exactmath.ops.contains;
import exactmath.ops.match;

/++
Attemts to rewrite expressions to get as little literals and numbers as an end
result as possible.

Preconditions:
    `expr` must not be null
Postconditions:
    the result will not be null
+/
immutable(Expr) constFold(immutable Expr expr) pure
in (expr !is null)
out (result; result !is null)
{
    import exactmath.util : assumePure;
    
    return assumePure!impureConstFold(expr);
}

// TODO use a NumberCache for frequently occuring small numbers
// TODO don't allocate a new BinaryExpr if the arguments aren't changed!

private:

immutable(Expr) impureConstFold(immutable Expr expr)
{
    return fold(expr);
}
immutable(Expr) fold(virtual!(immutable(Expr)));

pure:

@method
immutable(Expr) _fold(immutable Expr expr)
{
    return expr;
}

@method
immutable(Expr) _fold(immutable UnknownExpr expr)
{
    return expr;
}

@method
immutable(Expr) _fold(immutable LambdaExpr expr)
{
    auto b = expr.b.constFold();
    
    // $x -> f($x) = f
    if (auto callExpr = expr.b.downcast!CallExpr())
    {
        if (.equals(expr.a, callExpr.arg))
            return callExpr.func;
    }
    
    if (b !is expr.b)
        return cast(immutable) new LambdaExpr(expr.a, b);
    return expr;
}

@method
immutable(Expr) _fold(immutable CallExpr expr)
{
    return callFolded(expr.func.constFold(), expr.arg.constFold());
}

@method
immutable(Expr) _fold(immutable NegExpr expr)
{
    return negFolded(expr.value.constFold());
}

@method
immutable(Expr) _fold(immutable LnExpr expr)
{
    auto x = expr.arg.constFold();
    
    if (x is Constant.e)
        return IntExpr.one;
    if (x is expr.arg)
        return expr;
    
    if (x is expr.arg)
        return expr;
    
    return new immutable LnExpr(x);
}

@method
immutable(Expr) _fold(immutable SinExpr expr)
{
    return expr;
}

@method
immutable(Expr) _fold(immutable CosExpr expr)
{
    return expr;
}

@method
immutable(Expr) _fold(immutable TanExpr expr)
{
    return expr;
}

@method
immutable(Expr) _fold(immutable AccentExpr expr)
{
    return accentFolded(expr.func);
}

@method
immutable(Expr) _fold(immutable AddExpr expr)
{
    return addFolded(expr.a.constFold(), expr.b.constFold());
}

@method
immutable(Expr) _fold(immutable SubExpr expr)
{
    return subFolded(expr.a.constFold(), expr.b.constFold());
}

// TODO x * 1 / y -> x / y

@method
immutable(Expr) _fold(immutable MulExpr expr)
{
    return mulFolded(expr.a.constFold(), expr.b.constFold());
}

@method
immutable(Expr) _fold(immutable DivExpr expr)
{
    return divFolded(expr.a.constFold(), expr.b.constFold());
}

@method
immutable(Expr) _fold(immutable ModExpr expr)
{
    return expr;
}

@method
immutable(Expr) _fold(immutable PowExpr expr)
{
    return powFolded(expr.a.constFold(), expr.b.constFold());
}

@method
immutable(Expr) _fold(immutable LogExpr expr)
{
    auto base = expr.base.constFold();
    auto arg = expr.arg.constFold();
    
    assert(base !is null);
    assert(arg !is null);
    
    // log(a)(a) = 1
    if (.equals(arg, base))
        return NumExpr.one;
    // log(e)(a) = ln(a)
    if (Constant.e.equals(base))
        return new immutable LnExpr(arg);
    
    if (base is expr.base && arg is expr.arg)
        return expr;
    return new immutable LogExpr(base, arg);
}

@method
immutable(Expr) _fold(immutable DerivExpr expr)
{
    return expr;
}

@method
immutable(Expr) _fold(immutable IndexExpr expr)
{
    auto indexed = expr.expr.constFold();
    auto index = expr.index.constFold();
    
    auto res = indexed.match!(
        (immutable TupleExpr indexed) => index.match!(
            (immutable NumExpr index) {
                import std.conv : to;
                if (index.value % 1 == 0)
                {
                    if (index.value >= indexed.values.length || index.value < 0)
                        throw new BoundsException("Tuple index out of bounds");
                    auto indexInt = cast(size_t) index.value;
                    assert(indexInt < indexed.values.length && indexInt >= 0);
                    return indexed.values[indexInt];
                }
                throw new BoundsException(
                    "Tuple index not an integer" /+ ~ index.value.to!string +/
                );
            },
            (immutable IntExpr index) {
                if (index.value >= indexed.values.length || index.value < 0)
                    throw new BoundsException("Tuple index out of bounds");
                return indexed.values[cast(size_t) index.value];
            },
            (immutable Expr index) => null,
        ),
        (immutable Expr indexed) => null,
    );
    if (res)
        return res;
    if (indexed is expr.expr && index is expr.index)
        return expr;
    return cast(immutable) new IndexExpr(indexed, index);
}

@method
immutable(Expr) _fold(immutable TupleExpr expr)
{
    import exactmath.util : eagerMap;
    
    return new immutable TupleExpr(
        expr.values.eagerMap!((value) => value.constFold())
    );
}

@method
immutable(Expr) _fold(immutable SetExpr expr)
{
    return expr;
}

@method
immutable(Expr) _fold(immutable SingleExpr expr)
{
    return expr;
}
