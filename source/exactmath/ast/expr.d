/++
This module contains `Expr` subclasses.
+/
module exactmath.ast.expr;

import exactmath.ast.base;

/++ TODO remove?
+/
@tag(Tag.dotExpr)
final class DotExpr : Expr
{
pure:
public:
    ///
    immutable Expr expr;
    
    ///
    immutable string id;
    
    this(immutable Expr expr, immutable string id)
    {
        super(Tag.dotExpr);
        this.expr = expr;
        this.id = id;
    }
    
    override bool equals(const Expr rhs) const
    {
        auto obj = rhs.downcast!DotExpr();
        return obj && .equals(expr, obj.expr) && id == obj.id;
    }
}

/++
+/
@tag(Tag.unknownExpr)
final class UnknownExpr : Expr
{
pure:
    ///
    immutable string name;
    
    this(immutable string name)
    {
        super(Tag.unknownExpr);
        this.name = name;
    }
    
    override bool equals(const Expr rhs) const
    {
        auto obj = rhs.downcast!UnknownExpr();
        return obj && name == obj.name;
    }
}

/++
+/
@tag(Tag.localExpr)
final class LocalExpr : Expr
{
pure:
    ///
    immutable string name;
    
    this(immutable string name)
    {
        super(Tag.localExpr);
        this.name = name;
    }
    
    override bool equals(const Expr rhs) const
    {
        auto obj = rhs.downcast!LocalExpr();
        return obj && name == obj.name;
    }
}

/++
+/
@tag(Tag.letExpr)
final class LetExpr : Expr
{
pure:
    ///
    immutable Equation equation;
    
    this(immutable Equation equation)
    {
        super(Tag.letExpr);
        this.equation = equation;
    }
    
    override bool equals(const Expr rhs) const
    {
        auto obj = rhs.downcast!LetExpr();
        return obj && .equals(equation, obj.equation);
    }
}

/++
+/
@tag(Tag.lambdaExpr)
final class LambdaExpr : Expr
{
pure:
    /// a -> b
    immutable Expr a;
    
    /// a -> b
    immutable Expr b;
    
    this(immutable Expr a, immutable Expr b)
    {
        super(Tag.lambdaExpr);
        this.a = a;
        this.b = b;
    }
    
    override bool equals(const Expr rhs) const
    {
        auto obj = rhs.downcast!LambdaExpr();
        return obj && .equals(a, obj.a) && .equals(b, obj.b);
    }
}

/++
+/
@tag(Tag.callExpr)
final class CallExpr : Expr
{
pure:
    ///
    immutable Expr func;
    
    ///
    immutable Expr arg;
    
    this(immutable Expr func, immutable Expr arg) immutable
    {
        super(Tag.callExpr);
        this.func = func;
        this.arg = arg;
    }
    this(immutable Expr func, immutable Expr arg)
    {
        super(Tag.callExpr);
        this.func = func;
        this.arg = arg;
    }
    
    /+this(immutable Expr arg, string name, uint argCount)
    {
        import std.conv : text;
        //assert(args.length == argCount, text(name, " function got ", args.length, "/", argCount, " arguments: ", args));
        this(args, name);
    }+/
    
    override bool equals(const Expr rhs) const
    {
        const obj = rhs.downcast!CallExpr();
        return obj && .equals(func, obj.func) && .equals(arg, obj.arg);
    }
}

/++
+/
@tag(Tag.unaryExpr)
abstract class UnaryExpr : Expr
{
pure:
    ///
    immutable Expr value;
    
    this(Tag tag, immutable Expr value)
    {
        super(tag);
        this.value = value;
    }
    
    final override bool equals(const Expr rhs) const
    {
        if (typeid(rhs) !is typeid(this)) // TODO use `typeid == typeid`
            return false;
        auto obj = cast(const(UnaryExpr)) rhs;
        return obj && .equals(obj.value, value);
    }
}

/++
+/
@tag(Tag.negExpr)
final class NegExpr : UnaryExpr
{
pure:
    this(immutable Expr value)
    {
        super(Tag.negExpr, value);
    }
}

/++
+/
@tag(Tag.lnExpr)
final class LnExpr : UnaryExpr
{
pure:
    ///
    alias arg = value;
    
    this(immutable Expr arg)
    {
        super(Tag.lnExpr, arg);
    }
}

/++
+/
@tag(Tag.sinExpr)
final class SinExpr : UnaryExpr
{
pure:
    ///
    alias arg = value;
    
    this(immutable Expr arg)
    {
        super(Tag.sinExpr, arg);
    }
}

/++
+/
@tag(Tag.cosExpr)
final class CosExpr : UnaryExpr
{
pure:
    ///
    alias arg = value;
    
    this(immutable Expr arg)
    {
        super(Tag.cosExpr, arg);
    }
}

