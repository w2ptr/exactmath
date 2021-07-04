/++
This module contains `Equation` subclasses.
+/
module exactmath.ast.equation;

import exactmath.ast.base;

/++
This class represents a generic comparison equation between two expressions.

e.g.
a = b
a > b
a <= b
+/
/+
@tag(Tag.cmpEquation)
abstract class CmpEquation : Equation
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
}
+/

/++
+/
@tag(Tag.equalEquation)
final class EqualEquation : /+Cmp+/Equation
{
pure:
    ///
    immutable Expr a;
    
    ///
    immutable Expr b;

    ///
    this(immutable Expr a, immutable Expr b)
    {
        super(Tag.equalEquation);
        this.a = a;
        this.b = b;
    }
    /// ditto
    this(immutable Expr a, immutable Expr b) immutable
    {
        super(Tag.equalEquation);
        this.a = a;
        this.b = b;
    }
    
    override bool equals(const Equation rhs) const
    {
        auto obj = rhs.downcast!EqualEquation();
        if (obj is null)
            return false;
        
        return .equals(a, obj.a) && .equals(b, obj.b)
            || .equals(a, obj.b) && .equals(b, obj.a);
    }
}

/+
/++
a < b
+/
@tag(Tag.ltEquation)
final class LTEquation : CmpEquation
{
pure:
    ///
    immutable Expr smallest;
    
    ///
    immutable Expr greatest;
    
    this(immutable Expr smallest, immutable Expr greatest)
    {
        super(Tag.ltEquation);
        this.smallest = smallest;
        this.greatest = greatest;
    }
}

/++
a <= b
+/
@tag(Tag.leEquation)
final class LEEquation : CmpEquation
{
pure:
    ///
    immutable Expr smallest;
    
    ///
    immutable Expr greatest;
    
    this(immutable Expr smallest, immutable Expr greatest)
    {
        super(Tag.leEquation);
        this.smallest = smallest;
        this.greatest = greatest;
    }
}
+/

/++
+/
@tag(Tag.notEquation)
final class NotEquation : Equation
{
pure:
    ///
    immutable Equation equation;

    ///
    this(immutable Equation equation)
    {
        super(Tag.notEquation);
        this.equation = equation;
    }
    
    override bool equals(const Equation rhs) const
    {
        auto obj = rhs.downcast!NotEquation();
        return obj && .equals(equation, obj.equation);
    }
}

// abstract class MultiEquation : Equation { immutable Equation[] equations; }

/++
+/
@tag(Tag.orEquation)
final class OrEquation : Equation
{
pure:
    ///
    immutable Equation[] equations;
    // TODO make ^this a set instead of unordered array

    ///
    this(immutable Equation[] equations)
    {
        super(Tag.orEquation);
        this.equations = equations;
    }
    
    override bool equals(const Equation rhs) const // TODO remove this duplication in AndEquation?
    {
        auto obj = rhs.downcast!OrEquation();
        if (obj is null)
            return false;
        if (equations.length != obj.equations.length)
            return false;
        
        foreach (a, equation; equations)
        {
            if (!.equals(equation, obj.equations[a]))
                return false;
        }
        return true;
    }
}

/++
+/
@tag(Tag.andEquation)
final class AndEquation : Equation
{
pure:
    ///
    immutable Equation[] equations;

    ///
    this(immutable Equation[] equations)
    {
        super(Tag.andEquation);
        this.equations = equations;
    }
    
    override bool equals(const Equation rhs) const
    {
        auto obj = rhs.downcast!AndEquation();
        if (obj is null)
            return false;
        if (equations.length != obj.equations.length)
            return false;
        
        foreach (a, equation; equations)
        {
            if (!.equals(equation, obj.equations[a]))
                return false;
        }
        return true;
    }
}

/++
Describes an "implies" relationship between two logical propositions.

"A => B" is the same as "if A then B" and as "!A or B".
+/
@tag(Tag.impliesEquation)
final class ImpliesEquation : Equation
{
pure:
    ///
    immutable Equation condition;
    
    ///
    immutable Equation implication;

    ///
    this(immutable Equation condition, immutable Equation implication)
    {
        super(Tag.impliesEquation);
        this.condition = condition;
        this.implication = implication;
    }
    
    override bool equals(const Equation rhs) const
    {
        auto obj = rhs.downcast!ImpliesEquation();
        return obj &&
            .equals(condition, obj.condition) &&
            .equals(implication, obj.implication);
    }
}

/++
Represents an equation that contains no information.

The Null Equation is always true; that means that `EqA and NullEquation` is the
same as just `EqA`.
+/
@tag(Tag.nullEquation)
final class NullEquation : Equation
{
pure:
    ///
    static immutable NullEquation instance;
    
    override bool equals(const Equation rhs) const
    {
        if (this is rhs)
            return true;
        assert(cast(const(NullEquation)) rhs is null, "NullEquation is not unique");
        return false;
    }
    
private:
    this() immutable
    {
        super(Tag.nullEquation);
    }
    
    shared static this()
    {
        instance = new immutable NullEquation;
    }
}
