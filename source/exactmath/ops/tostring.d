/++
This module contains functions for converting an expression to a valid and
human-readable string.
+/
module exactmath.ops.tostring;

/// Basic operations are supported and operator precedence is applied.
pure unittest
{
    import exactmath.init : initMath;
    initMath();
    
    auto expr = new immutable TupleExpr([
        new immutable AddExpr(
            new immutable PowExpr(
                NumExpr.one,
                IntExpr.two,
            ),
            new immutable NegExpr(
                IntExpr.literal!3,
            ),
        ),
        new immutable MulExpr(
            new immutable AddExpr(
                NumExpr.literal!(4.0),
                IntExpr.literal!5,
            ),
            new immutable PowExpr(
                IntExpr.literal!6,
                IntExpr.literal!7,
            ),
        ),
    ]);
    
    assert(expr.toFullString() == "(1 ^ 2 + -3, (4 + 5) * 6 ^ 7)");
}

/// Expressions and equations are written down as readably as possible.
pure unittest
{
    import exactmath.init : initMath;
    initMath();
    
    auto x = cast(immutable) new UnknownExpr("x");
    auto y = cast(immutable) new UnknownExpr("y");
    
    auto expr = new immutable EqualEquation(
        new immutable AddExpr(
            new immutable MulExpr(
                IntExpr.literal!2,
                x,
            ),
            new immutable MulExpr(
                IntExpr.literal!3,
                y,
            ),
        ),
        IntExpr.literal!5,
    );
    
    assert(expr.toFullString() == "2 x + 3 y = 5");
}

import exactmath.ast;
import exactmath.parser : OpLevel;
import std.range.primitives : isOutputRange;

import openmethods;
mixin(registerMethods);

/++


Preconditions:
    `node` must not be null
+/
string toFullString(const Node node) pure
in (node !is null)
{
    import std.array : appender;
    auto result = appender!string();
    
    void sink(string s) pure
    {
        result.put(s);
    }
    
    toStringSink(node, &sink);
    return result.data;
}

/++


Preconditions:
    `node`  must not be null
+/
void toStringRange(T)(const Node node, T sink)
if (isOutputRange!T)
in (node !is null)
{
    return toStringSink(node, &sink.put);
}

/++
Outputs a user-friendly string representation of a node.

Never throws or fails, unless `sink` throws.

Params:
    T = the delegate type (can be both pure and impure)
    node = the node that is stringified
    sink = the delegate the parts of the string are sent to
Preconditions:
    `node` must not be null
+/
void toStringSink(T)(const Node node, scope T sink, OpLevel level = OpLevel.comma)
if (__traits(compiles, T.init("")))
in (node !is null)
{
    import exactmath.util : assumePure;
    
    if (false) // so `pure` inference works properly for impure delegates
        sink("");
    
    // FIXME no assumePure - pure doesn't properly work with openmethods
    return assumePure!impureToString(node, sink, level);
}

private:

void impureToString(const Node node, scope void delegate(string) sink, OpLevel level)
{
    if (node is null)
        sink("[[BUG: null]]");
    else
        str(node, sink, level);
}
void str(virtual!(const(Node)), scope void delegate(string), OpLevel);

/+--------------------------
implementations
--------------------------+/

@method
void _str(const Node node, scope void delegate(string) sink, OpLevel level)
{
    sink("[[Bug: stringification unimplemented for ");
    sink(typeid(node).name);
    sink("]]");
}

// expressions

@method
void _str(const UnknownExpr node, scope void delegate(string) sink, OpLevel level)
{
    sink(node.name);
}

@method
void _str(const LocalExpr node, scope void delegate(string) sink, OpLevel level)
{
    sink("$");
    sink(node.name);
}

@method
void _str(const LambdaExpr node, scope void delegate(string) sink, OpLevel level)
{
    return printBinaryExpr(node.a, node.b, sink, " -> ", level, OpLevel.lambda);
}

@method
void _str(const CallExpr node, scope void delegate(string) sink, OpLevel level)
{
    toStringSink(node.func, sink, OpLevel.primary);
    sink("(");
    toStringSink(node.arg, sink, OpLevel.primary);
    sink(")");
}

@method
void _str(const NegExpr node, scope void delegate(string) sink, OpLevel level)
{
    sink("-");
    toStringSink(node.value, sink, OpLevel.unary);
}

@method
void _str(const LnExpr node, scope void delegate(string) sink, OpLevel level)
{
    sink("ln(");
    toStringSink(node.arg, sink, OpLevel.comma);
    sink(")");
}

@method
void _str(const SinExpr node, scope void delegate(string) sink, OpLevel level)
{
    sink("sin(");
    toStringSink(node.arg, sink, OpLevel.comma);
    sink(")");
}

@method
void _str(const CosExpr node, scope void delegate(string) sink, OpLevel level)
{
    sink("cos(");
    toStringSink(node.arg, sink, OpLevel.comma);
    sink(")");
}

@method
void _str(const TanExpr node, scope void delegate(string) sink, OpLevel level)
{
    sink("tan(");
    toStringSink(node.arg, sink, OpLevel.comma);
    sink(")");
}

@method
void _str(const AccentExpr node, scope void delegate(string) sink, OpLevel level)
{
    toStringSink(node.func, sink, OpLevel.primary);
    sink("'");
}

@method
void _str(const ToExpr node, scope void delegate(string) sink, OpLevel level)
{
    return printBinaryExpr(node.a, node.b, sink, " to ", level, OpLevel.to);
}

