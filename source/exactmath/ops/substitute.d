/++
+/
module exactmath.ops.substitute;

///
pure unittest
{
    import exactmath.init : initMath;
    initMath();
    
    auto x = cast(immutable) new UnknownExpr("x");
    auto y = cast(immutable) new UnknownExpr("y");
    
    auto expr = new immutable AddExpr(
        x,
        new immutable NegExpr(x),
    );
    auto cmp = new immutable AddExpr(
        y,
        new immutable NegExpr(y),
    );
    assert(.equals(expr.substitute(x, y), cmp));
}

///
pure unittest
{
    import exactmath.init : initMath;
    initMath();
    
    auto x = cast(immutable) new UnknownExpr("x");
    auto arg0 = cast(immutable) new LocalExpr("arg0");
    auto lambda = cast(immutable) new LambdaExpr(
        arg0,
        new immutable MulExpr(IntExpr.two, x),
    );
    assert(.equals(
        lambda.substitute(x, IntExpr.two),
        cast(immutable) new LambdaExpr(arg0, IntExpr.literal!4),
    ));
}

import openmethods;
mixin(registerMethods);

import exactmath.ast;
import exactmath.ops.simplify.basicops;
import exactmath.ops.simplify.calls;
import std.meta : AliasSeq;

/++
+/
immutable(Expr) substitute(immutable Expr expr, immutable Expr needle, immutable Expr replacement) pure
{
    import exactmath.util : assumePure;
    
    if (.equals(expr, needle))
        return replacement;
    return assumePure!impureSubstitute(expr, needle, replacement);
}

private:

immutable(Expr) impureSubstitute(immutable Expr expr, immutable Expr needle, immutable Expr replacement)
{
    return subst(expr, needle, replacement);
}
immutable(Expr) subst(virtual!(immutable(Expr)), immutable Expr, immutable Expr);

@method
immutable(Expr) _subst(immutable Expr expr, immutable Expr needle, immutable Expr replacement)
{
    return expr;
}

@method
immutable(Expr) _subst(immutable UnknownExpr expr, immutable Expr needle, immutable Expr replacement)
{
    return expr;
}

@method
immutable(Expr) _subst(immutable LocalExpr expr, immutable Expr needle, immutable Expr replacement)
{
    return expr;
}

@method
immutable(Expr) _subst(immutable LetExpr expr, immutable Expr needle, immutable Expr replacement)
{
    assert(false, "TODO LetExpr#substitute");
}

@method
immutable(Expr) _subst(immutable LambdaExpr expr, immutable Expr needle, immutable Expr replacement)
{
    auto a = expr.a.substitute(needle, replacement);
    auto b = expr.b.substitute(needle, replacement);
    
    if (a is expr.a && b is expr.b)
        return expr;
    return cast(immutable) new LambdaExpr(a, b);
}

@method
immutable(Expr) _subst(immutable CallExpr expr, immutable Expr needle, immutable Expr replacement)
{
    auto func = expr.func.substitute(needle, replacement);
    auto arg = expr.arg.substitute(needle, replacement);
    
    if (func is expr.func && arg is expr.arg)
        return expr;
    return callFolded(func, arg);
}

static foreach (T; AliasSeq!(NegExpr, LnExpr, SinExpr, CosExpr, TanExpr,
    AccentExpr))
{
    @method
    immutable(Expr) _subst(immutable T expr, immutable Expr needle, immutable Expr replacement)
    {
        auto value = expr.value.substitute(needle, replacement);
        
        if (value is expr.value)
            return expr;
        return foldedOpFor!T(value);
    }
}

static foreach (T; AliasSeq!(ToExpr, AddExpr, SubExpr, MulExpr, DivExpr,
    ModExpr, PowExpr, LogExpr, DerivExpr))
{
    @method
    immutable(Expr) _subst(immutable T expr, immutable Expr needle, immutable Expr replacement)
    {
        auto a = expr.a.substitute(needle, replacement);
        auto b = expr.b.substitute(needle, replacement);
        
        if (a is expr.a && b is expr.b)
            return expr;
        return foldedOpFor!T(a, b);
    }
}

@method
immutable(Expr) _subst(immutable IndexExpr expr, immutable Expr needle, immutable Expr replacement)
{
    auto indexed = expr.indexed.substitute(needle, replacement);
    auto index = expr.index.substitute(needle, replacement);
    
    if (indexed is expr.indexed && index is expr.index)
        return expr;
    return cast(immutable) new IndexExpr(indexed, index);
}

@method
immutable(Expr) _subst(immutable TupleExpr expr, immutable Expr needle, immutable Expr replacement)
{
    import exactmath.util : eagerMap;
    return new immutable TupleExpr(
        expr.values.eagerMap!((value) => value.substitute(needle, replacement)),
    );
}

@method
immutable(Expr) _subst(immutable SetExpr expr, immutable Expr needle, immutable Expr replacement)
{
    return expr;
}

@method
immutable(Expr) _subst(immutable SingleExpr expr, immutable Expr needle, immutable Expr replacement)
{
    return expr;
}
