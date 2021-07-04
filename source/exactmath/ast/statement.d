/++
This module contains `Statement` subclasses.
+/
module exactmath.ast.statement;

import exactmath.ast.base;

/++
+/
struct Statement
{
pure:
    ///
    this(ExprStatement exprStatement)
    {
        _exprStatement = exprStatement;
        _tag = 0;
    }
    /// ditto
    this(EquationStatement equationStatement)
    {
        _equationStatement = equationStatement;
        _tag = 1;
    }
    /// ditto
    this(TypeStatement typeStatement)
    {
        _typeStatement = typeStatement;
        _tag = 2;
    }
    /// ditto
    this(TypeAliasStatement typeAliasStatement)
    {
        _typeAliasStatement = typeAliasStatement;
        _tag = 3;
    }
    
    inout(T)* as(T)() inout
    {
        static if (is(T == ExprStatement))
        {
            if (_tag == 0)
                return &_exprStatement;
        }
        else static if (is(T == EquationStatement))
        {
            if (_tag == 1)
                return &_equationStatement;
        }
        else static if (is(T == TypeStatement))
        {
            if (_tag == 2)
                return &_typeStatement;
        }
        else static if (is(T == TypeAliasStatement))
        {
            if (_tag == 3)
                return &_typeAliasStatement;
        }
        else
            static assert(false, "Type " ~ T.stringof ~ " not a Statement");
        
        return null;
    }
    
private:
    uint _tag;
    
    union
    {
        ExprStatement _exprStatement;
        EquationStatement _equationStatement;
        TypeStatement _typeStatement;
        TypeAliasStatement _typeAliasStatement;
    }
}

/++
+/
struct ExprStatement
{
pure:
    ///
    immutable Expr expr;
    
    this(immutable Expr expr)
    {
        this.expr = expr;
    }
}

/++
+/
struct EquationStatement
{
pure:
    ///
    immutable Equation equation;
    
    this(immutable Equation equation)
    {
        this.equation = equation;
    }
}

/++
+/
struct TypeStatement
{
pure:
    ///
    immutable Type type;
    
    this(immutable Type type)
    {
        this.type = type;
    }
}

/++
+/
struct TypeAliasStatement
{
pure:
    ///
    immutable string name;
    
    ///
    immutable Type type;
    
    this(immutable string name, immutable Type type)
    {
        this.name = name;
        this.type = type;
    }
}
