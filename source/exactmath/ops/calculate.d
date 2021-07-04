/++
This module contains functions for calculating an expression to only literals,
if possible.

The result can then be simplified to get the smallest value possible.

This module is part of the exactmath rewriting functionality.

The `solve` functions should generally not be used directly; to get a proper
solution for an expression, `calculate` should be used, since it will do the
necessary simplifications and it will select the best solution. Solving does
basically nothing else than searching through the provided state and rewriting
it to return some equation of the form `x = [...]` if x was the specified
needle, where [...] is some expression that is independent of x. For full
calculation of some expression, use `calculate`.

The result of `calculate` should always be true, so it is always perfectly safe
to add the result to your `BindingState`.

See_Also:
    exactmath.ops.simplify
+/

module exactmath.ops.calculate;

//debug = DebugCalc;

/// Calculating an unknown with a few indirections
pure unittest
{
    import exactmath.init : initMath;
    initMath();

    import exactmath.ops.simplify : simplify;

    auto x = cast(immutable) new UnknownExpr("x");
    auto a = cast(immutable) new UnknownExpr("a");
    auto b = cast(immutable) new UnknownExpr("b");
    
    auto mathState = basicState();
    // x = a + b and a = 2 and b = 5 --> x = 7
    mathState.enter(new immutable EqualEquation(x, new immutable AddExpr(a, b)));
    mathState.enter(new immutable EqualEquation(a, IntExpr.two));
    mathState.enter(new immutable EqualEquation(b, NumExpr.literal!(5.0)));
    
    auto res = x.calculate(mathState, (nextExpr) => true).simplify();
    auto cmp = new immutable EqualEquation(x, IntExpr.literal!7);
    assert(.equals(res, cmp));
}

/// Solving from multiple linear equations
pure unittest
{
    import exactmath.init : initMath;
    initMath();
    
    auto x = cast(immutable) new UnknownExpr("x");
    auto y = cast(immutable) new UnknownExpr("y");
    auto z = cast(immutable) new UnknownExpr("z");
    
    // x + y + z = 3
    // 2 x + 3 y + 4 z = 9
    // 3 x + 4 y + 2 z = 9
    // gives x = 1; y = 1; z = 1
    
    auto mathState = basicState();
    mathState.enter(new immutable EqualEquation(
        new immutable AddExpr(new immutable AddExpr(x, y), z),
        IntExpr.literal!3,
    ));
    mathState.enter(new immutable EqualEquation(
        new immutable AddExpr(
            new immutable AddExpr(
                new immutable MulExpr(IntExpr.literal!2, x),
                new immutable MulExpr(IntExpr.literal!3, y),
            ),
            new immutable MulExpr(IntExpr.literal!4, z),
        ),
        IntExpr.literal!9,
    ));
    mathState.enter(new immutable EqualEquation(
        new immutable AddExpr(
            new immutable AddExpr(
                new immutable MulExpr(IntExpr.literal!3, x),
                new immutable MulExpr(IntExpr.literal!4, y),
            ),
            new immutable MulExpr(IntExpr.literal!2, z),
        ),
        IntExpr.literal!9,
    ));
    
    auto xResult = x.calculate(mathState, (nextExpr) => true);
    auto yResult = y.calculate(mathState, (nextExpr) => true);
    auto zResult = z.calculate(mathState, (nextExpr) => true);
    
    import exactmath.ops.simplify : simplify;
    import exactmath.ops.tostring : toFullString;
    /*assert(.equals(
        xResult.simplify(),
        new immutable EqualEquation(x, IntExpr.literal!1),
    ), xResult.simplify().toFullString());
    assert(.equals(
        yResult.simplify(),
        new immutable EqualEquation(y, IntExpr.literal!1),
    ), yResult.simplify().toFullString());
    assert(.equals(
        zResult.simplify(),
        new immutable EqualEquation(z, IntExpr.literal!1),
    ), zResult.simplify().toFullString());*/
}
// TODO: the above test shouldn't required a call to simplify; this should be
// happening during calculation with *Folded ops

/// Test with units
pure unittest
{
    import exactmath.init : initMath;
    initMath();
    
    import exactmath.ops.simplify.units : simplifyUnits;
    
    auto n = cast(immutable) new UnknownExpr("n");
    auto m = cast(immutable) new UnknownExpr("m");
    auto M = cast(immutable) new UnknownExpr("M");
    
    // n = 20 mole
    // M = 10 kilogram/mole
    // n = m / M
    // m = ?
    auto mathState = basicState();
    mathState.enter(new immutable EqualEquation(
        n,
        new immutable MulExpr(IntExpr.literal!20, UnitExpr.mole),
    ));
    mathState.enter(new immutable EqualEquation(
        M,
        new immutable MulExpr(
            IntExpr.literal!10,
            new immutable DivExpr(UnitExpr.kilogram, UnitExpr.mole),
        ),
    ));
    mathState.enter(new immutable EqualEquation(
        n,
        new immutable DivExpr(m, M),
    ));
    
    auto result = m.calculate(mathState, (nextExpr) => true).simplifyUnits();
    auto cmp = new immutable EqualEquation(
        m,
        new immutable MulExpr(IntExpr.literal!200, UnitExpr.kilogram),
    );
    assert(.equals(result, cmp));
}