/++
+/
@tag(Tag.tanExpr)
final class TanExpr : UnaryExpr
{
pure:
    ///
    alias arg = value;
    
    this(immutable Expr arg)
    {
        super(Tag.tanExpr, arg);
    }
}

/++
+/
@tag(Tag.accentExpr)
final class AccentExpr : UnaryExpr
{
pure:
    ///
    alias func = value;
    
    this(immutable Expr func)
    {
        super(Tag.accentExpr, func);
    }
}

/++
+/
@tag(Tag.binaryExpr)
abstract class BinaryExpr : Expr
{
pure:
    ///
    immutable Expr a;
    
    ///
    immutable Expr b;
    
    this(Tag tag, immutable Expr a, immutable Expr b)
    {
        super(tag);
        this.a = a;
        this.b = b;
    }
    
    final override bool equals(const Expr rhs) const
    {
        if (typeid(rhs) !is typeid(this)) // TODO use `typeid == typeid`
            return false;
        auto obj = cast(const(BinaryExpr)) rhs;
        return obj && .equals(obj.b, b) && .equals(obj.a, a);
    }
}

/++
Expresses `a` in terms of `b`.
+/
@tag(Tag.toExpr)
final class ToExpr : BinaryExpr
{
pure:
    this(immutable Expr a, immutable Expr b)
    {
        super(Tag.toExpr, a, b);
    }
}

/++
+/
@tag(Tag.addExpr)
final class AddExpr : BinaryExpr
{
pure:
    this(immutable Expr a, immutable Expr b)
    {
        super(Tag.addExpr, a, b);
    }
}

/++
+/
@tag(Tag.subExpr)
final class SubExpr : BinaryExpr
{
pure:
    this(immutable Expr a, immutable Expr b)
    {
        super(Tag.subExpr, a, b);
    }
}

/++
+/
@tag(Tag.mulExpr)
final class MulExpr : BinaryExpr
{
pure:
    this(immutable Expr a, immutable Expr b)
    {
        super(Tag.mulExpr, a, b);
    }
}

/++
+/
@tag(Tag.divExpr)
final class DivExpr : BinaryExpr
{
pure:
    this(immutable Expr a, immutable Expr b)
    {
        super(Tag.divExpr, a, b);
    }
}

/++ TODO support this better
+/
@tag(Tag.modExpr)
final class ModExpr : BinaryExpr
{
pure:
    this(immutable Expr a, immutable Expr b)
    {
        super(Tag.modExpr, a, b);
    }
}

/++
+/
@tag(Tag.powExpr)
final class PowExpr : BinaryExpr
{
pure:
    /// base ^ exponent
    alias base = a;
    
    /// base ^ exponent
    alias exponent = b;
    
    this(immutable Expr base, immutable Expr exponent)
    {
        super(Tag.powExpr, base, exponent);
    }
}

/++
+/
@tag(Tag.logExpr)
final class LogExpr : BinaryExpr
{
pure:
    /// log_base(arg)
    alias base = a;
    
    /// log_base(arg)
    alias arg = b;
    
    this(immutable Expr base, immutable Expr arg)
    {
        super(Tag.logExpr, base, arg);
    }
}

/++
+/
@tag(Tag.derivExpr)
final class DerivExpr : BinaryExpr
{
pure:
    /// d expr / d unknown
    alias expr = a;
    
    /// d expr / d unknown
    alias unknown = b;
    
    this(immutable Expr expr, immutable Expr unknown)
    {
        super(Tag.derivExpr, expr, unknown);
    }
}

/++ TODO support this better
+/
@tag(Tag.indexExpr)
final class IndexExpr : Expr
{
pure:
    /// indexed[index]
    immutable Expr indexed;
    alias expr = indexed;
    
    /// indexed[index]
    immutable Expr index;
    
    this(immutable Expr indexed, immutable Expr index)
    {
        super(Tag.indexExpr);
        this.indexed = indexed;
        this.index = index;
    }
    
    override bool equals(const Expr rhs) const
    {
        auto obj = rhs.downcast!IndexExpr();
        return obj && .equals(indexed, obj.indexed) && .equals(index, obj.index);
    }
}

/++
+/
@tag(Tag.tupleExpr)
final class TupleExpr : Expr
{
pure:
    ///
    immutable Expr[] values;
    
    this(immutable Expr[] values)
    {
        super(Tag.tupleExpr);
        this.values = values;
    }
    this(immutable Expr[] values) immutable // FSR this one is necessary...
    {
        super(Tag.tupleExpr);
        this.values = values;
    }
    
    override bool equals(const Expr rhs) const
    {
        auto tupleExpr = rhs.downcast!TupleExpr();
        if (tupleExpr is null)
            return false;
        if (tupleExpr.values.length != values.length)
            return false;
        
        foreach (a, value; values)
        {
            if (!.equals(value, tupleExpr.values[a]))
                return false;
        }
        return true;
    }
    
