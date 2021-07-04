/++
This module contains functions for approximating an arbitrary expression,
possibly losing precision.

This module is part of the exactmath rewriting functionality.
+/
module exactmath.ops.approximate;

///
pure unittest
{
    import exactmath.init : initMath;
    initMath();
    
    auto x = new immutable TupleExpr([
        new immutable SubExpr(
            new immutable PowExpr(
                NumExpr.literal!(2.0),
                new immutable DivExpr(
                    NumExpr.literal!(32.0),
                    NumExpr.literal!(2.0),
                ),
            ),
            NumExpr.one,
        ),
        Constant.pi
    ]);
    
    auto res = x.approximate();
    auto cmp = new immutable TupleExpr([
        NumExpr.literal!(65_535.0),
        new immutable NumExpr(Constant.pi.approxValue),
    ]);
    assert(.equals(res, cmp));
}

///
pure unittest
{
    import exactmath.init : initMath;
    import exactmath.ops.simplify.constfold : constFold;
    import std.math : approxEqual, log; // log is actually log(e) = ln
    initMath();
    
    auto arg = cast(immutable) new LocalExpr("arg");
    auto func = cast(immutable) new LambdaExpr(arg, new immutable LnExpr(arg));
    
    // ($arg -> ln($arg))(10) = ln(10)
    auto expr = new immutable CallExpr(
        func,
        IntExpr.literal!10,
    );
    
    auto result = cast(immutable(NumExpr)) expr.constFold().approximate();
    assert(result.value.approxEqual(log(10)));
}

import exactmath.ast;
import exactmath.ops.match;

import openmethods;
mixin(registerMethods);

/++
Will attempt to rewrite an expression so that as many expressions are changed
to numbers and function calls are executed.

It will not attempt to rewrite unknowns. For this purpose, use
`exactmath.ops.calculate` first, then call `approximate` on the resulting
equation.

Throws:
    `ImplException` if an expression cannot be approximated to one number
+/
immutable(Expr) approximate(immutable Expr expr) pure
{
    import exactmath.util : assumePure;
    
    return (() @trusted => assumePure!impureApproximate(expr))();
}

/++
Does the same as `approximate`, but does this by approximating both sides of an
equation.
+/
immutable(Equation) approximate(immutable Equation equation) pure
{
    import exactmath.util : assumePure;
    
    return (() @trusted => assumePure!impureApproximateEq(equation))();
}

/++
Does the same as `approximate`, but does this by approximating only one part
of an equation.

This is useful if you want to keep one side original, e.g.:
"2 * 5 = 2 * 5".approximateFor("2 * 5") gives "2 * 5 = 10"

Params:
    equation = the equation that is approximated
    expr = the expression that is compared to prevent
+/
immutable(Equation) approximateFor(immutable Equation equation, immutable Expr expr) pure
{
    import exactmath.util : assumePure;
    
    return assumePure!impureApproximateFor(equation, expr);
}

private:

immutable(Expr) impureApproximate(immutable Expr expr)
{
    return appr(expr);
}
immutable(Expr) appr(virtual!(immutable(Expr)));

immutable(Equation) impureApproximateEq(immutable Equation equation)
{
    return apprEq(equation);
}
immutable(Equation) apprEq(virtual!(immutable(Equation)));

immutable(Equation) impureApproximateFor(immutable Equation eq, immutable Expr expr)
{
    return apprFor(eq, expr);
}
immutable(Equation) apprFor(virtual!(immutable(Equation)), immutable(Expr));

/+-------------------------
implementations
-------------------------+/

pure:

@method
immutable(Expr) _appr(immutable Expr expr)
{
    return expr;
}

@method
immutable(Expr) _appr(immutable LambdaExpr expr)
{
    return expr; // TODO?
}

/+@method
immutable(Expr) _appr(immutable CallExpr expr)
{
    return expr; // TODO?
}+/