/// "to" expressions
pure unittest
{
    import exactmath.init : initMath;
    initMath();

    import exactmath.ops.simplify : simplifyFor;

    // V1 * c1 = V2 * c2
    // V1 = 10 litre
    // c1 = 20 mole/litre
    // c2 = 5 mole/litre
    // --> V2 - V1 to litre = 30 litre
    auto v1 = cast(immutable) new UnknownExpr("V1");
    auto v2 = cast(immutable) new UnknownExpr("V2");
    auto c1 = cast(immutable) new UnknownExpr("c1");
    auto c2 = cast(immutable) new UnknownExpr("c2");
    auto mole = cast(immutable) new UnknownExpr("mole");
    auto litre = cast(immutable) new UnknownExpr("litre");
    
    auto mathState = basicState();
    mathState.enter(new immutable EqualEquation(
        new immutable MulExpr(v1, c1),
        new immutable MulExpr(v2, c2),
    ));
    mathState.enter(new immutable EqualEquation(
        v1,
        new immutable MulExpr(IntExpr.literal!10, litre),
    ));
    mathState.enter(new immutable EqualEquation(
        c1,
        new immutable MulExpr(
            IntExpr.literal!20,
            new immutable DivExpr(mole, litre),
        ),
    ));
    mathState.enter(new immutable EqualEquation(
        c2,
        new immutable MulExpr(
            IntExpr.literal!5,
            new immutable DivExpr(mole, litre),
        ),
    ));
    
    auto calculated = new immutable ToExpr(
        new immutable SubExpr(v2, v1),
        litre,
    );
    auto result = calculated.calculate(mathState, (nextExpr) => true)
        .simplifyFor(calculated);
    // TODO would be best if it always evaluated to 30 litre, not litre * 30.
    auto cmp1 = new immutable EqualEquation(
        calculated,
        new immutable MulExpr(IntExpr.literal!30, litre),
    );
    auto cmp2 = new immutable EqualEquation(
        calculated,
        new immutable MulExpr(litre, IntExpr.literal!30),
    );
    assert(.equals(result, cmp1) || .equals(result, cmp2));
}

/// Calculating an expression that was already entered fully
pure unittest
{
    import exactmath.init : initMath;
    initMath();
    
    import exactmath.ops.simplify : simplifyFor;
    
    auto mass = cast(immutable) new UnknownExpr("mass");
    auto rock = cast(immutable) new UnknownExpr("rock");
    auto g_earth = cast(immutable) new UnknownExpr("g_earth");
    auto gravity = cast(immutable) new UnknownExpr("gravity");
    auto gram = cast(immutable) new UnknownExpr("gram");
    auto newton = cast(immutable) new UnknownExpr("newton");
    auto param = cast(immutable) new LocalExpr("x");
    
    // mass(rock) = 45 gram
    // g_earth = 10 m/s^2 (<-- approximated)
    // gravity($x) = mass($x) * g_earth
    // gravity(rock)
    // >> gravity(rock) to newton = 0.45 newton
    
    auto mathState = basicState();
    
    mathState.enter(new immutable EqualEquation(
        new immutable CallExpr(mass, rock),
        new immutable MulExpr(IntExpr.literal!45, gram),
    ));
    mathState.enter(new immutable EqualEquation(
        g_earth,
        new immutable MulExpr(
            IntExpr.literal!10,
            new immutable DivExpr(
                UnitExpr.metre,
                new immutable PowExpr(UnitExpr.second, IntExpr.two),
            ),
        ),
    ));
    mathState.enter(new immutable EqualEquation(
        new immutable CallExpr(gravity, param),
        new immutable MulExpr(
            new immutable CallExpr(mass, param),
            g_earth,
        ),
    ));
    
    auto value = new immutable ToExpr(
        new immutable CallExpr(gravity, rock),
        newton,
    );
    
    auto result = value.calculate(mathState, (nextExpr) => true)
        .simplifyFor(value);
    auto cmp = new immutable EqualEquation(
        value,
        new immutable MulExpr(
            new immutable DivExpr(IntExpr.literal!450, IntExpr.literal!1000),
            newton,
        ),
    );
    assert(.equals(result, cmp));
}

/// Calculating an expression that has some predefined properties with more
/// complex formulae
pure unittest
{
    import exactmath.init : initMath;
    initMath();
    
    import exactmath.ops.simplify : simplifyFor;
    
    auto mathState = basicState();
    
    // a(X) = 20 metre
    // 2 * b(X) = 60 metre
    // c(X) = 6
    // d($x) = a($x) + b($x) / c($x)
    // d(X)
    // >> d(X) = 25 metre
    
    auto a = cast(immutable) new UnknownExpr("a");
    auto b = cast(immutable) new UnknownExpr("b");
    auto c = cast(immutable) new UnknownExpr("c");
    auto d = cast(immutable) new UnknownExpr("d");
    auto obj = cast(immutable) new UnknownExpr("X");
    auto param = cast(immutable) new LocalExpr("x");
    
    mathState.enter(new immutable EqualEquation(
        new immutable CallExpr(a, obj),
        new immutable MulExpr(IntExpr.literal!20, UnitExpr.metre),
    ));
    mathState.enter(new immutable EqualEquation(
        new immutable CallExpr(b, obj),
        new immutable MulExpr(IntExpr.literal!30, UnitExpr.metre),
    ));
    mathState.enter(new immutable EqualEquation(
        new immutable CallExpr(c, obj),
        IntExpr.literal!6,
    ));
    mathState.enter(new immutable EqualEquation(
        new immutable CallExpr(d, param),
        new immutable AddExpr(
            new immutable CallExpr(a, param),
            new immutable DivExpr(
                new immutable CallExpr(b, param),
                new immutable CallExpr(c, param),
            ),
        ),
    ));
    
    auto value = new immutable CallExpr(d, obj);
    auto result = value.calculate(mathState, (nextExpr) => true)
        .simplifyFor(value);
    auto cmp = new immutable EqualEquation(
        value,
        new immutable MulExpr(IntExpr.literal!25, UnitExpr.metre),
    );
    assert(.equals(result, cmp));
}

