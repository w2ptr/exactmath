/++
+/
module exactmath.ops.match;

import exactmath.ast.base : Node, Expr, Equation, Tag;
import exactmath.ast.expr;

/++
+/
template match(funcs...)
{
    import std.meta : staticMap;
    import std.traits : CommonType, Parameters, ReturnType;
    
    alias OtherParams = Parameters!(funcs[0])[1 .. $];
    alias Return = ReturnType!(funcs[0]);
    
    // TODO
    /+template ActualReturnType(T)
    {
        static if (is(T == void))
            static assert(false);
            //alias ActualReturnType = ;
        else
            alias ActualReturnType = ReturnType!T;
    }+/
    
    //alias Return = CommonType!(staticMap!(ActualReturnType, funcs));
    // but won't work with `void` return type
    
    /++
    +/
    Return match(T : Node)(immutable T node)
    {
        import std.traits : getUDAs, Unqual;
        
        // TODO also match super-class, find the best specialization
        
        //Switch: final switch (node.tag)
        //{
            static foreach (func; funcs)
            {
                static if (__traits(isFinalClass, Unqual!(Parameters!func[0])))
                {
                    // case getUDAs!(Unqual!(Parameters!func[0]), Tag)[0]:
                    if (node.tag == getUDAs!(Unqual!(Parameters!func[0]), Tag)[0])
                    {
                        // check it with a dynamic_cast, then use reinterpret_cast
                        // in -release
                        assert(cast(Parameters!func[0]) node !is null,
                            Parameters!func[0].stringof ~ "'s tag is wrong");
                        static if (is(ReturnType!func == void))
                        {
                            func(*(cast(Parameters!func[0]*) &node));
                            static if (is(Return == void))
                                return;
                            else
                                return Return.init;
                        }
                        else
                            return func(*cast(Parameters!func[0]*) &node);
                    }
                }
                else static if (is(immutable(T) : Parameters!func[0])) // catch-all, can only appear once
                {
                    //default:
                        static if (is(ReturnType!func == void))
                        {
                            func(node);
                            static if (is(Return == void))
                                return;
                            else
                                return Return.init;
                        }
                        else
                            return func(node);
                }
                else
                {
                    // static foreach (SubClass; SubClasses!P) { case tag: return func(); }
                    static assert(false, "`match` does not support non-final class matching (yet): " ~ func.stringof);
                }
            }
        //}
        assert(false, "Switch for " ~ T.stringof ~ " does not check for " ~ typeid(node).name);
    }
}

///
pure unittest
{
    import exactmath.init;
    initMath();
    
    import exactmath.ast;
    
    auto x1 = new immutable AddExpr(
        new immutable NumExpr(3.0),
        new immutable NumExpr(5.0),
    );
    x1.match!(
        (immutable AddExpr expr) {
            expr.a.match!(
                (immutable NumExpr numExprA) {
                    assert(numExprA.value == 3.0, "a != 3");
                },
                (immutable Expr exprA) {
                    assert(false, typeid(exprA).name);
                },
            );
            expr.b.match!(
                (immutable NumExpr numExprB) {
                    assert(numExprB.value == 5.0, "b != 5");
                },
                (immutable Expr exprB) {
                    assert(false, typeid(exprB).name);
                },
            );
        },
        (immutable Expr expr) {
            assert(false);
        }
    );
}
