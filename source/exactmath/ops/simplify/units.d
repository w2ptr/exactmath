/++


This module is part of the exactmath rewriting functionality.
+/
module exactmath.ops.simplify.units;

///
pure unittest
{
    import exactmath.init : initMath;
    initMath();
    
    // (2 m * 4) ^ 3 - 4 m^3
    // (2*4 m)^3 - 4 m^3
    // 8^3 m^3 - 4 m^3
    // 512 m^3 - 4 m^3
    // 508 m^3
    auto cubicMeter = new immutable PowExpr(UnitExpr.metre, IntExpr.literal!3);
    auto expr = new immutable SubExpr(
        new immutable PowExpr(
            new immutable MulExpr(
                new immutable MulExpr(IntExpr.two, UnitExpr.metre),
                IntExpr.literal!4,
            ),
            IntExpr.literal!3,
        ),
        new immutable MulExpr(
            IntExpr.literal!4,
            cubicMeter,
        ),
    );
    auto cmp = new immutable MulExpr(
        IntExpr.literal!508,
        cubicMeter,
    );
    
    import exactmath.ops.tostring : toFullString;
    assert(.equals(expr.simplifyUnits(), cmp), expr.simplifyUnits().toFullString() ~ " vs " ~ cmp.toFullString());
}

import openmethods;
mixin(registerMethods);

import exactmath.ast;
import exactmath.ops.match;
import exactmath.ops.simplify.basicops;
import std.meta : AliasSeq;

/++
Simplifies the units of an expression.

All units will be collected and positioned as a coefficient;
e.g. `2 metre / 3 second` becomes `2/3 metre/second`

Params:
    expr = the expression that has to be simplified
Returns:
    a new expression if units were moved around, or `expr` itself it nothing
    changed
Preconditions:
    `expr` must not be null
Postconditions:
    the result will not be null
+/
immutable(Expr) simplifyUnits(immutable Expr expr) pure
in (expr !is null)
out (result; result !is null)
{
    return simplify(expr).toExpr();
}

/++
Simplifies the units of an equation.

Params:
    equation = the equation of which the sub-expressions must be simplified
Returns:
    a new equation if units could have been simplified, or `equation` itself if
    nothing changed
Preconditions:
    `expr` must not be null
Postconditions:
    the result will not be null
+/
immutable(Equation) simplifyUnits(immutable Equation equation) pure
in (equation !is null)
out (result; result !is null)
{
    import exactmath.util : assumePure;
    
    return assumePure!impureSimplifyEquation(equation);
}

private:

Result simplify(immutable Expr expr) pure
{
    import exactmath.util : assumePure;
    
    return assumePure!impureSimplify(expr);
}
Result impureSimplify(immutable Expr expr)
{
    return simp(expr);
}
Result simp(virtual!(immutable(Expr)));

immutable(Equation) impureSimplifyEquation(immutable Equation equation)
{
    return simpEq(equation);
}
immutable(Equation) simpEq(virtual!(immutable(Equation)));

pure:

// `simplifyUnits` collects all the units in an expression in the `Result`
// struct if possible and will turn this into a `MulExpr` at the end.

struct Result
{
    immutable Expr expr;
    Units units;
    
    immutable(Expr) toExpr() const pure
    {
        Expr result = cast() expr;
        static foreach (member; AliasSeq!("second", "metre", "kilogram", "ampere",
            "kelvin", "mole", "candela", "radian", "steradian"))
        {
            mixin("auto ", member, " = __traits(getMember, units, member);");
            if (mixin(member) == 1)
            {
                result = new MulExpr(
                    cast(immutable) result,
                    __traits(getMember, UnitExpr, member),
                );
            }
            else if (mixin(member) != 0)
            {
                result = new MulExpr(
                    cast(immutable) result,
                    new immutable PowExpr(
                        __traits(getMember, UnitExpr, member),
                        new immutable IntExpr(mixin(member)),
                    ),
                );
            }
        }
        return cast(immutable) result;
    }
}

struct Units
{
    Units invert() const pure
    {
        return Units(
            -second, -metre, -kilogram, -ampere, -kelvin, -mole, -candela,
            -radian, -steradian,
        );
    }
    
    Units multiply(const Units rhs) const pure
    {
        return Units(
            second + rhs.second, metre + rhs.metre, kilogram + rhs.kilogram,
            ampere + rhs.ampere, kelvin + rhs.kelvin, mole + rhs.mole,
            candela + rhs.candela, radian + rhs.radian,
            steradian + rhs.steradian,
        );
    }
    
    Units power(int value) const pure
    {
        return Units(
            second * value, metre * value, kilogram * value, ampere * value,
            kelvin * value, mole * value, candela * value, radian * value,
            steradian * value,
        );
    }
    