import openmethods;
mixin(registerMethods);

import exactmath.ast;
import exactmath.ops.contains;
import exactmath.ops.isolate;
import exactmath.ops.match;
import exactmath.ops.simplify.constfold;
import exactmath.state;
import std.meta : AliasSeq;

// TODO don't create new objects if the results of subexpressions are unchanged.

/++
Type for testing if an expression should be calculated further;

takes an expression and should return a boolean representing that.
+/
alias ExprTester = bool delegate(immutable(Expr)) pure;

/++
Params:
    expr = the expression that is calculated
    state = opaque `BindingState` object
    proceed = the delegate that tests if an expression must be calculated further
Returns:
    an equation that represents the possible values of `expr` calculated into
    literals as far as possible
+/
immutable(Equation) calculate(immutable Expr expr, ref BindingState state, scope ExprTester proceed) pure
{
    auto actualState = State(&state, proceed);
    return calculate(expr, &actualState);
}

private:

/+
Keeps track of previous lookups in the binding state, to prevent infinite
recursion.
+/
struct State
{
pure:
package:
    this(BindingState* state, ExprTester proceed)
    {
        _stack = null;
        _state = state;
        _proceed = proceed;
    }
    
    @disable this(this);
    
    /+
    Marks an equation, to indicate that this equation has already been searched
    for the expression.
    
    Will register it if that association does not exist yet and then return
    false; will mutate nothing and return true otherwise.
    
    Params:
        equation = the equation that is associated
        expr = the expression that the equation is associated with
    +/
    bool guard(immutable Equation equation, immutable Expr expr)
    {
        import exactmath.ops.tostring : toFullString;
        import std.conv : text;
        foreach (frame; _stack)
        {
            if (.equals(frame.equation, equation) /+&& .equals(frame.expr, expr)+/)
            {
                debug (DebugCalc)
                    dbg(text(_stack.length, " ", equation.toFullString(), " has a guard for ", expr.toFullString()));
                return true;
            }
        }
        debug (DebugCalc)
            dbg(text(_stack.length, " ", equation.toFullString(), " has no guard for ", expr.toFullString()));
        
        _stack ~= Pair(equation /+, expr+/);
        return false;
    }
    
    /+
    +/
    void remove(immutable Equation equation)
    {
        import exactmath.ops.tostring : toFullString;
        debug (DebugCalc)
        {
            import std.conv : text;
            dbg(text(_stack.length, " removing ", equation.toFullString()));
        }
        
        foreach (a, ref frame; _stack)
        {
            if (frame.equation is equation)
            {
                _stack = _stack[0 .. a] ~ _stack[a + 1 .. $];
                return;
            }
        }
        assert(false, equation.toFullString() ~ " is not registered yet!");
    }
    
private:
    static struct Pair
    {
        immutable Equation equation;
        //immutable Expr expr;
    }
    
    // TODO use better data structure?
    Pair[] _stack;
    
    ExprTester _proceed;
    
    BindingState* _state;
}

/+
Variant that takes an already made `exactmath.ops.solve.State` object (for
internal use).
+/
immutable(Equation) calculate(immutable Expr expr, State* state) pure
{
    import exactmath.util : assumePure;
    
    debug (DebugCalc)
    {
        indentCounter++;
        scope (exit)
            indentCounter--;
    }
    
    // if the user-provided ExprTester does not want it to be calculated more,
    // then this is enough
    if (!state._proceed(expr))
        return new immutable EqualEquation(expr, expr);
    
    debug (DebugCalc)
    {
        import exactmath.ops.tostring : toFullString;
        dbg("Going to calculate " ~ expr.toFullString());
    }
    
    // otherwise, keep calculating!
    auto result = assumePure!impureCalculate(expr, state);
    debug (DebugCalc)
    {
        import exactmath.ops.tostring : toFullString;
        dbg("End result is " ~ result.toFullString());
    }
    return result;
}

immutable(Equation) impureCalculate(immutable Expr expr, State* state)
{
    return calc(expr, state);
}
immutable(Equation) calc(virtual!(immutable(Expr)), State*);

/+ STRATEGY FOR CALCULATING FROM MULTIPLE EQUATIONS
e.g.
w + x + y + z = 4;      {1}
6w + 2x + 3y + 4z = 12; {2}
2w + 6x + 2y + 3z = 24; {3}
3w + 6x + 2y + 4z = 48  {4}

express w in no other unknowns = calculate(w, [w]): {1}
  w = 4 - x - y - z
  
  express x in w = calculate(x, [w, x]): {2}
    x = (12 - 3y - 4z - 6w) / 2
    express y in (w, x) = calculate(y, [w, x, y]): {3}
      y = (24 - 2w - 6x - 3z) / 2
      express z in (w, x, y) = calculate(z, [w, x, y, z]): {4}
        z = (48 - 3w - 6x - 2y) / 4
      --> remove {4} registration
      y = (24 - 2w - 6x - 3 * (48 - 3w - 6x - 2y) / 4) / 2
        = (24 - 2w - 6x - 36 + 9/4 * w + 18/4 * x + 6/4 * y) / 2
        = 12 - w - 3x - 18 + 9/8 * w + 18/8 * x + 6/8 * y
      2/8 * y = 12 - w - 3x - 18 + 9/8 * w + 18/8 * x
      y = 48 - 4w - 12x - 72 + 9/36 * w + 18/36 * x
    --> remove {3} registration
    express z in (w, x) = calculate(z, [w, x, z]): {3}
      z = (24 - 2w - 6x - 2y) / 3
      express y in (w, x, z) = calculate(y, [w, x, z, y]): {4}
        y = (48 - 3w - 6x - 4z) / 2
      --> remove {4} registration
      z = 24 - 2w - 6x - 2 * (48 - 3w - 6x - 4z) / 2
        = 24 - 2w - 6x - 48 + 3w + 6x + 4z
      -3z = 24 - 2w - 6x - 48 + 3w + 6x
      z = -8 + 2/3 * w + 2x + 16 - w - 2x
    --> remove {3} registration
    x = 12 - 3 * (48 - 4w - 12x - 72 + 9/36 * w + 18/36 * x) - 4 * (-8 + 2/3 * w + 2x + 16 - w - 2x) - 6w
      = etc
  
  express y in w = calculate(y, [w, y]): {2}
    y = etc
  --> remove {2} registration
  
  express z in w = calculate(z, [w, z]): {2}
    z = etc
  --> remove {2} registration
  
  // now x, y and z are all expressed in only `w` and the following equation can
  // be solved:
  w = 4 - x - y - z
    = etc
