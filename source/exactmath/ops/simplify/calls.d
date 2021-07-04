/++


This module is part of the exactmath rewriting functionality.
+/
module exactmath.ops.simplify.calls;

import exactmath.ast;

/++
Creates a call expression, while attempting to constant-fold right away.
e.g. callFolded(($x) -> $x + 1, 5) = 5 + 1
+/
immutable(Expr) callFolded(immutable Expr func, immutable Expr arg) pure
{
    import exactmath.ops.substitute : substitute;
    
    // if func = ($y -> ...) then
    // ($y -> z)(x) = z.substitute($y, x)
    
    if (auto lambda = func.downcast!LambdaExpr())
    {
        if (auto local = lambda.a.downcast!LocalExpr())
            return lambda.b.substitute(local, arg);
    }
    return new immutable CallExpr(func, arg);
}

/++
Attempts to differentiate a function, or else creates a fresh new accent
expression from it.
+/
immutable(Expr) accentFolded(immutable Expr func) pure
{
    import exactmath.ops.derivative : derivative;
    
    // ($x -> y)' = $x -> __deriv(y, $x)
    if (auto lambda = func.downcast!LambdaExpr())
    {
        return cast(immutable) new LambdaExpr(
            lambda.a,
            lambda.b.derivative(lambda.a),
        );
    }
    return new immutable AccentExpr(func);
}

// TODO derivFolded
