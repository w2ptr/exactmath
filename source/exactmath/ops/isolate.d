/++
This module contains functions for rewriting expressions to reduce the amount
of occurences of a certain sub-expression.

This module is part of the exactmath rewriting functionality.
+/
module exactmath.ops.isolate;

// TODO: make `isolate` use *Folded

///
pure unittest
{
    import exactmath.init : initMath;
    import exactmath.ops.simplify : simplify;
    initMath();
    
    auto x = cast(immutable) new UnknownExpr("x");
    auto y = cast(immutable) new UnknownExpr("y");
    auto z = cast(immutable) new UnknownExpr("z");
    
    // (3 * x + y - x / 2) / z = ((5 / 2) * x + y) / z
    auto expr = new immutable DivExpr(
        new immutable SubExpr(
            new immutable AddExpr(
                new immutable MulExpr(IntExpr.literal!3, x),
                y,
            ),
            new immutable DivExpr(
                x,
                IntExpr.two,
            ),
        ),
        z,
    );
    auto result = expr.isolate(x);
    auto cmp = new immutable DivExpr(
        new immutable AddExpr(
            new immutable MulExpr(
                new immutable DivExpr(
                    IntExpr.literal!5,
                    IntExpr.literal!2,
                ),
                x,
            ),
            y,
        ),
        z,
    );
    assert(.equals(result.simplify(), cmp));
}

///
pure unittest
{
    import exactmath.init : initMath;
    import exactmath.ops.simplify : simplify;
    initMath();
    
    // x - (3 - (3 - x) / 2) / 2
    auto x = cast(immutable) new UnknownExpr("x");
    
    auto expr1 = new immutable SubExpr(
        x,
        new immutable DivExpr(
            new immutable SubExpr(
                IntExpr.literal!3,
                new immutable DivExpr(
                    new immutable SubExpr(IntExpr.literal!3, x),
                    IntExpr.two,
                ),
            ),
            IntExpr.two,
        ),
    );
    
    // x + (3 + x) / 2 = x + 3/2 - x/2 = 3/2 * x + 3/2
    auto expr = new immutable AddExpr(
        x,
        new immutable DivExpr(
            new immutable AddExpr(
                IntExpr.literal!3,
                x,
            ),
            IntExpr.two,
        ),
    );
    auto cmp = new immutable AddExpr(
        new immutable MulExpr(
            new immutable DivExpr(
                IntExpr.literal!3,
                IntExpr.two,
            ),
            x,
        ),
        new immutable DivExpr(IntExpr.literal!3, IntExpr.two),
    );
    import exactmath.ops.tostring : toFullString;
    /+DISABLED FOR NOW TODO: assert(
        .equals(expr.isolate(x).simplify(), cmp),
        expr.isolate(x).simplify().toFullString()
    );+/
}

/+ NOTE:
`isolate` itself will only isolate expressions if the expressions are already
close together. If this is not true yet, `gather` will be used to bring the
occurences closer.
+/

import openmethods;
mixin(registerMethods);

import exactmath.ast;
import exactmath.ops.contains;
import exactmath.ops.match;
import exactmath.ops.simplify.basicops;
import exactmath.ops.tostring : toFullString;
import std.meta : AliasSeq;

/++
+/
final class IsolateException : MathException
{
    import std.exception : basicExceptionCtors;
    
    ///
    mixin basicExceptionCtors;
}

/++
Will rewrite `expr` to a representation with only multiplications at the top
level, which is more usable for `solve`.

For example, "8 * x + y * x".isolate("x") = "(8 + y) * x".

For example, "5 * e^x + x * e^x".isolate("x") = "(5 + x) * e^x". TODO

For example, "8 * x^2 + y * x^2".isolate("x") = "(8 + y) * x^2". TODO

In most cases, `needle` should be an `UnknownExpr` or an `IDExpr`.

Params:
    expr = the expression that is gives as input and that is rewritten
    needle = the expression that needs to be isolated
Returns:
    a new expression with only one occurence of `needle`
Throws:
    `ImplException` if the expression cannot be rewritten properly
Preconditions:
    `expr` and `needle` must not be null
Postconditions:
    this is impossible, an exception will be thrown