--> remove {1} registration
+/

pure
{

/+
Check if there is an EqualEquation that already has the answer;
e.g. if the user entered m(b) = 2 and we're calculating m(b), then we shouldn't
calculate m and b separately, but directly return m(b) = 2.

Returns:
    an equation if found, `null` otherwise
+/
immutable(Equation) trySimpleSearch(immutable Expr expr, State* state)
{
    foreach (eq; state._state.equations)
    {
        // TODO make this a generic search function for `AndEquation`s
        // TODO make this find all results, not just the first one
        if (auto equalEq = eq.downcast!EqualEquation())
        {
            if (.equals(equalEq.a, expr))
            {
                if (state.guard(equalEq, expr))
                    continue;
                scope (exit)
                    state.remove(equalEq);
                return onSolveResult(expr, equalEq.b, state);
            }
            if (.equals(equalEq.b, expr))
            {
                if (state.guard(equalEq, expr))
                    continue;
                scope (exit)
                    state.remove(equalEq);
                return onSolveResult(expr, equalEq.a, state);
            }
        }
    }
    return null;
}

/+
Helper function that propagates the equation `eq` to the outer expression.
+/
immutable(Equation) propagate(
    immutable Expr expr,
    immutable Equation eq,
    scope immutable(Equation) delegate(immutable(Expr)) pure fn,
) {
    return eq.match!(
        (immutable EqualEquation eq) {
            // op(a) = op([a = x])
            // => op(a) = op(x)
            if (.equals(eq.a, expr))
                return fn(eq.b);
            if (.equals(eq.b, expr))
                return fn(eq.a);
            return NullEquation.instance;
        },
        (immutable NotEquation eq) {
            // op(a) = op([not eq])
            // => not propagate(op(a), eq)
            throw new ImplException("TODO");
        },
        (immutable OrEquation eq) {
            // op(a) = op([eqX or eqY])
            // => [propagate(op(a), eqX) or propagate(op(a), eqY)]
            immutable(Equation)[] result;
            foreach (subEq; eq.equations)
                result ~= propagate(expr, subEq, fn);
            return cast(immutable) new OrEquation(result);
        },
        (immutable AndEquation eq) {
            // op(a) = op([eqX; eqY])
            // => [propagate(op(a), eqX) and propagate(op(a), eqY)]
            immutable(Equation)[] result;
            foreach (subEq; eq.equations)
                result ~= propagate(expr, subEq, fn);
            return cast(immutable) new AndEquation(result);
        },
        (immutable NullEquation eq) {
            // op(a) = op([?])
            // => [?]
            assert(eq is NullEquation.instance, "NullEquation is not unique");
            return eq;
        },
        (immutable Equation eq) {
            assert(false, "Untested Equation subclass " ~ typeid(eq).name);
        },
    );
}

@method
immutable(Equation) _calc(immutable Expr expr, State* state)
{
    throw new ImplException("Cannot calculate " ~ typeid(expr).name);
}

/+
@method
immutable(Expr) _calc(immutable DotExpr expr, State* state)
{
    
}+/

@method
immutable(Equation) _calc(immutable UnknownExpr expr, State* state)
{
    return solveAll(expr, state);
}

@method
immutable(Equation) _calc(immutable LocalExpr expr, State* state)
{
    return NullEquation.instance;
}

@method
immutable(Equation) _calc(immutable LambdaExpr expr, State* state)
{
    // TODO other variables in expr.b could be substituted!
    // e.g.
    // a = 2; f = ($x) -> $x + a
    // --- calculate(f) ---
    // f = ($x) -> $x + 2
    return new immutable EqualEquation(expr, expr);
}

@method
immutable(Equation) _calc(immutable CallExpr expr, State* state)
{
    if (auto result = solveAll(expr, state))
    {
        if (result !is NullEquation.instance)
        {
            return propagate(
                expr,
                result,
                (valueExpr) => new immutable EqualEquation(
                    expr,
                    valueExpr,
                ),
            );
        }
    }
    
    auto func = expr.func.calculate(state);
    auto arg = expr.arg.calculate(state);
    
    auto result = propagate(
        expr.func,
        func,
        (valueFunc) => (arg is NullEquation.instance
            // e.g. f(x) where f = $x -> ... and x is still unknown -->
            // just substitute into lambda body and calculate ($x -> ...)(x)
            ? onSolveResult(expr, callFolded(valueFunc, expr.arg), state)
            // e.g. f(x) where f = $x -> ... and x = ... -->
            // f(x) = ...
            : propagate(
                expr.arg,
                arg,
                (valueArg) => new immutable EqualEquation(
                    expr,
                    callFolded(valueFunc, valueArg),
                ),
            )
        ),
    );
    return result;
}

static foreach (T; AliasSeq!(NegExpr, LnExpr, SinExpr, CosExpr, TanExpr))
{
    @method
    immutable(Equation) _calc(immutable T expr, State* state)
    {
        if (auto result = trySimpleSearch(expr, state))
            return result;
        
        auto x = expr.value.calculate(state);
        
        return propagate(
            expr.value,
            x,
            (value) => new immutable EqualEquation(expr, foldedOpFor!T(value)),
        );
    }
}

@method
immutable(Equation) _calc(immutable AccentExpr expr, State* state)
{
    if (auto result = trySimpleSearch(expr, state))
        return result;
    
    return propagate(
        expr.func,
        expr.func.calculate(state),
        (value) => new immutable EqualEquation(expr, accentFolded(value)),
    );
}

@method
immutable(Equation) _calc(immutable ToExpr expr, State* state)
{
    // a to b --> calculate(a / b) * b
    // e.g. 5 kilogram to gram
    // = 5 kilogram/(1/1000 kilogram) * gram
    // = 5000 gram
    auto div = new immutable DivExpr(expr.a, expr.b);
    auto a = div.calculate(state);
    
    return propagate(
        div,
        a,
        (valueA) => new immutable EqualEquation(
            expr,
            new immutable MulExpr(valueA, expr.b),
        ),
    );
}

static foreach (T; AliasSeq!(AddExpr, SubExpr, MulExpr, DivExpr, ModExpr,
    PowExpr, LogExpr, DerivExpr))
{
    @method
    immutable(Equation) _calc(immutable T expr, State* state)
    {
        if (auto result = trySimpleSearch(expr, state))
            return result;
        
        auto a = expr.a.calculate(state);
        auto b = expr.b.calculate(state);
        
        // e.g.
        // binOp(a, b) = binOp([a = 2 or a = 3], [b = 3])
        // => [binOp(a, b) = binOp(2, [b = 3])] or [binOp(a, b) = binOp(3, [b = 3])]
        // => [binOp(a, b) = binOp(2, 3)] or [binOp(a, b) = binOp(3, 3)]
        
        return propagate(
            expr.a,
            a,
            (valueA) => propagate(
                expr.b,
                b,
                (valueB) => new immutable EqualEquation(
                    expr,
                    foldedOpFor!T(valueA, valueB),
                ),
            ),
        );
    }
}

@method
immutable(Equation) _calc(immutable IndexExpr expr, State* state)
{
    if (auto result = trySimpleSearch(expr, state))
        return result;
    
    auto indexed = expr.indexed.calculate(state);
    auto index = expr.index.calculate(state);
    
    return propagate(
        expr.indexed,
        indexed,
        (valueExpr) => propagate(
            expr.index,
            index,
            (valueIndex) => new immutable EqualEquation(
                expr,
                cast(immutable) new IndexExpr(valueExpr, valueIndex),
            ),
        ),
    );
}

@method
immutable(Equation) _calc(immutable TupleExpr expr, State* state)
{
    import exactmath.util : eagerMap;
    
    if (auto result = trySimpleSearch(expr, state))
        return result;
    
    // (x, y, z) = ([x = 2], [y = 2 or y = 3], [z = 2])
    // => (x, y, z) = (2, 2, 2) or (x, y, z) = (2, 3, 2)
    immutable(Equation) recurse(
        immutable Expr[] doneValues,
        immutable Expr[] values,
        immutable Equation[] equations,
        State* state,
    ) {
        if (values.length == 0)
        {
            assert(equations.length == 0);
            return new immutable EqualEquation(expr, new immutable TupleExpr(doneValues));
        }
        return propagate(
            values[0],
            equations[0],
            (doneValue) => recurse(doneValues ~ doneValue, values[1 .. $], equations[1 .. $], state),
        );
    }
    
    return recurse([], expr.values, expr.values.eagerMap!((value) => value.calculate(state)), state);
}

// these cannot be calculated any further anyway:

@method
immutable(Equation) _calc(immutable NumExpr expr, State* state)
{
    return new immutable EqualEquation(expr, expr);
}

@method
immutable(Equation) _calc(immutable IntExpr expr, State* state)
{
    return new immutable EqualEquation(expr, expr);
}

@method
immutable(Equation) _calc(immutable UnitExpr expr, State* state)
{
    return new immutable EqualEquation(expr, expr);
}

@method
immutable(Equation) _calc(immutable Constant expr, State* state)
{
    return new immutable EqualEquation(expr, expr);
}

} // pure