    // represent the exponent
    // e.g. kg * m * s^-2
    // ---> kg:1, m:1, s:-2
    int second = 0;
    int metre = 0;
    int kilogram = 0;
    int ampere = 0;
    int kelvin = 0;
    int mole = 0;
    int candela = 0;
    int radian = 0;
    int steradian = 0;
}

/+----------------
simplify implementations
----------------+/

@method
Result _simp(immutable Expr expr)
{
    return Result(expr, Units());
}

@method
Result _simp(immutable NegExpr expr)
{
    auto result = expr.value.simplify();
    if (result.expr is expr.value)
        return Result(expr, Units());
    return Result(negFolded(result.expr), result.units);
}

static foreach (T; AliasSeq!(LnExpr, SinExpr, CosExpr, TanExpr))
{
    @method
    Result _simp(immutable T expr)
    {
        auto result = expr.value.simplify();
        if (result.expr is expr.value)
            return Result(expr, Units());
        
        return Result(new immutable T(result.toExpr()), Units());
    }
}

@method
Result _simp(immutable AddExpr expr)
{
    auto a = expr.a.simplify();
    auto b = expr.b.simplify();
    
    if (a.expr is expr.a && b.expr is expr.b || // nothing changed
        a.units != b.units || // units don't match
        a.units == Units()) // no units, so shouldn't change
    {
        return Result(expr, Units());
    }
    
    return Result(addFolded(a.expr, b.expr), a.units);
}

@method
Result _simp(immutable SubExpr expr)
{
    auto a = expr.a.simplify();
    auto b = expr.b.simplify();
    
    if (a.expr is expr.a && b.expr is expr.b ||
        a.units != b.units ||
        a.units == Units())
    {
        return Result(expr, Units());
    }
    
    return Result(subFolded(a.expr, b.expr), a.units);
}

@method
Result _simp(immutable MulExpr expr)
{
    auto a = expr.a.simplify();
    auto b = expr.b.simplify();
    
    if (a.expr is expr.a && b.expr is expr.b)
        return Result(expr, Units());
    
    return Result(
        mulFolded(a.expr, b.expr),
        a.units.multiply(b.units),
    );
}

@method
Result _simp(immutable DivExpr expr)
{
    auto a = expr.a.simplify();
    auto b = expr.b.simplify();
    
    if (a.expr is expr.b && b.expr is expr.b)
        return Result(expr, Units());
    
    return Result(
        divFolded(a.expr, b.expr),
        a.units.multiply(b.units.invert()),
    );
}

@method
Result _simp(immutable PowExpr expr)
{
    auto base = expr.base.simplify();
    
    if (auto number = expr.exponent.downcast!IntExpr())
    {
        // TODO checked math?
        return Result(
            powFolded(base.expr, number),
            base.units.power(cast(int) number.value),
        );
    }
    
    return Result(expr, Units());
}

@method
Result _simp(immutable UnitExpr expr)
{
    if (expr is UnitExpr.second)
        return Result(IntExpr.one, Units(1, 0, 0, 0, 0, 0, 0, 0, 0));
    if (expr is UnitExpr.metre)
        return Result(IntExpr.one, Units(0, 1, 0, 0, 0, 0, 0, 0, 0));
    if (expr is UnitExpr.kilogram)
        return Result(IntExpr.one, Units(0, 0, 1, 0, 0, 0, 0, 0, 0));
    if (expr is UnitExpr.ampere)
        return Result(IntExpr.one, Units(0, 0, 0, 1, 0, 0, 0, 0, 0));
    if (expr is UnitExpr.kelvin)
        return Result(IntExpr.one, Units(0, 0, 0, 0, 1, 0, 0, 0, 0));
    if (expr is UnitExpr.mole)
        return Result(IntExpr.one, Units(0, 0, 0, 0, 0, 1, 0, 0, 0));
    if (expr is UnitExpr.candela)
        return Result(IntExpr.one, Units(0, 0, 0, 0, 0, 0, 1, 0, 0));
    if (expr is UnitExpr.radian)
        return Result(IntExpr.one, Units(0, 0, 0, 0, 0, 0, 0, 1, 0));
    if (expr is UnitExpr.steradian)
        return Result(IntExpr.one, Units(0, 0, 0, 0, 0, 0, 0, 0, 1));
    assert(false, "UnitExpr not a known unit: " ~ expr.name);
}

/+-----------------
simplifyEquation implementations
-----------------+/

@method
immutable(Equation) _simpEq(immutable Equation equation)
{
    return equation;
}

@method
immutable(Equation) _simpEq(immutable EqualEquation equation)
{
    return new immutable EqualEquation(
        equation.a.simplifyUnits(),
        equation.b.simplifyUnits(),
    );
}