+/
immutable(Expr) isolate(immutable Expr expr, immutable Expr needle) pure
in (expr !is null, "isolate `expr` is null")
in (needle !is null, "isolate `needle` is null")
out (result; result !is null, "isolate result is null")
{
    import exactmath.ops.gather : gather;
    import exactmath.ops.simplify : simplify;
    import exactmath.util : assumePure;
    
    return assumePure!impureIsolate(
        expr/+.simplify()+/.gather(needle)/+.simplify()+/,
        needle,
    );
}

private:

immutable(Expr) impureIsolate(immutable Expr expr, immutable Expr needle)
{
    return iso(expr, needle);
}
immutable(Expr) iso(virtual!(immutable(Expr)), immutable Expr);

pure:

@method
immutable(Expr) _iso(immutable Expr expr, immutable Expr needle)
{
    import exactmath.ops.tostring : toFullString;

    throw new IsolateException(
        expr.toFullString() ~
        " could not be rewritten to isolate " ~
        needle.toFullString()
    );
}

/+@method
immutable(Expr) _iso(immutable DotExpr expr, immutable Expr needle)
{
    
}+/

@method
immutable(Expr) _iso(immutable UnknownExpr expr, immutable Expr needle)
{
    return expr;
}

@method
immutable(Expr) _iso(immutable LambdaExpr expr, immutable Expr needle)
{
    return expr;
}

@method
immutable(Expr) _iso(immutable CallExpr expr, immutable Expr needle)
{
    // Can't do anything with that, right?
    return expr;
}

static foreach (T; AliasSeq!(NegExpr, LnExpr, SinExpr, CosExpr, TanExpr))
{
    @method
    immutable(Expr) _iso(immutable T expr, immutable Expr needle)
    {
        // e.g. unaryOp(x + 2 * x) = unaryOp(3 * x)
        auto res = expr.value.isolate(needle);
        if (res is expr.value)
            return expr;
        return foldedOpFor!T(res);
    }
}

@method
immutable(Expr) _iso(immutable ToExpr expr, immutable Expr needle)
{
    auto a = expr.a.isolate(needle);
    if (a is expr.a)
        return expr;
    return new immutable ToExpr(a, expr.b);
}

/+
Helper function for isolating in binary expressions.
+/
immutable(Expr) isolateBinary(alias fn, T : BinaryExpr)(immutable T expr, immutable Expr needle)
out (result; result !is null)
{
    auto a = expr.a.isolate(needle);
    auto b = expr.b.isolate(needle);
    
    if (a.contains(needle) && b.contains(needle))
    {
        import exactmath.ops.tostring : toFullString;
        
        auto result = fn(needle, a, b);
        if (result is null)
        {
            throw new IsolateException("Could not isolate " ~
                needle.toFullString() ~ " in " ~
                expr.toFullString());
        }
        return result;
    }
    return foldedOpFor!T(a, b);
}

struct CollectResult
{
pure:
    // Example: a + x + b * x = a + (1 + b) * x
    immutable Expr otherFactor; // 1 + b
    immutable Expr extra; // a
    
    void add(CollectResult rhs)
    {
        if (rhs.otherFactor is null)
        {
            cast() otherFactor = cast() rhs.otherFactor;
        }
        else
        {
            cast() otherFactor = cast() addFolded(
                otherFactor,
                rhs.otherFactor);
        }
        
        if (rhs.extra is null)
        {
            cast() extra = cast() rhs.extra;
        }
        else
        {
            cast() extra = cast() addFolded(
                extra,
                rhs.extra);
        }
    }
    
    void subtract(CollectResult rhs)
    {
        if (rhs.otherFactor is null)
        {
            cast() otherFactor = cast() negFolded(rhs.otherFactor);
        }
        else
        {
            cast() otherFactor = cast() subFolded(
                otherFactor,
                rhs.otherFactor);
        }
        
        if (rhs.extra is null)
        {
            cast() extra = cast() negFolded(rhs.extra);
        }
        else
        {
            cast() extra = cast() subFolded(
                extra,
                rhs.extra);
        }
    }
    
    void negate()
    {
        cast() otherFactor = cast() negFolded(otherFactor);
        cast() extra = cast() negFolded(extra);
    }
}

// TODO what about `x^2 + x^2 = 2 * x^2`?
// it should also isolate bigger expressions that only have one occurence of
// the needle!