    ///
    static immutable TupleExpr unit;
    shared static this()
    {
        unit = new immutable TupleExpr([]);
    }
    
private:
    // ...
}

/++
+/
@tag(Tag.setExpr)
final class SetExpr : Expr
{
    /+
    static struct Element
    {
        union
        {
            
        }
        
        uint tag;
    }
    +/
    
    //Element[] elements;
    
    this()
    {
        super(Tag.setExpr);
    }
    
    static immutable SetExpr naturals;
    static immutable SetExpr fulls;
    static immutable SetExpr reals;
    
    shared static this()
    {
        //naturals = new immutable SetExpr; // {x | x >= 0 and x % 1 = 0}
        //fulls = new immutable SetExpr; // {x | x % 1 = 0}
        //reals = new immutable SetExpr; // {x | x = x}
    }
}

/++
Represents a single expression that contains no sub-expressions.
+/
@tag(Tag.singleExpr)
abstract class SingleExpr : Expr
{
pure:
    this(Tag tag)
    {
        super(tag);
    }
}

/++
+/
@tag(Tag.numExpr)
final class NumExpr : SingleExpr
{
pure:
    ///
    immutable Decimal value;
    
    this(immutable Decimal value)
    {
        super(Tag.numExpr);
        this.value = value;
    }
    
    ///
    alias minOne = literal!(-1.0);
    ///
    alias zero = literal!(0.0);
    ///
    alias one = literal!(1.0);
    ///
    alias two = literal!(2.0);
    
    /++
    +/
    template literal(double value)
    {
        static immutable NumExpr literal;
        shared static this()
        {
            literal = new immutable NumExpr(value);
        }
    }
    
    override bool equals(const Expr rhs) const
    {
        const obj = rhs.downcast!NumExpr();
        return obj && value == obj.value;
    }
}

/++
+/
@tag(Tag.intExpr)
final class IntExpr : SingleExpr
{
pure:
    ///
    immutable long value;
    
    this(immutable long value) immutable
    {
        super(Tag.intExpr);
        this.value = value;
    }
    
    ///
    alias minOne = literal!(-1);
    ///
    alias zero = literal!0;
    ///
    alias one = literal!1;
    ///
    alias two = literal!2;
    
    /++
    +/
    template literal(int value)
    {
        static immutable IntExpr literal;
        shared static this()
        {
            literal = new immutable IntExpr(value);
        }
    }
    
    override bool equals(const Expr rhs) const
    {
        auto obj = rhs.downcast!IntExpr();
        return obj && value == obj.value;
    }
}

/++
+/
@tag(Tag.unitExpr)
final class UnitExpr : SingleExpr
{
pure:
    ///
    immutable string name;
    
    ///
    static immutable UnitExpr second;
    
    /// ditto
    static immutable UnitExpr metre;
    
    /// ditto
    static immutable UnitExpr kilogram;
    
    /// ditto
    static immutable UnitExpr ampere;
    
    /// ditto
    static immutable UnitExpr kelvin;
    
    /// ditto
    static immutable UnitExpr mole;
    
    /// ditto
    static immutable UnitExpr candela;
    
    /// ditto
    static immutable UnitExpr radian;
    
    /// ditto
    static immutable UnitExpr steradian;
    
    override bool equals(const Expr rhs) const
    {
        return this is rhs; // constructor is private, so this is fine
    }
    
private:
    this(immutable string name) immutable
    {
        super(Tag.unitExpr);
        this.name = name;
    }
    
    shared static this()
    {
        metre = new immutable UnitExpr("metre");
        second = new immutable UnitExpr("second");
        kilogram = new immutable UnitExpr("kilogram");
        ampere = new immutable UnitExpr("ampere");
        candela = new immutable UnitExpr("candela");
        mole = new immutable UnitExpr("mole");
        kelvin = new immutable UnitExpr("kelvin");
        
        radian = new immutable UnitExpr("radian");
        steradian = new immutable UnitExpr("steradian");
    }
}

/++
+/
@tag(Tag.constant)
final class Constant : SingleExpr
{
pure:
    ///
    immutable Decimal approxValue;
    
    ///
    immutable string name;
    
    override bool equals(const Expr rhs) const
    {
        return this is rhs;
    }
    
    static immutable Constant pi;
    static immutable Constant e;
    //static immutable Constant i;
    
    shared static this()
    {
        pi = new immutable Constant(3.14159265358979323846264338327950288419716939937510, "c_pi");
        e = new immutable Constant(2.71828182845904523536028747135266249775724709369995, "c_e");
    }
    
private:
    this(immutable Decimal approxValue, immutable string name) immutable
    {
        super(Tag.constant);
        this.approxValue = approxValue;
        this.name = name;
    }
}

