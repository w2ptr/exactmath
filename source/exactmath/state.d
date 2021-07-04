/++
+/
module exactmath.state;

import exactmath.ast;

/++
+/
struct BindingState
{
pure:
    ///
    BindingState* parent;
    
    ///
    immutable(Equation)[] equations;
    
    ///
    immutable(Type)[] types;
    
    //
    //immutable(Category)[] categories;
    
    ///
    NumberCache numberCache;
    
    /++
    +/
    void enter(immutable Equation expr)
    {
        equations ~= expr;
    }
    
private:
    // TODO `calculate` cache
}

/++
+/
BindingState basicState() pure
{
    static arg0 = cast(immutable) new LocalExpr("arg0");
    static arg1 = cast(immutable) new LocalExpr("arg1");
    
    // helper functions
    static immutable(Equation) unaryFunc(T : Expr)(string name)
    {
        auto key = cast(immutable) new UnknownExpr(name);
        auto value = cast(immutable) new LambdaExpr(
            arg0,
            new immutable T(arg0),
        );
        return cast(immutable) new EqualEquation(key, value);
    }
    
    static immutable(Equation) binaryFunc(T : Expr)(string name)
    {
        auto key = cast(immutable) new UnknownExpr(name);
        auto value = cast(immutable) new LambdaExpr(
            arg0,
            cast(immutable) new LambdaExpr(
                arg1,
                cast(immutable) new T(arg0, arg1),
            ),
        );
        return cast(immutable) new EqualEquation(key, value);
    }
    
    static immutable(Equation) pair(string name, immutable Expr value)
    {
        auto key = cast(immutable) new UnknownExpr(name);
        return cast(immutable) new EqualEquation(key, value);
    }
    
    // to limit allocation if possible
    auto secpowmin2 = new immutable PowExpr(
        UnitExpr.second,
        IntExpr.literal!(-2),
    );
    auto secpowmin3 = new immutable PowExpr(
        UnitExpr.second,
        IntExpr.literal!(-3),
    );
    auto kgm2 = new immutable MulExpr(
        UnitExpr.kilogram,
        new immutable PowExpr(UnitExpr.metre, IntExpr.literal!2),
    );
    
    return BindingState(null, [ // equations
        // built-in functions
        binaryFunc!AddExpr("add"),
        binaryFunc!SubExpr("sub"),
        binaryFunc!MulExpr("mul"),
        binaryFunc!DivExpr("div"),
        binaryFunc!ModExpr("mod"),
        binaryFunc!PowExpr("pow"),
        binaryFunc!LogExpr("log"),
        binaryFunc!DerivExpr("deriv"),
        unaryFunc!NegExpr("neg"),
        unaryFunc!LnExpr("ln"),
        unaryFunc!SinExpr("sin"),
        unaryFunc!CosExpr("cos"),
        unaryFunc!TanExpr("tan"),
        
        // basic units
        pair("second", UnitExpr.second),
        pair("metre", UnitExpr.metre),
        pair("kilogram", UnitExpr.kilogram),
        pair("ampere", UnitExpr.ampere),
        pair("kelvin", UnitExpr.kelvin),
        pair("mole", UnitExpr.mole),
        pair("candela", UnitExpr.candela),
        pair("radian", UnitExpr.radian),
        pair("steradian", UnitExpr.steradian),
        
        // derived units
        pair("coulomb", new immutable MulExpr(UnitExpr.ampere, UnitExpr.second)),
        pair("farad", new immutable MulExpr( // F = kg m^2 s^4 A^2
            kgm2,
            new immutable MulExpr(
                new immutable PowExpr(UnitExpr.second, IntExpr.literal!(-4)),
                new immutable PowExpr(UnitExpr.ampere, IntExpr.two),
            ),
        )),
        pair("gram", new immutable DivExpr(UnitExpr.kilogram, IntExpr.literal!1000)),
        pair("hertz", new immutable DivExpr(IntExpr.one, UnitExpr.second)),
        pair("joule", new immutable MulExpr( // J = kg m^2 s^-2
            kgm2,
            secpowmin2,
        )),
        pair("litre", new immutable DivExpr( // kL = m^3 so L = m^3 / 1000
            new immutable PowExpr(UnitExpr.metre, IntExpr.literal!3),
            IntExpr.literal!1000,
        )),
        pair("newton", new immutable MulExpr( // N = kg m s^-2
            new immutable MulExpr(UnitExpr.kilogram, UnitExpr.metre),
            secpowmin2,
        )),
        pair("ohm", new immutable MulExpr( // Ω = kg m^2 s^-3 A^-2
            kgm2,
            new immutable MulExpr(
                secpowmin3,
                new immutable PowExpr(UnitExpr.ampere, IntExpr.literal!(-2)),
            ),
        )),
        pair("pascal", new immutable MulExpr( // Pa = kg m^-1 s^-2
            new immutable MulExpr(
                UnitExpr.kilogram,
                new immutable PowExpr(UnitExpr.metre, IntExpr.minOne)
            ),
            secpowmin2,
        )),
        pair("volt", new immutable MulExpr( // V = kg m^2 s^-3 A^-1
            kgm2,
            new immutable MulExpr(
                secpowmin3,
                new immutable PowExpr(UnitExpr.ampere, IntExpr.minOne),
            ),
        )),
        pair("watt", new immutable MulExpr( // W = kg m^2 s^-3
            kgm2,
            secpowmin3,
        )),
        
        // constants
        pair("c_pi", Constant.pi),
        pair("c_e", Constant.e),
    ], [
        // types
    ]);
}

/++
+/
struct NumberCache
{
    // TODO
}