/+
Will walk a sum to isolate a `needle`,
e.g. `a + x + b * x - c * x = a + (1 + b - c) * x`
+/
CollectResult collectFactor(immutable Expr needle, immutable Expr expr) pure
{
    if (.equals(expr, needle))
        return CollectResult(IntExpr.one, IntExpr.zero);
    
    // e.g. b * d * x + c * x = (b * d + c) * x
    return expr.match!(
        (immutable NegExpr expr) {
            if (.equals(expr.value, needle))
                return CollectResult(IntExpr.minOne, IntExpr.zero);
            auto result = collectFactor(needle, expr.value);
            result.negate();
            return result;
        },
        (immutable AddExpr expr) {
            auto result = collectFactor(needle, expr.a);
            result.add(collectFactor(needle, expr.b));
            return result;
        },
        (immutable SubExpr expr) {
            auto result = collectFactor(needle, expr.a);
            result.subtract(collectFactor(needle, expr.b));
            return result;
        },
        (immutable MulExpr expr) {
            auto aContains = expr.a.contains(needle);
            auto bContains = expr.b.contains(needle);
            if (aContains && !bContains) // (a * x) * b = (a*b) * x
            {
                auto result = collectFactor(needle, expr.a);
                cast() result.otherFactor = cast() mulFolded(result.otherFactor, expr.b);
                cast() result.extra = cast() mulFolded(result.extra, expr.b);
                return result;
            }
            if (!aContains && bContains) // a * (b * x) = (a*b) * x
            {
                auto result = collectFactor(needle, expr.b);
                cast() result.otherFactor = cast() mulFolded(result.otherFactor, expr.a);
                cast() result.extra = cast() mulFolded(result.extra, expr.a);
                return result;
            }
            if (aContains && bContains) // f(x) * g(x) = ?
            {
                // TODO more possibilities, e.g. (2 * x) * x = 2 * x^2
                throw new IsolateException(
                    "Cannot isolate " ~ needle.toFullString() ~
                    " from " ~ expr.toFullString());
            }
            return CollectResult(IntExpr.zero, expr);
        },
        (immutable DivExpr expr) {
            auto aContains = expr.a.contains(needle);
            auto bContains = expr.b.contains(needle);
            if (aContains && !bContains) // (a * x) / b = (a/b) * x
            {
                auto result = collectFactor(needle, expr.a);
                cast() result.otherFactor = cast() divFolded(result.otherFactor, expr.b);
                cast() result.extra = cast() divFolded(result.extra, expr.b);
                return result;
            }
            if (bContains) // a / (b * x) = ?
            {
                throw new IsolateException(
                    "Cannot isolate " ~ needle.toFullString() ~
                    " from " ~ expr.toFullString());
            }
            return CollectResult(IntExpr.zero, expr);
        },
        (immutable Expr expr) {
            if (expr.contains(needle))
            {
                throw new IsolateException(
                    "Cannot isolate " ~ needle.toFullString() ~
                    " from " ~ expr.toFullString());
            }
            return CollectResult(IntExpr.zero, expr);
        },
    );
}

pure unittest
{
    import exactmath.init : initMath;
    import exactmath.ops.simplify : simplify;
    initMath();
    
    auto x = cast(immutable) new UnknownExpr("x");
    auto y = cast(immutable) new UnknownExpr("y");
    
    // y * x / 2 + 6 * x + 5 = (y / 2 + 6) * x + 5
    auto result = collectFactor(
        x,
        new immutable AddExpr(
            new immutable AddExpr(
                new immutable MulExpr(
                    y,
                    new immutable DivExpr(
                        x,
                        IntExpr.two,
                    ),
                ),
                new immutable MulExpr(
                    IntExpr.literal!6,
                    x,
                ),
            ),
            IntExpr.literal!5,
        ),
    );
    assert(.equals(result.extra.simplify(), IntExpr.literal!5));
    assert(.equals(result.otherFactor.simplify(), new immutable AddExpr(
        new immutable MulExpr(
            new immutable DivExpr(IntExpr.one, IntExpr.two),
            y,
        ),
        IntExpr.literal!6,
    )));
}

