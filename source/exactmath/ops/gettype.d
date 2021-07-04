/++


NOTE: this module is not finished yet!!!
+/
module exactmath.ops.gettype;

import exactmath.ast;
import exactmath.state;

import openmethods;
mixin(registerMethods);

// typeof(x)

/++
Attempts to calculate the type that is the closest to the actual variable type.

The actual type of `expr` will always be either equal to the result, or a
subtype of the result.

Params:
    expr = the expression to calculate a type of
    state = the state of expressions
Returns:
    the type of the expression or null if a type cannot be found
+/
immutable(Type) getType(immutable Expr expr, BindingState* state) pure
{
    import exactmath.util : assumePure;
    
    return assumePure!impureGetType(expr, state);
}

/++
+/
immutable(Type) getReturnType(immutable Expr expr, BindingState* state) pure
{
    import exactmath.util : assumePure;
    
    assert(false, "TODO");
    //return assumePure!impureReturnType(expr, state);
}

private:

immutable(Type) impureGetType(immutable Expr expr, BindingState* state)
{
    return type(expr, state);
}
immutable(Type) type(virtual!(immutable(Expr)), BindingState*);

// typeof(x(y))

/+immutable(Type) impureReturnType(immutable Expr expr, BindingState* state)
{
    return returnType(expr, state);
}
immutable(Type) returnType(virtual!(immutable(Expr)), immutable Expr arg, BindingState* state);+/

// typeof(x + y) or typeof(x - y)

immutable(Type) getAddType(immutable Type type1, immutable Type type2, BindingState* state) pure
{
    import exactmath.util : assumePure;
    
    return assumePure!impureAddType(type1, type2, state);
}
immutable(Type) impureAddType(immutable Type type1, immutable Type type2, BindingState* state)
{
    return add(type1, type2, state);
}
immutable(Type) add(virtual!(immutable(Type)), virtual!(immutable(Type)), BindingState*);

// typeof(x * y) or typeof(x / y)

immutable(Type) getMulType(immutable Type type1, immutable Type type2, BindingState* state) pure
{
    import exactmath.util : assumePure;
    
    return assumePure!impureMulType(type1, type2, state);
}
immutable(Type) impureMulType(immutable Type type1, immutable Type type2, BindingState* state)
{
    return mul(type1, type2, state);
}
immutable(Type) mul(virtual!(immutable(Type)), virtual!(immutable(Type)), BindingState*);

/+----------------------------
implementations
----------------------------+/

@method
immutable(Type) _type(immutable UnknownExpr expr, BindingState* state)
{
    return AnyType.instance;
    // TODO
    //auto value = state.getOneExact(expr);
    //if (value is null)
    //    return AnyType.instance;
    //return value.getType(state);
}

@method
immutable(Type) _type(immutable LambdaExpr expr, BindingState* state)
{
    return cast(immutable) new LambdaType(
        expr.getReturnType(state),
        expr.b.getType(state),
    );
}

@method
immutable(Type) _type(immutable AddExpr expr, BindingState* state)
{
    assert(false, "TODO");
}

// TODO all other binary operators

@method
immutable(Type) _type(immutable CallExpr expr, BindingState* state)
{
    return expr.func.getReturnType(state);
}

@method
immutable(Type) _type(immutable TupleExpr expr, BindingState* state)
{
    import exactmath.util : eagerMap;
    
    return cast(immutable) new ProductType(expr.values.eagerMap!((value) => value.getType(state)));
}

@method
immutable(Type) _type(immutable SetExpr expr, BindingState* state)
{
    return SetType.instance;
}

@method
immutable(Type) _type(immutable NumExpr expr, BindingState* state)
{
    //if (expr.isNatural())
    //    return NaturalType.instance;
    //return InType.reals;
    assert(false, "unimplemented");
}

@method
immutable(Type) _type(immutable UnitExpr expr, BindingState* state)
{
    assert(false, "unimplemented");
    //return InType.getSingleUnitCollection(expr);
}

@method
immutable(Type) _type(immutable Constant expr, BindingState* state)
{
    assert(false, "unimplemented");
    //return InType.reals;
}

// typeof(x(y))

/+
@method
immutable(Type) _returnType(immutable Expr func, BindingState* state)
{
    throw new MathException("Cannot determine type of expression");
    //auto value = state.getOneExact(expr);
    //if (value is null)
    //    return AnyType.instance;
    //return value.getReturnType(state);
}

@method
immutable(Type) _returnType(immutable LambdaExpr func, BindingState* state)
{
    return expr.b.getType(state);
}

@method
immutable(Type) _returnType(immutable BinaryOp func, BindingState* state)
{
    assert(false, "TODO");
}

// TODO make some of these `UnaryOp`s?

@method
immutable(Type) _returnType(immutable UnaryOp func, BindingState* state)
{
    assert(false, "TODO");
}

@method
immutable(Type) _returnType(immutable LogFunc func, BindingState* state)
{
    assert(false, "TODO");
}

@method
immutable(Type) _returnType(immutable LnFunc func, BindingState* state)
{
    assert(false, "TODO");
}

@method
immutable(Type) _returnType(immutable SinFunc func, BindingState* state)
{
    assert(false, "TODO");
}

@method
immutable(Type) _returnType(immutable CosFunc func, BindingState* state)
{
    assert(false, "TODO");
}

@method
immutable(Type) _returnType(immutable TanFunc func, BindingState* state)
{
    assert(false, "TODO");
}

@method
immutable(Type) _returnType(immutable DerivFunc func, BindingState* state)
{
    assert(false, "TODO");
}
+/

// typeof(x + y)

/+@method
immutable(Type) _add()
{
    
}+/

// typeof(x * y)

/+@method
immutable(Type) _mul()
{
    
}+/