@method
void _str(const AddExpr node, scope void delegate(string) sink, OpLevel level)
{
    return printBinaryExpr(node.a, node.b, sink, " + ", level, OpLevel.add);
}

@method
void _str(const SubExpr node, scope void delegate(string) sink, OpLevel level)
{
    return printBinaryExpr(node.a, node.b, sink, " - ", cast(OpLevel) (level + 1), OpLevel.add);
}

@method
void _str(const MulExpr node, scope void delegate(string) sink, OpLevel level)
{
    import exactmath.ops.match : match;
    
    if (node.b.match!(
        (immutable UnknownExpr b) {
            return node.a.match!(
                (immutable IntExpr a) {
                    _str(a, sink, level);
                    sink(" ");
                    sink(b.name);
                    return true;
                },
                (immutable NumExpr a) {
                    _str(a, sink, level);
                    sink(" ");
                    sink(b.name);
                    return true;
                },
                (immutable Expr a) => false,
            );
        },
        (immutable Expr b) => false,
    ))
        return;
    
    return printBinaryExpr(node.a, node.b, sink, " * ", level, OpLevel.mul);
}

@method
void _str(const DivExpr node, scope void delegate(string) sink, OpLevel level)
{
    return printBinaryExpr(node.a, node.b, sink, " / ", cast(OpLevel) (level + 1), OpLevel.unary);
}

@method
void _str(const ModExpr node, scope void delegate(string) sink, OpLevel level)
{
    return printBinaryExpr(node.a, node.b, sink, " % ", cast(OpLevel) (level + 1), OpLevel.mul);
}

@method
void _str(const PowExpr node, scope void delegate(string) sink, OpLevel level)
{
    return printBinaryExpr(node.a, node.b, sink, " ^ ", level, OpLevel.pow);
}

@method
void _str(const LogExpr node, scope void delegate(string) sink, OpLevel level)
{
    sink("log(");
    toStringSink(node.base, sink, OpLevel.comma);
    sink(")(");
    toStringSink(node.arg, sink, OpLevel.comma);
    sink(")");
}

@method
void _str(const DerivExpr node, scope void delegate(string) sink, OpLevel level)
{
    sink("deriv(");
    toStringSink(node.expr, sink, OpLevel.comma);
    sink(")(");
    toStringSink(node.unknown, sink, OpLevel.comma);
    sink(")");
}

@method
void _str(const IndexExpr node, scope void delegate(string) sink, OpLevel level)
{
    toStringSink(node.expr, sink, OpLevel.primary);
    sink("[");
    toStringSink(node.index, sink, OpLevel.primary);
    sink("]");
}

void printBinaryExpr(
    const Expr arg1,
    const Expr arg2,
    scope void delegate(string) sink,
    string op,
    OpLevel old,
    OpLevel level,
) {
    immutable parens = old > level;
    if (parens)
        sink("(");
    
    toStringSink(arg1, sink, level);
    sink(op);
    toStringSink(arg2, sink, level);
    
    if (parens)
        sink(")");
}

@method
void _str(const TupleExpr node, scope void delegate(string) sink, OpLevel level)
{
    sink("(");
    foreach (a, subExpr; node.values)
    {
        if (a)
            sink(", ");
        toStringSink(subExpr, sink, OpLevel.comma);
    }
    sink(")");
}

@method
void _str(const NumExpr node, scope void delegate(string) sink, OpLevel level)
{
    import std.conv : to;
    //import exactmath.util : doubleToString; sink(doubleToString(node.value));
    
    sink(node.value.to!string);
}

@method
void _str(const IntExpr node, scope void delegate(string) sink, OpLevel level)
{
    import std.conv : to;
    sink(node.value.to!string);
}

@method
void _str(const UnitExpr node, scope void delegate(string) sink, OpLevel level)
{
    sink(node.name);
}

@method
void _str(const Constant node, scope void delegate(string) sink, OpLevel level)
{
    sink(node.name);
}

// equations

@method
void _str(const EqualEquation node, scope void delegate(string) sink, OpLevel level)
{
    return printBinaryExpr(node.a, node.b, sink, " = ", level, OpLevel.comma);
}

@method
void _str(const NotEquation node, scope void delegate(string) sink, OpLevel level)
{
    sink("not [");
    toStringSink(node.equation, sink, OpLevel.comma);
    sink("]");
}

@method
void _str(const OrEquation node, scope void delegate(string) sink, OpLevel level)
{
    foreach (a, eq; node.equations)
    {
        if (a)
            sink(" or ");
        sink("[");
        toStringSink(eq, sink, OpLevel.comma);
        sink("]");
    }
}

@method
void _str(const AndEquation node, scope void delegate(string) sink, OpLevel level)
{
    foreach (a, eq; node.equations)
    {
        if (a)
            sink("; ");
        sink("[");
        toStringSink(eq, sink, OpLevel.comma);
        sink("]");
    }
}

@method
void _str(const ImpliesEquation node, scope void delegate(string) sink, OpLevel level)
{
    sink("[");
    toStringSink(node.condition, sink, OpLevel.comma);
    sink("] => [");
    toStringSink(node.implication, sink, OpLevel.comma);
    sink("]");
}

@method
void _str(const NullEquation node, scope void delegate(string) sink, OpLevel level)
{
    sink("?");
}

// types

// TODO