@method
immutable(Expr) _iso(immutable AddExpr expr, immutable Expr needle)
{
    // x + x = 2 * x
    // a * x + x = (a + 1) * x
    // a * x + b * x = (a + b) * x
    // a * (x + b) + c * (d * x) = (a + c * d) * x + a * b
    // a * x^2 + b * x = a * (x + b / a / 2)^2 - b^2 / a / 4
    
    static immutable(Expr) isolateQuadratic(immutable Expr needle, immutable Expr a, immutable Expr b) pure
    {
        // a * x^2 + b * x
        // = a * (x^2 + b/a * x)
        // = a * ((x + b / a / 2) ^ 2 - b^2 / a^2 / 4)
        // = a * (x + b / a / 2)^2 - b^2 / a / 4
        // TODO
        return null;
    }
    
    static immutable(Expr) isolateAdd(immutable Expr needle, immutable Expr a, immutable Expr b) pure
    {
        // TODO remove unnecessary allocation?
        // a * f(x) + b * f(x) + c --> c + (a + b) * f(x)
        auto result = collectFactor(needle, new immutable AddExpr(a, b));
        return new immutable AddExpr(
            new immutable MulExpr(result.otherFactor, needle),
            result.extra,
        );
    }
    
    // x + x = 2 * x
    if (.equals(expr.a, needle) && .equals(expr.b, needle))
        return new immutable MulExpr(IntExpr.two, needle);
    
    return isolateBinary!isolateAdd(expr, needle);
}

@method
immutable(Expr) _iso(immutable SubExpr expr, immutable Expr needle)
{
    static immutable(Expr) isolateMin(immutable Expr needle, immutable Expr a, immutable Expr b)
    {
        auto result = collectFactor(needle, new immutable SubExpr(a, b));
        return new immutable AddExpr(
            new immutable MulExpr(result.otherFactor, needle),
            result.extra,
        );
    }
    
    if (.equals(expr.a, expr.b))
        return IntExpr.zero;
    
    return isolateBinary!isolateMin(expr, needle);
}

@method
immutable(Expr) _iso(immutable MulExpr expr, immutable Expr needle)
{
    static immutable(Expr) isolateMul(immutable Expr needle, immutable Expr a, immutable Expr b)
    {
        // x * x => x ^ 2
        // x ^ a * x => x ^ (a + 1)
        // x ^ a * x ^ b => x ^ (a + b)
        return null;
    }
    
    if (.equals(needle, expr.a) && .equals(needle, expr.b))
        return new immutable PowExpr(expr.a, IntExpr.two);
    
    return isolateBinary!isolateMul(expr, needle);
}

@method
immutable(Expr) _iso(immutable DivExpr expr, immutable Expr needle)
{
    static immutable(Expr) isolateDiv(immutable Expr needle, immutable Expr a, immutable Expr b)
    {
        // x / x => 1
        // x ^ a / x => x ^ (a - 1)
        // x / x ^ a => x ^ (1 - a)
        return null;
    }
    
    return isolateBinary!isolateDiv(expr, needle);
}

@method
immutable(Expr) _iso(immutable ModExpr expr, immutable Expr needle)
{
    static immutable(Expr) isolateMod(immutable Expr needle, immutable Expr a, immutable Expr b)
    {
        return null;
    }
    
    return isolateBinary!isolateMod(expr, needle);
}

@method
immutable(Expr) _iso(immutable PowExpr expr, immutable Expr needle)
{
    static immutable(Expr) isolatePow(immutable Expr needle, immutable Expr a, immutable Expr b)
    {
        return null;
    }
    
    return isolateBinary!isolatePow(expr, needle);
}

@method
immutable(Expr) _iso(immutable LogExpr expr, immutable Expr needle)
{
    throw new IsolateException("Unable to isolate things from `log`");
}

@method
immutable(Expr) _iso(immutable DerivExpr expr, immutable Expr needle)
{
    throw new IsolateException("Unable to isolate things from derivative");
}

@method
immutable(Expr) _iso(immutable IndexExpr expr, immutable Expr needle)
{
    throw new IsolateException("Unable to isolate things from index expressions");
}

@method
immutable(Expr) _iso(immutable TupleExpr expr, immutable Expr needle)
{
    immutable(Expr)[] result;
    result.reserve(expr.values.length);
    foreach (value; expr.values)
        result ~= value.isolate(needle);
    return new immutable TupleExpr(result);
}

@method
immutable(Expr) _iso(immutable SetExpr expr, immutable Expr needle)
{
    return expr;
}

@method
immutable(Expr) _iso(immutable NumExpr expr, immutable Expr needle)
{
    return expr;
}

@method
immutable(Expr) _iso(immutable IntExpr expr, immutable Expr needle)
{
    return expr;
}

@method
immutable(Expr) _iso(immutable UnitExpr expr, immutable Expr needle)
{
    return expr;
}

@method
immutable(Expr) _iso(immutable Constant expr, immutable Expr needle)
{
    return expr;
}