immutable(Expr) unaryMatcher(string err, alias fn, T : UnaryExpr)(immutable T expr)
{
    auto value = expr.value.approximate();
    
    return value.match!(
        (immutable NumExpr value) => cast(immutable(Expr)) new NumExpr(fn(value.value)),
        (immutable IntExpr value) => new immutable NumExpr(fn(value.value)),
        /+(immutable TupleExpr value) {
            throw new ImplException("TODO");
        },+/
        (immutable Expr value) =>
            value is expr.value
            ? expr
            : new immutable T(value),
    );
}

@method
immutable(Expr) _appr(immutable NegExpr expr)
{
    return unaryMatcher!("negative", (x) => -x, NegExpr)(expr);
    /+return expr.value.approximate().match!(
        (immutable NumExpr x) => cast(immutable(Expr)) new NumExpr(-x.value),
        (immutable IntExpr x) => new immutable IntExpr(-x.value),
        (immutable TupleExpr x) => new immutable NegExpr(x), // TODO propagate `-`
        (immutable Expr x) => new immutable NegExpr(x),
    );+/
}

// TODO use `unaryMatcher` for the following functions

@method
immutable(Expr) _appr(immutable LnExpr expr)
{
    import std.math : log2, LOG2E;
    
    // ln(x) = log(e)(x) = log(2)(x) / log(2)(e)
    return expr.arg.approximate().match!(
        (immutable NumExpr x) => cast(immutable(Expr)) new NumExpr(log2(x.value) / LOG2E),
        (immutable IntExpr x) => new NumExpr(log2(x.value) / LOG2E),
        (immutable TupleExpr x) {
            throw new TypeException("Cannot take `ln` of a tuple");
        },
        (immutable Expr x) =>
            x is expr.arg
            ? expr
            : new immutable LnExpr(x),
    );
}

@method
immutable(Expr) _appr(immutable SinExpr expr)
{
    import core.math : sin;
    
    return expr.arg.approximate().match!(
        (immutable NumExpr x) => cast(immutable(Expr)) new NumExpr(sin(x.value)),
        (immutable IntExpr x) => new immutable NumExpr(sin(cast(real) x.value)),
        (immutable TupleExpr x) {
            throw new TypeException("Cannot take sine of a tuple");
        },
        (immutable Expr x) => new immutable SinExpr(x),
    );
}

@method
immutable(Expr) _appr(immutable CosExpr expr)
{
    import core.math : cos;
    
    return expr.arg.approximate().match!(
        (immutable NumExpr x) => cast(immutable(Expr)) new immutable NumExpr(cos(x.value)),
        (immutable TupleExpr x) {
            throw new TypeException("Cannot take cosine of a tuple");
        },
        (immutable Expr x) => new immutable CosExpr(x),
    );
}

@method
immutable(Expr) _appr(immutable TanExpr expr)
{
    import std.math : tan;
    
    return expr.arg.approximate().match!(
        (immutable NumExpr x) => cast(immutable(Expr)) new immutable NumExpr(tan(x.value)),
        (immutable TupleExpr x) {
            throw new TypeException("Cannot take tangens of a tuple");
        },
        (immutable Expr x) => new immutable TanExpr(x),
    );
}

