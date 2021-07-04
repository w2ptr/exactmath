/++
Rewrites an expression so that the result is more human-readable and workable.

`simplify` is very unopiniated and will only attempt to rewrite expressions if
the result has not lost any information. It is basically `constFold` and
`simplifyUnits` in a single function.

This module is part of the exactmath rewriting functionality.
+/
module exactmath.ops.simplify.simplify;

import exactmath.ast;
import exactmath.ops.match;

import openmethods;
mixin(registerMethods);

// TODO don't recreate objects if unnecessary
// e.g. new immutable Something(a.simplify(), b.simplify())
// -> if (simplifiedA !is a || simplifiedB !is b) return ^that;
//    else return original;

/++
Simplifies an expression so it is more human-readable, without losing
information and not by rewriting in a way that could change the outcome of
other algorithms.

Never throws or fails. If the expression cannot be simplified more, it will be
returned directly.

Params:
    expr = the expression that is simplified
Returns:
    A simplified, more human-readable version of `expr`
Preconditions:
    `expr` must not be null
Postconditions:
    result will not be null
+/
immutable(Expr) simplify(immutable Expr expr) pure
in (expr !is null)
out (result; result !is null)
{
    import exactmath.ops.simplify.constfold : constFold;
    import exactmath.ops.simplify.units : simplifyUnits;
    
    return expr.constFold().simplifyUnits();
}

/// ditto
immutable(Equation) simplify(immutable Equation equation) pure
{
    return equation.match!(
        (immutable EqualEquation eq) {
            return cast(immutable(Equation)) new immutable EqualEquation(
                eq.a.simplify(),
                eq.b.simplify(),
            );
        },
        (immutable NotEquation eq) =>
            cast(immutable) new NotEquation(eq.equation.simplify()),
        (immutable Equation eq) => eq,
    );
}

/++
Will simplify one or both sides of an equation, only if it is different from
the input expression; useful after having called `calculate`, when you want to
preserve the original input.

Params:
    equation = the equation that is simplified
    expr = the expression that is preserved
+/
immutable(Equation) simplifyFor(immutable Equation equation, immutable Expr expr) pure
{
    return equation.match!(
        (immutable EqualEquation eq) {
            if (.equals(eq.a, expr))
            {
                return cast(immutable(Equation)) new EqualEquation(
                    eq.a,
                    eq.b.simplify(),
                );
            }
            if (.equals(eq.b, expr))
            {
                return new immutable EqualEquation(
                    eq.b,
                    eq.a.simplify(),
                );
            }
            
            return new immutable EqualEquation(
                eq.a.simplify(),
                eq.b.simplify(),
            );
        },
        (immutable NotEquation eq) =>
            cast(immutable) new NotEquation(eq.equation.simplifyFor(expr)),
        (immutable Equation eq) => eq,
    );
}