//--- SOLVE ---//

public:

/++
Params:
    needle = the unknown that the solutions are being sought for
    state = opaque state object
Returns:
    an equation describing all the solutions for `needle` in `state`
+/
immutable(Equation) solveAll(immutable Expr needle, ref BindingState state, ExprTester tester) pure
{
    auto actualState = State(&state, tester);
    return solveAll(needle, &actualState);
}

/++
Same as the BindingState overload, but with an already made `State` that will
register already attempted associations, so that state can be kept around
between calls.

This function is mostly used internally by `calculate` and `solve`.
+/
immutable(Equation) solveAll(immutable Expr needle, State* state) pure
{
    debug (DebugCalc)
    {
        indentCounter++;
        scope (exit)
            indentCounter--;
    }
    
    immutable(Equation)[] result;
    foreach (equation; state._state.equations)
    {
        auto solutions = solveFrom(needle, equation, state);
        if (solutions !is NullEquation.instance)
            result ~= solutions;
    }
    
    if (result.length == 0)
        return NullEquation.instance;
    if (result.length == 1)
        return result[0];
    return cast(immutable) new AndEquation(result);
}

private:

/+
Will attempt to solve for a needle from a single equation.
+/
immutable(Equation) solveFrom(immutable Expr needle, immutable Equation equation, State* state) pure
{
    import exactmath.util : assumePure;
    
    return assumePure!impureSolve(needle, equation, state);
}