immutable(Expr) binaryMatcher(string err, alias fn, T : BinaryExpr)(immutable Expr exprA, immutable Expr exprB)
{
    auto a = exprA.approximate();
    auto b = exprB.approximate();
    
    return a.match!(
        (immutable NumExpr a) => cast(immutable(Expr)) b.match!(
            (immutable NumExpr b) => cast(immutable(Expr)) new NumExpr(fn(a.value, b.value)),
            (immutable IntExpr b) => new immutable NumExpr(fn(a.value, b.value)),
            (immutable Expr b) => new immutable T(a, b),
        ),
        (immutable IntExpr a) => b.match!(
            (immutable NumExpr b) => cast(immutable(Expr)) new NumExpr(fn(a.value, b.value)),
            (immutable IntExpr b) => new immutable NumExpr(fn(a.value, b.value)),
            (immutable Expr b) => new immutable T(a, b),
        ),
        // op(tuple(x1, x2), tuple(y1, y2)) = tuple(op(x1, y1), op(x2, y2))
        (immutable TupleExpr a) => b.match!(
            (immutable TupleExpr b) {
                if (a.values.length != b.values.length)
                    throw new TypeException("Cannot take the " ~ err ~ " of two tuples of different lengths");
                immutable(Expr)[] result;
                foreach (i, value; a.values)
                    result ~= binaryMatcher!(err, fn, T)(value, b.values[i]);
                return cast(immutable(Expr)) new immutable TupleExpr(result);
            },
            (immutable Expr b) => new immutable T(a, b),
        ),
        (immutable Expr a) => new immutable T(a, b),
    );
}

@method
immutable(Expr) _appr(immutable ToExpr expr)
{
    auto a = expr.a.approximate();
    
    if (a is expr.a)
        return expr;
    return new immutable ToExpr(a, expr.b);
}

@method
immutable(Expr) _appr(immutable AddExpr expr)
{
    return binaryMatcher!("sum", (x, y) => x + y, AddExpr)(expr.a, expr.b);
}

@method
immutable(Expr) _appr(immutable SubExpr expr)
{
    return binaryMatcher!("difference", (x, y) => x - y, SubExpr)(expr.a, expr.b);
}

@method
immutable(Expr) _appr(immutable MulExpr expr)
{
    return binaryMatcher!("product", (x, y) => x * y, MulExpr)(expr.a, expr.b);
}

@method
immutable(Expr) _appr(immutable DivExpr expr)
{
    return binaryMatcher!("quotient", (x, y) => cast(Decimal) x / y, DivExpr)(expr.a, expr.b);
}

@method
immutable(Expr) _appr(immutable PowExpr expr)
{
    return binaryMatcher!("power", (x, y) => x ^^ y, PowExpr)(expr.a, expr.b);
}


@method
immutable(Expr) _appr(immutable LogExpr expr)
{
    import std.math : log2;
    
    return binaryMatcher!("logarithm", (x, y) => log2(x) / log2(y), LogExpr)(expr.a, expr.b);
}

@method
immutable(Expr) _appr(immutable TupleExpr expr)
{
    import exactmath.util : eagerMap;
    
    return new immutable TupleExpr(
        expr.values.eagerMap!((value) => value.approximate())
    );
}

/+@method
immutable(Expr) _appr(immutable NumExpr expr)
{
    return expr;
}

@method
immutable(Expr) _appr(immutable UnitExpr expr)
{
    return expr;
}+/

@method
immutable(Expr) _appr(immutable Constant expr)
{
    // TODO this could be cached globally on `Constant`
    return new immutable NumExpr(expr.approxValue);
}

// equations

@method
immutable(Equation) _apprEq(immutable Equation eq)
{
    return eq;
}

@method
immutable(Equation) _apprEq(immutable EqualEquation eq)
{
    auto a = eq.a.approximate();
    auto b = eq.b.approximate();
    
    if (a is eq.a && b is eq.b)
        return eq;
    
    return new immutable EqualEquation(a, b);
}

@method
immutable(Equation) _apprFor(immutable Equation eq, immutable Expr expr)
{
    return eq;
}

@method
immutable(Equation) _apprFor(immutable EqualEquation eq, immutable Expr expr)
{
    if (.equals(eq.a, expr))
        return new immutable EqualEquation(eq.a, eq.b.approximate());
    if (.equals(eq.b, expr))
        return new immutable EqualEquation(eq.a.approximate(), eq.b);
    
    return new immutable EqualEquation(
        eq.a.approximate(),
        eq.b.approximate(),
    );
}
