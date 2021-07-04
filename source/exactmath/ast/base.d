/++
This module contains the base AST classes and several global functions that are
required.

The main class is `Node`, from which `Statement`, `Expr`, `Type` and `Equation`
are derived.
+/
module exactmath.ast.base;

public import exactmath.ast.statement : Statement;

// debug
__gshared void delegate(string) dbg;
__gshared uint indentCounter = 0;

/++
Utility function that can be used if a `pure` equals is needed.
+/
bool equals(const Expr a, const Expr b) pure
{
    if (a is b)
        return true;
    if (a is null || b is null)
        return false;
    return a.equals(b);
}

/// ditto
bool equals(const Equation a, const Equation b) pure
{
    if (a is b)
        return true;
    if (a is null || b is null)
        return false;
    return a.equals(b);
}

/// ditto
bool equals(const Type a, const Type b) pure
{
    if (a is b)
        return true;
    if (a is null || b is null)
        return false;
    return a.equals(b);
}

/++
+/
enum Tag
{
    node,
    
    type,
    anyType,
    sumType,
    productType,
    unknownType,
    setType,
    typeofType,
    inType,
    lambdaType,
    
    expr,
    dotExpr,
    unknownExpr,
    localExpr,
    letExpr,
    lambdaExpr,
    callExpr,
    unaryExpr,
    negExpr,
    lnExpr,
    sinExpr,
    cosExpr,
    tanExpr,
    accentExpr, // add more built-in functions here...
    binaryExpr,
    toExpr,
    addExpr,
    subExpr,
    mulExpr,
    divExpr,
    modExpr,
    powExpr,
    logExpr,
    derivExpr, // add more built-in functions here...
    indexExpr,
    tupleExpr,
    setExpr,
    singleExpr,
    numExpr,
    intExpr,
    unitExpr,
    constant,
    
    equation,
    equalEquation,
    notEquation,
    orEquation,
    andEquation,
    ltEquation,
    leEquation,
    impliesEquation,
    nullEquation,
}

/+
Function for UDAs
+/
package(exactmath)
Tag tag(Tag value) pure
{
    return value;
}

/++
Type used for approximating math expressions as numbers.
+/
alias Decimal = double;

// TODO make this a proper arbitrary precision BigDecimal
// maybe use [...] DUB package?

/++
An exception for any `exactmath` errors.
+/
/+abstract+/ class MathException : Exception
{
    import std.exception : basicExceptionCtors;
    
    ///
    mixin basicExceptionCtors;
}

/++
Represents an arithmetic error, such as dividing by 0, taking the logarithm
of 0 or taking the square root of a negative number.
+/
final class ArithmeticException : MathException
{
    import std.exception : basicExceptionCtors;
    
    ///
    mixin basicExceptionCtors;
}

/++
Represents a type mismatch in a call or some other expression.
+/
final class TypeException : MathException
{
    import std.exception : basicExceptionCtors;
    
    ///
    mixin basicExceptionCtors;
}

/++
Represents an implementation exception, meaning that the operation is not yet
supported.
+/
final class ImplException : MathException
{
    import std.exception : basicExceptionCtors;
    
    ///
    mixin basicExceptionCtors;
}

/++
Represents a tuple out of bounds error.
e.g. (0, 1, 2)[3] will trigger this
+/
final class BoundsException : MathException
{
    import std.exception : basicExceptionCtors;
    
    ///
    mixin basicExceptionCtors;
}

/++
+/
@tag(Tag.node)
abstract class Node
{
pure:
    ///
    immutable Tag tag;

    ///
    this(Tag tag)
    {
        this.tag = tag;
    }
    
    /++
    +/
    inout(T) downcast(T : Node)() inout
    {
        import std.traits : getUDAs;
        if (this is null)
            return null;
        if (tag == getUDAs!(T, Tag)[0])
        {
            assert(cast(inout(T)) this !is null, "Wrong tag on " ~ typeid(this).name);
            return cast(inout(T)) cast(inout(void*)) this;
        }
        assert(cast(inout(T)) this is null, "Wrong tag on " ~ typeid(this).name);
        return null;
    }
}

/+ TODO

/+--- Category ---+/

// See also: exactmath.ops.incategory

/++
+/
abstract class Category
{
    alias canAdd = CanAddCategory.instance;
    alias canMul = CanMulCategory.instance;
}

// TO CONSIDER:
// 
// Instead of getting type categories, what about adding a simplified
// template system? With typeof(operator+) = A -> B -> AddType(A, B)
// instead of 

/+
Custom category, with specified properties

Not integrated right now, maybe later.
+/
/+final class PropertyCategory
{
    
}+/

/++
Represents a category that holds all types that are addable.

Examples of instances are any numbers, tuples of only addables, lists of
addables, ???.

See_Also:
    exactmath.ops.incategory
+/
final class CanAddCategory : Category
{
    private this() immutable pure {}
    
    ///
    static immutable CanAddCategory instance;
    shared static this()
    {
        instance = new immutable CanAddCategory;
    }
}

/++
Represents a category that holds all types that can be multiplied.

Examples of instances are any numbers, tuples of only multiplyables, lists of
multiplyables, ???.
+/
final class CanMulCategory : Category
{
    private this() immutable pure {}
    
    ///
    static immutable NumCategory instance;
    shared static this()
    {
        instance = new immutable NumCategory;
    }
}

+/

/++
+/
@tag(Tag.type)
abstract class Type : Node
{
pure:
    ///
    this(Tag tag)
    {
        super(tag);
    }
    
    final override bool opEquals(const Object rhs) const
    {
        auto obj = cast(Type) rhs;
        return .equals(this, obj);
    }

    ///
    abstract bool equals(const Type rhs) const;
}

/++
+/
@tag(Tag.expr)
abstract class Expr : Node
{
pure:
    ///
    this(Tag tag)
    {
        super(tag);
    }
    
    final override string toString() const
    {
        return "Expr()";
    }
    /+final override string toString() const
    {
        return (cast(immutable) this).toString();
    }+/
    
    final override bool opEquals(const Object rhs) const
    {
        auto obj = cast(const(Expr)) rhs;
        return .equals(this, obj);
    }

    ///
    abstract bool equals(const Expr rhs) const;
}

/++
+/
@tag(Tag.equation)
abstract class Equation : Node
{
pure:
    ///
    this(Tag tag)
    {
        super(tag);
    }
    
    final override bool opEquals(const Object rhs) const
    {
        auto obj = cast(const(Equation)) rhs;
        return .equals(this, obj);
    }

    ///
    abstract bool equals(const Equation rhs) const;
}