immutable(Equation) impureSolve(immutable Expr needle, immutable Equation equation, State* state)
{
    return solve(needle, equation, state);
}
immutable(Equation) solve(immutable Expr needle, virtual!(immutable(Equation)), State*);

/+
Params:
    needle = the expression which needs to be freed to `needle = [...]`
    other = the expression representing the intermediate result
    expr = the expression representing that contains the needle
    state = opaque state object
+/
immutable(Equation) solveEquality(immutable Expr needle, immutable Expr expr, immutable Expr other, State* state) pure
{
    import exactmath.util : assumePure;
    
    if (other.contains(needle))
        return NullEquation.instance;
    
    debug (DebugCalc)
    {
        import exactmath.ops.tostring : toFullString;
        dbg("Solving equality " ~ expr.toFullString() ~ " = " ~ other.toFullString());
    }
    
    if (!expr.contains(needle)) // `expr` doesn't contain needle
        return NullEquation.instance;
    
    if (!.equals(needle, expr)) // keep going
        return assumePure!impureSolveEq(needle, expr, other, state);
    
    // This means that the result (= `other`) is found.
    // e.g. when solving for x, the result is x = z.
    // Now we calculate the result of that further.
    // If it turns out that there is a circular dependency between multiple
    // unknowns, e.g. z = 2 * x - 1 => x = 2 * x - 1, then we solve this
    // equation too.
    return onSolveResult(needle, other, state);
}

// this function is also used when a direct result is found (see function
// trySimpleSearch()), which is why it's split off
immutable(Equation) onSolveResult(immutable Expr needle, immutable Expr other, State* state) pure
{
    auto oldTester = state._proceed;
    bool found = false;
    state._proceed = (expr) {
        if (.equals(needle, expr))
        {
            // `found` means the result is something like e.g.
            // x = 2 * x + 2 and that equation should be solved again
            found = true;
            return false;
        }
        return oldTester(expr);
    };
    scope (exit)
        state._proceed = oldTester;
    
    auto actualResult = propagate(
        other,
        other.calculate(state),
        (resultValue) => new immutable EqualEquation(needle, resultValue),
    );
    
    if (found)
    {
        // this means that the right-hand side contains the `needle`, so it
        // needs to be solved further
        auto oldTester2 = state._proceed; // is this switch even necessary?
        state._proceed = (nextExpr) => false;
        scope (exit)
            state._proceed = oldTester2;
        return solveFrom(needle, actualResult, state);
    }
    return actualResult;
}

immutable(Equation) impureSolveEq(immutable Expr needle, immutable Expr expr, immutable Expr other, State* state)
{
    return solveEq(needle, expr, other, state);
}
immutable(Equation) solveEq(immutable Expr, virtual!(immutable(Expr)), immutable Expr, State*);

/+--------------------------
implementations
--------------------------+/

pure:

//--- solve implementations ---//

@method
immutable(Equation) _solve(immutable Expr needle, immutable Equation equation, State* state)
{
    return NullEquation.instance;
    //throw new ImplException("Cannot yet solve arbitrary equations of a form different than x = y.");
}

@method
immutable(Equation) _solve(immutable Expr needle, immutable EqualEquation equation, State* state)
{
    if (equation.a.contains(needle)) // f(x) = ...
    {
        if (state.guard(equation, needle))
            return NullEquation.instance;
        scope (exit)
            state.remove(equation);
        
        if (equation.b.contains(needle)) // f(x) = g(x) => f(x) - g(x) = 0
        {
            return solveEquality(needle, new immutable SubExpr(equation.a, equation.b), IntExpr.zero, state);
        }
        else // f(x) = b
        {
            // e.g. 5 = 3 * x --> x = 5 / 3
            return solveEquality(needle, equation.a, equation.b, state);
        }
    }
    else
    {
        if (equation.b.contains(needle)) // a = g(x)
        {
            if (state.guard(equation, needle)) // guard for infinite recursion
                return NullEquation.instance;
            scope (exit)
                state.remove(equation);
            
            // e.g. 3 * x = 5 --> x = 5 / 3
            return solveEquality(needle, equation.b, equation.a, state);
        }
        else // doesn't contain it at all -> unsolvable
        {
            return NullEquation.instance;
        }
    }
    
    assert(false, "unreachable");
}

@method
immutable(Equation) _solve(immutable Expr needle, immutable OrEquation equation, State* state)
{
    throw new ImplException("Cannot solve from an 'or' equation yet");
}

@method
immutable(Equation) _solve(immutable Expr needle, immutable AndEquation equation, State* state)
{
    immutable(Equation)[] result;
    foreach (subEq; equation.equations)
    {
        auto solutions = solveFrom(needle, subEq, state);
        if (solutions !is NullEquation.instance)
            result ~= solutions;
    }
    
    if (result.length == 0)
        return NullEquation.instance;
    if (result.length == 1)
        return result[0];
    return cast(immutable) new AndEquation(result);
}

@method
immutable(Equation) _solve(immutable Expr needle, immutable NullEquation equation, State* state)
{
    assert(equation is NullEquation.instance, "NullEquation.instance is not unique");
    return equation;
}

//--- solveEquality implementations ---//

