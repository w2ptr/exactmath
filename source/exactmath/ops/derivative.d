/++
This module contains a function that calculates the derivative of an
arbitrary expression.

Deprecation:
    This module is not generic enough and may return incorrect values on
    complex input. A more generic solution still has to be created.
+/
module exactmath.ops.derivative;

import exactmath.ast;
import exactmath.ops.simplify.basicops;

import openmethods;
mixin(registerMethods);

/++
[description]

Params:
    expr = the expression of which the derivative is calculated
    unknown = the unknown expression
Returns:
    the derivative of `expr` = d(expr) / d(unknown)
Preconditions:
    expr must not be null
    unknown must not be null
Postconditions:
    the result will not be null
+/
immutable(Expr) derivative(immutable Expr expr, immutable Expr unknown) pure
in (expr !is null)
in (unknown !is null)
out (result; result !is null)
{
    import exactmath.util : assumePure;
    
    if (.equals(expr, unknown))
        return IntExpr.one;
    
    // TODO FIXME openmethods won't properly work with pure functions!
    return (() @trusted => assumePure!impureDeriv(expr, unknown))();
}

private:

immutable(Expr) impureDeriv(immutable Expr expr, immutable Expr unknown)
{
    return deriv(expr, unknown);
}

immutable(Expr) deriv(virtual!(immutable(Expr)) expr, immutable Expr unknown);

/+-------------------------------------------------
implementations
-------------------------------------------------+/

pure:

@method
immutable(Expr) _deriv(immutable Expr expr, immutable Expr unknown)
{
    return new immutable DerivExpr(expr, unknown);
}

@method
immutable(Expr) _deriv(immutable UnknownExpr expr, immutable Expr unknown)
{
    return new immutable DerivExpr(expr, unknown);
}

@method
immutable(Expr) _deriv(immutable LocalExpr expr, immutable Expr unknown)
{
    return IntExpr.zero;
}

@method
immutable(Expr) _deriv(immutable CallExpr expr, immutable Expr unknown)
{
    // d/dx f(g(x)) = f'(g(x)) * d/dx (g(x))
    return mulFolded(
        new immutable CallExpr(
            new immutable AccentExpr(expr.func),
            expr.arg,
        ),
        expr.arg.derivative(unknown),
    );
}

@method
immutable(Expr) _deriv(immutable NegExpr expr, immutable Expr unknown)
{
    return negFolded(expr.value.derivative(unknown));
}

@method
immutable(Expr) _deriv(immutable LnExpr expr, immutable Expr unknown)
{
    // ln'(f(x)) = 1/f(x) * f'(x) = f'(x) / f(x)
    
    return divFolded(
        expr.arg.derivative(unknown),
        expr.arg,
    );
}

@method
immutable(Expr) _deriv(immutable SinExpr expr, immutable Expr unknown)
{
    // sin'(f(x)) = cos(x) * f'(x)
    
    return mulFolded(
        new immutable CosExpr(expr.arg),
        expr.arg.derivative(unknown),
    );
}

@method
immutable(Expr) _deriv(immutable CosExpr expr, immutable Expr unknown)
{
    // cos'(f(x)) = -sin(f(x)) * f'(x)
    
    return mulFolded(
        new immutable NegExpr(
            new immutable SinExpr(expr.arg),
        ),
        expr.arg.derivative(unknown),
    );
}

@method
immutable(Expr) _deriv(immutable TanExpr expr, immutable Expr unknown)
{
    // tan'(f(x)) = f'(x) / (cos(f(x))) ^ 2
    
    return divFolded(
        expr.arg.derivative(unknown),
        new immutable PowExpr(
            new immutable CosExpr(expr.arg),
            IntExpr.two,
        ),
    );
}

@method
immutable(Expr) _deriv(immutable AccentExpr expr, immutable Expr unknown)
{
    // TODO d/dx f' has no real meaning...? so throw `TypeException`?
    //return new immutable DerivExpr();
    throw new TypeException("Cannot do d/dx on a function");
}

