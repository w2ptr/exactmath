/++
This module is for rewriting equations and expressions to bring occurences of
subexpressions closer together.

The function `gather` is usually called by `isolate`, which may require it as
a preparation to be able to isolate a needle from an expression.

For example:
```
ln(x) + ln(x) --> ln(x * x) = ln(x ^ 2)
```

For example:
```
a + 2 * x * 3 --> a + (2 * 3) * x
```

This module is part of the exactmath rewriting functionality.
+/
module exactmath.ops.gather;

///
pure unittest
{
    import exactmath.init : initMath;
    initMath();
    
    auto x = cast(immutable) new UnknownExpr("x");
    
    // ln(2 * x) + ln(x) = ln((2 * x) * x) doesn't work yet
    /+auto lnTest = new immutable AddExpr(
        new immutable LnExpr(
            new immutable MulExpr(
                x,
                IntExpr.two,
            ),
        ),
        new immutable LnExpr(x),
    );
    auto lnCmp = new immutable LnExpr(
        new immutable MulExpr(
            new immutable MulExpr(
                x,
                IntExpr.two,
            ),
            x
        ),
    );
    
    assert(.equals(lnTest.gather(x), lnCmp));+/
}

import openmethods;
mixin(registerMethods);

import exactmath.ast;
import exactmath.ops.contains;
import exactmath.ops.match;
import std.meta : AliasSeq;

/++
Will attempt to gather the occurences of an expression close together, to make
it easier to solve equations.

This function never throws; if the rewriting is unsufficient, the throwing is
up to the caller.

Params:
    expr = the expression that is manipulated
    needle = the expression of which the occurences must be gathered
Returns:
    an expression with `needle` gathered around as much as possible
+/
immutable(Expr) gather(immutable Expr expr, immutable Expr needle) pure
{
    import exactmath.util : assumePure;
    
    return assumePure!impureGather(expr, needle);
}

private:

immutable(Expr) impureGather(immutable Expr expr, immutable Expr needle)
{
    return gat(expr, needle);
}
immutable(Expr) gat(virtual!(immutable(Expr)), immutable Expr);

pure:

// Rewrite rules:
// log(b)(f(x)) + log(b)(g(x)) => log(a)(f(x) * g(x))
// ...

@method
immutable(Expr) _gat(immutable Expr expr, immutable Expr needle)
{
    return expr;
}

@method
immutable(Expr) _gat(immutable UnknownExpr expr, immutable Expr needle)
{
    return expr;
}

@method
immutable(Expr) _gat(immutable LambdaExpr expr, immutable Expr needle)
{
    return expr;
}

@method
immutable(Expr) _gat(immutable CallExpr expr, immutable Expr needle)
{
    return expr;
}

static foreach (T; AliasSeq!(NegExpr, LnExpr, SinExpr, CosExpr, TanExpr))
{
    @method
    immutable(Expr) _gat(immutable T expr, immutable Expr needle)
    {
        auto result = expr.value.gather(needle);
        
        if (result is expr.value)
            return expr;
        
        return new immutable T(result);
    }
}

/+
@method
immutable(Expr) _gat(immutable ToExpr expr, immutable Expr needle)
{
    //...
}
+/

@method
immutable(Expr) _gat(immutable AddExpr expr, immutable Expr needle)
{
    auto a = expr.a.gather(needle);
    auto b = expr.b.gather(needle);
    
    /+if (expr.a.contains(needle))
    {
        if (expr.b.contains(needle))
            return expr; // TODO
        else
            return expr; // TODO
    }
    else
    {
        if (expr.b.contains(needle))
            return expr; // TODO
        else
            return expr;
    }+/
    
    return new immutable AddExpr(a, b);
}

@method
immutable(Expr) _gat(immutable SubExpr expr, immutable Expr needle)
{
    return expr;
}

@method
immutable(Expr) _gat(immutable MulExpr expr, immutable Expr needle)
{
    return expr;
}

@method
immutable(Expr) _gat(immutable DivExpr expr, immutable Expr needle)
{
    return expr;
}

@method
immutable(Expr) _gat(immutable ModExpr expr, immutable Expr needle)
{
    return expr;
}

@method
immutable(Expr) _gat(immutable PowExpr expr, immutable Expr needle)
{
    return expr;
}

@method
immutable(Expr) _gat(immutable LogExpr expr, immutable Expr needle)
{
    return expr;
}

@method
immutable(Expr) _gat(immutable DerivExpr expr, immutable Expr needle)
{
    return expr;
}

@method
immutable(Expr) _gat(immutable IndexExpr expr, immutable Expr needle)
{
    return expr;
}

@method
immutable(Expr) _gat(immutable TupleExpr expr, immutable Expr needle)
{
    import exactmath.util : eagerMap;
    
    return new immutable TupleExpr(
        expr.values.eagerMap!((value) => value.gather(needle)),
    );
}

@method
immutable(Expr) _gat(immutable SetExpr expr, immutable Expr needle)
{
    return expr;
}

@method
immutable(Expr) _gat(immutable SingleExpr expr, immutable Expr needle)
{
    return expr;
}