@method
immutable(Equation) _solveEq(immutable Expr needle, immutable Expr expr, immutable Expr other, State* state)
{
    assert(!other.contains(needle));
    import exactmath.ops.tostring : toFullString;
    throw new ImplException(
        "Cannot solve arbitrary expressions " ~ expr.toFullString() ~
        " and " ~ other.toFullString() ~
        " for " ~ needle.toFullString());
}

@method
immutable(Equation) _solveEq(immutable Expr needle, immutable LambdaExpr expr, immutable Expr other, State* state)
{
    // TODO LambdaExpr
    assert(false, "TODO solve LambdaExpr");
}

@method
immutable(Equation) _solveEq(immutable Expr needle, immutable CallExpr expr, immutable Expr other, State* state)
{
    if (expr.func.contains(needle))
    {
        if (expr.arg.contains(needle))
        {
            // "Cannot solve expression f(x)(g(x)) = y yet!";
            // (should be possible though)
            
            return NullEquation.instance;
        }
        else if (expr.arg.downcast!LocalExpr() !is null)
        {
            // x($y) = z --> x = $y -> z
            return solveEquality(needle, expr.func,
                cast(immutable) new LambdaExpr(expr.arg, other), state);
        }
        else
        {
            // x(y) = z with y not a LocalExpr --> not useful
            return NullEquation.instance;
        }
    }
    else
    {
        if (auto lambdaFunc = expr.func.downcast!LambdaExpr())
        {
            if (auto param = lambdaFunc.a.downcast!LocalExpr())
            {
                import exactmath.ops.substitute : substitute;
                return solveEquality(
                    needle,
                    lambdaFunc.b.substitute(param, expr.arg),
                    other,
                    state,
                );
            }
            return NullEquation.instance;
        }
        
        if (expr.arg.contains(needle))
        {
            // e.g. f(x) = y --> need to calculate f first, then solve the
            // result
            
            // e.g.
            //   f(x) = y
            //   and f = $x -> $x or f = $x -> -$x
            // gives ($x -> $x)(x) = y or ($x -> -$x)(x) = y
            auto c = expr.func.calculate(state);
            
            if (state.guard(c, expr.func))
                return NullEquation.instance;
            scope (exit)
                state.remove(c);
            
            auto resultEquation = propagate(
                expr.func,
                c,
                (value) => new immutable EqualEquation(
                    callFolded(value, expr.arg),
                    other,
                ),
            );
            return solveFrom(needle, resultEquation, state);
        }
        
        return NullEquation.instance;
    }
}

// TODO unary built-in functions (sin, cos, tan, ln)

@method
immutable(Equation) _solveEq(immutable Expr needle, immutable NegExpr expr, immutable Expr other, State* state)
{
    if (expr.value.contains(needle)) // -x = a --> x = -a
        return solveEquality(needle, expr.value, negFolded(other), state);
    else // not in there at all
        return NullEquation.instance;
}

@method
immutable(Equation) _solveEq(immutable Expr needle, immutable LnExpr expr, immutable Expr other, State* state)
{
    if (!expr.value.contains(needle))
        return NullEquation.instance;
    
    // ln(x) = b --> x = e ^ b
    return solveEquality(needle, expr.value, powFolded(Constant.e, other), state);
}

@method
immutable(Equation) _solveEq(immutable Expr needle, immutable AccentExpr expr, immutable Expr other, State* state)
{
    if (!expr.value.contains(needle))
        return NullEquation.instance;
    
    throw new ImplException("Cannot solve from AccentExpr");
}

@method
immutable(Equation) _solveEq(immutable Expr needle, immutable ToExpr expr, immutable Expr other, State* state)
{
    if (expr.a.contains(needle))
    {
        // f(x) to b = other
        // --> f(x) = other to 1/b
        return solveEquality(needle, expr.a, new immutable ToExpr(
            other,
            new immutable DivExpr(IntExpr.one, expr.b),
        ), state);
    }
    
    // a to f(x) = other
    // --> ?
    return NullEquation.instance;
}

@method
immutable(Equation) _solveEq(immutable Expr needle, immutable AddExpr expr, immutable Expr other, State* state)
{
    if (expr.a.contains(needle))
    {
        if (expr.b.contains(needle))
        {
            try
                return solveEquality(needle, expr.isolate(needle), other, state);
            catch (IsolateException e)
                return NullEquation.instance;
        }
        else // f(x) + b = a --> f(x) = a - b
            return solveEquality(needle, expr.a, subFolded(other, expr.b), state);
    }
    else
    {
        if (expr.b.contains(needle)) // b + f(x) = a --> f(x) = a - b
            return solveEquality(needle, expr.b, subFolded(other, expr.a), state);
        else // not in there at all
            return NullEquation.instance;
    }
}

@method
immutable(Equation) _solveEq(immutable Expr needle, immutable SubExpr expr, immutable Expr other, State* state)
{
    if (expr.a.contains(needle))
    {
        if (expr.b.contains(needle))
        {
            try
                return solveEquality(needle, expr.isolate(needle), other, state);
            catch (IsolateException e)
                return NullEquation.instance;
        }
        else // f(x) - b = a --> f(x) = a + b
            return solveEquality(needle, expr.a, addFolded(other, expr.b), state);
    }
    else
    {
        if (expr.b.contains(needle)) // b - f(x) = a --> f(x) = b - a
            return solveEquality(needle, expr.b, subFolded(expr.a, other), state);
        else // not in there at all
            return NullEquation.instance;
    }
}