@method
immutable(Expr) _deriv(immutable ToExpr expr, immutable Expr unknown)
{
    auto a = expr.a.derivative(unknown);
    
    return new immutable ToExpr(a, expr.b);
}

@method
immutable(Expr) _deriv(immutable AddExpr expr, immutable Expr unknown)
{
    // d/dx (f(x) + g(x)) = f'(x) + g'(x)
    return addFolded(
        expr.a.derivative(unknown),
        expr.b.derivative(unknown),
    );
}

@method
immutable(Expr) _deriv(immutable SubExpr expr, immutable Expr unknown)
{
    // d/dx (f(x) - g(x)) = f'(x) - g'(x)
    return subFolded(
        expr.a.derivative(unknown),
        expr.b.derivative(unknown),
    );
}

@method
immutable(Expr) _deriv(immutable MulExpr expr, immutable Expr unknown)
{
    // d/dx (f(x) * g(x)) = f'(x) * g(x) + f(x) * g'(x)
    return addFolded(
        mulFolded(expr.a.derivative(unknown), expr.b),
        mulFolded(expr.a, expr.b.derivative(unknown)),
    );
}

@method
immutable(Expr) _deriv(immutable DivExpr expr, immutable Expr unknown)
{
    // d/dx (f(x) / g(x)) = (f'(x) * g(x) - f(x) * g'(x)) / g(x) ^ 2
    
    return divFolded(
        subFolded(
            mulFolded(
                expr.a.derivative(unknown),
                expr.b,
            ),
            mulFolded(
                expr.a,
                expr.b.derivative(unknown),
            ),
        ),
        powFolded(
            expr.b,
            IntExpr.two,
        ),
    );
}

@method
immutable(Expr) _deriv(immutable PowExpr expr, immutable Expr unknown)
{
    // general rule:
    // d/dx (f(x) ^ g(x))
    // = (f(x) ^ g(x))
    //   * (
    //      g'(x) * ln(f(x))
    //      + g(x) * f'(x) / f(x)
    //     )
    
    if (auto numExponent = expr.exponent.downcast!IntExpr())
    {
        // shortcut for e.g. d/dx f(x)^4 = 4 * f(x)^3 * f'(x)
        // TODO the constant-folder should be able to handle this
        if (numExponent.value == 2)
        {
            return mulFolded(
                new immutable MulExpr(IntExpr.two, expr.base),
                expr.base.derivative(unknown),
            );
        }
        
        return mulFolded(
            new immutable MulExpr(
                numExponent,
                new immutable PowExpr(
                    expr.base,
                    new immutable IntExpr(numExponent.value - 1),
                ),
            ),
            expr.base.derivative(unknown),
        );
    }
    
    return mulFolded(
        expr,
        addFolded(
            mulFolded(
                expr.exponent.derivative(unknown),
                new immutable LnExpr(expr.base),
            ),
            mulFolded(
                expr.exponent,
                divFolded(
                    expr.base.derivative(unknown),
                    expr.base,
                ),
            ),
        ),
    );
}

@method
immutable(Expr) _deriv(immutable LogExpr expr, immutable Expr unknown)
{
    // d/dx log(b)(n) = d/dx (ln(n) / ln(b))
    // TODO do in one go
    
    return divFolded(
        new immutable LnExpr(expr.arg),
        new immutable LnExpr(expr.base),
    ).derivative(unknown);
}

@method
immutable(Expr) _deriv(immutable NumExpr expr, immutable Expr unknown)
{
    return IntExpr.zero;
}

@method
immutable(Expr) _deriv(immutable IntExpr expr, immutable Expr unknown)
{
    return IntExpr.zero;
}

@method
immutable(Expr) _deriv(immutable UnitExpr expr, immutable Expr unknown)
{
    // s(t) = t * 10 * meter
    // s'(t) = 1 * 10 meter / second + 0
    // v(t) = 10 * meter / second
    
    return IntExpr.zero;
}

@method
immutable(Expr) _deriv(immutable Constant expr, immutable Expr unknown)
{
    return IntExpr.zero;
}