@method
immutable(Equation) _solveEq(immutable Expr needle, immutable MulExpr expr, immutable Expr other, State* state)
{
    if (expr.a.contains(needle))
    {
        if (expr.b.contains(needle))
        {
            //if (IntExpr.zero.equals(other)) // a * b = 0 --> a = 0 or b = 0
            //    TODO
            try
                return solveEquality(needle, expr.isolate(needle), other, state);
            catch (IsolateException e)
                return NullEquation.instance;
        }
        else // f(x) * b = a --> f(x) = a / b
        {
            if (IntExpr.zero.equals(expr.b) || NumExpr.zero.equals(expr.b))
                return NullEquation.instance;
            return solveEquality(needle, expr.a, divFolded(other, expr.b), state);
        }
    }
    else
    {
        if (expr.b.contains(needle)) // b * f(x) = a --> f(x) = a / b
        {
            if (IntExpr.zero.equals(expr.a) || NumExpr.zero.equals(expr.a))
                return NullEquation.instance;
            return solveEquality(needle, expr.b, divFolded(other, expr.a), state);
        }
        else
            return NullEquation.instance;
    }
}

@method
immutable(Equation) _solveEq(immutable Expr needle, immutable DivExpr expr, immutable Expr other, State* state)
{
    if (expr.a.contains(needle))
    {
        if (expr.b.contains(needle))
            return NullEquation.instance;
            //throw new ImplException("Cannot yet solve f(x) / g(x) = a");
        else // f(x) / b = a --> f(x) = a * b AND b != 0 (TODO)
            return solveEquality(needle, expr.a, mulFolded(other, expr.b), state);
    }
    else
    {
        if (expr.b.contains(needle)) // b / f(x) = a --> f(x) = b / a AND f(x) != 0 (TODO)
            return solveEquality(needle, divFolded(expr.a, other), expr.b, state);
        else
            return NullEquation.instance;
    }
}

@method
immutable(Equation) _solveEq(immutable Expr needle, immutable PowExpr expr, immutable Expr other, State* state)
{
    if (expr.a.contains(needle))
    {
        if (expr.b.contains(needle))
            return NullEquation.instance;
            //throw new ImplException("Cannot yet solve f(x) ^ g(x) = a");
        else // f(x) ^ arg1 = other --> f(x) = other ^ (1/arg1)
        {
            if (auto integerExp = expr.exponent.downcast!IntExpr())
            {
                if (integerExp.value % 1 == 0) // even: f(x) ^ n = other --> f(x) = other ^ (1/n) or f(x) = -(other ^ (1/n))
                {
                    return cast(immutable) new OrEquation([
                        solveEquality(
                            needle,
                            expr.a,
                            powFolded(other, new immutable DivExpr(IntExpr.one, expr.b)),
                            state,
                        ),
                        solveEquality(
                            needle,
                            expr.a,
                            negFolded(powFolded(other, new immutable DivExpr(IntExpr.one, expr.b))),
                            state,
                        ),
                    ]);
                }
                else // uneven: f(x) ^ n = other --> f(x) = other ^ (1/n) (not considering complex numbers)
                {
                    return solveEquality(
                        needle,
                        expr.a,
                        powFolded(other, new immutable DivExpr(IntExpr.one, expr.b)),
                        state,
                    );
                }
            }
            throw new ImplException("Cannot yet solve equations of the form f(x) ^ a = b");
        }
    }
    else
    {
        if (expr.b.contains(needle)) // a ^ f(x) = other --> f(x) = log(a)(other)
            return solveEquality(needle, expr.exponent, new immutable LogExpr(expr.base, other), state); // TODO what if exponent = 0?
        else
            return NullEquation.instance;
    }
}

@method
immutable(Equation) _solveEq(immutable Expr needle, immutable LogExpr expr, immutable Expr other, State* state)
{
    if (expr.base.contains(needle))
    {
        if (expr.arg.contains(needle))
            return NullEquation.instance;
            //throw new ImplException("Cannot yet solve log(f(x))(g(x)) = a");
        else 
        {
            //     log(f(x))(b) = a
            // --> ln(b) / ln(f(x)) = a
            // --> ln(f(x)) = ln(b) / a
            // --> f(x) = e ^ (ln(b) / a) = e ^ (ln(b)) ^ (1/a) = b ^ (1/a)
            return solveEquality(
                needle,
                expr.base,
                // TODO what if b = 0?
                new immutable PowExpr(expr.arg, new immutable DivExpr(IntExpr.one, other)),
                state,
            );
        }
    }
    else
    {
        if (expr.arg.contains(needle)) // log(b)(f(x)) = a --> f(x) = b ^ a
            return solveEquality(needle, expr.arg, new immutable PowExpr(expr.base, other), state); // TODO what if b = 0?
        else
            return NullEquation.instance;
    }
}

immutable(Equation) _solveEq(immutable Expr needle, immutable IndexExpr expr, immutable Expr other, State* state)
{
    // a[x] = b cannot be solved
    // x[a] = b cannot be solved
    
    /+if (expr.index.contains(needle))
        throw new ImplException("Cannot solve equations of the form a[f(x)] = b");
    if (expr.indexed.contains(needle))
        throw new ImplException("Cannot solve equations of the form f(x)[a] = b");+/
    return NullEquation.instance;
}

immutable(Equation) _solveEq(immutable Expr needle, immutable TupleExpr expr, immutable Expr other, State* state)
{
    //immutable(Equation)[] result;
    foreach (a, value; expr.values)
    {
        if (value.contains(expr))
        {
            return solveEquality(
                needle,
                value,
                cast(immutable) new IndexExpr(other, new immutable IntExpr(a)),
                state);
        }
    }
    return NullEquation.instance;
    //return new immutable AndEquation(result);
}

// TODO DerivExpr

// TODO NumExpr, UnitExpr, Constant?
