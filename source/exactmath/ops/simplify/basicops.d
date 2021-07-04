/++
Module that implements only const-folding operations for the basic operations,
such as x+y, x-y, x^y, -x and x(y).

This module is part of the exactmath rewriting functionality.
+/
module exactmath.ops.simplify.basicops;

import exactmath.ast;
import exactmath.ops.match;

pure:

///
unittest
{
    // (12 - 8 x) / 4 --> 3 - 2 x
    auto x = cast(immutable) new UnknownExpr("x");
    auto expr = new immutable SubExpr(
        IntExpr.literal!11,
        new immutable MulExpr(IntExpr.literal!8, x),
    );
    
    assert(.equals(
        divFolded(expr, IntExpr.literal!4),
        new immutable SubExpr(
            new immutable DivExpr(IntExpr.literal!11, IntExpr.literal!4),
            new immutable MulExpr(IntExpr.literal!2, x),
        ),
    ));
}

// generic *Expr --> *Folded mapper
version (DDoc)
{
    /++
    +/
    template foldedOpFor(T) {}
}
else
{
    alias foldedOpFor(T : NegExpr) = negFolded;
    alias foldedOpFor(T : LnExpr) = lnFolded;
    alias foldedOpFor(T : SinExpr) = (value) => new immutable SinExpr(value);
    alias foldedOpFor(T : CosExpr) = (value) => new immutable CosExpr(value);
    alias foldedOpFor(T : TanExpr) = (value) => new immutable TanExpr(value);
    alias foldedOpFor(T : AccentExpr) = (value) => new immutable AccentExpr(value);
    //alias foldedOpFor(T : CallExpr) = callFolded;
    alias foldedOpFor(T : ToExpr) = (a, b) => new immutable ToExpr(a, b);
    alias foldedOpFor(T : AddExpr) = addFolded;
    alias foldedOpFor(T : SubExpr) = subFolded;
    alias foldedOpFor(T : MulExpr) = mulFolded;
    alias foldedOpFor(T : DivExpr) = divFolded;
    alias foldedOpFor(T : ModExpr) = (a, b) => new immutable ModExpr(a, b);
    alias foldedOpFor(T : PowExpr) = powFolded;
    alias foldedOpFor(T : LogExpr) = (a, b) => new immutable LogExpr(a, b);
    alias foldedOpFor(T : DerivExpr) = (a, b) => new immutable DerivExpr(a, b); //derivFolded;
}

/++


Postconditions:
    the result will not be null
+/
immutable(Expr) orCreate(alias func, T, Args...)(Args args) pure
out (result; result !is null)
{
    if (auto maybe = func(args))
        return maybe;
    return new immutable T(args);
}

// TODO this module could, as an optimization, return null if no folding was
// possible, leaving the creation up to the caller if it wants to.

/++
Negates an expression, while attempting to keep the AST as flat as possible.
e.g. negFold(3 + b) = -3 - b
+/
immutable(Expr) negFolded(immutable Expr value) pure
in (value !is null)
out (result; result !is null)
{
    return value.match!(
        (immutable NumExpr value) => cast(immutable(Expr)) new immutable NumExpr(-value.value),
        (immutable IntExpr value) => new immutable IntExpr(-value.value),
        (immutable AddExpr value) { // -(a + b) = -a - b
            return new immutable SubExpr(negFolded(value.a), value.b);
        },
        (immutable SubExpr value) { // -(a - b) = -a + b
            return new immutable AddExpr(negFolded(value.a), value.b);
        },
        (immutable MulExpr value) { // -(a * b) = -a * b
            return new immutable MulExpr(negFolded(value.a), value.b);
        },
        (immutable DivExpr value) { // -(a / b) = -a / b
            return new immutable DivExpr(negFolded(value.a), value.b);
        },
        (immutable NegExpr value) => value.value,
        (immutable Expr value) => new immutable NegExpr(value),
    );
}

/++
Calculates the `ln` (natural logarithm = log(e)) of an expression, while
attempting to keep the AST as small and readable as possible.
e.g. lnFolded(e) = 1, but lnFolded(pi) = ln(pi)
+/
immutable(Expr) lnFolded(immutable Expr value) pure
in (value !is null)
out (result; result !is null)
{
    if (Constant.e.equals(value))
        return IntExpr.one;
    return new immutable LnExpr(value);
}

/++
Performs a binary operation on two values, while allocating as few intermediate
expressions as possible.
e.g. addFolded(5, 2) = 7 and not 5 + 2.
e.g. addFolded(5, 2/3) = 17/3 and not 5 + 2 / 3

Preconditions:
    `a` and `b` must not be null
Postconditions:
    the result will not be null
+/
immutable(Expr) addFolded(immutable Expr a, immutable Expr b) pure
in (a !is null)
in (b !is null)
out (result; result !is null)
{
    if (NumExpr.zero.equals(a) || IntExpr.zero.equals(a))
        return b;
    if (NumExpr.zero.equals(b) || IntExpr.zero.equals(b))
        return a;
    
    if (auto newDiv = divMatcher!(
        // TODO shouldn't orCreate in these functions be removed? i.e. if it's
        // null, then try another method?
        (aa, ab, b) { // expr, number, expr
            // aa/ab + b = (aa + b*ab) / ab
            return orCreate!(tryCalcDiv, DivExpr)(
                addFolded(aa, mulFolded(ab, b)),
                ab,
            );
        },
        (a, ba, bb) { // expr, expr, number
            // a + ba/bb = (a*bb + ba) / bb
            return orCreate!(tryCalcDiv, DivExpr)(
                addFolded(mulFolded(a, bb), ba),
                bb,
            );
        },
        (aa, ab, ba, bb) { // expr, number, expr, number
            // aa / ab + ba / bb =
            // (aa * bb + ba * ab) / (ab * bb)
            return orCreate!(tryCalcDiv, DivExpr)(
                addFolded(mulFolded(aa, bb), mulFolded(ba, ab)),
                mulFolded(ab, bb),
            );
        },
    )(a, b))
        return newDiv;
    
    auto result = binaryMatcher!((numA, numB) {
        if (numA == 0) // 0 + b = b
            return numB % 1 == 0
                ? new immutable IntExpr(cast(long) numB)
                : new immutable NumExpr(numA);
        
        if (numB == 0) // a + 0 = a
            return numA % 1 == 0
                ? new immutable IntExpr(cast(long) numA)
                : new immutable NumExpr(numA);
        
        if (numA % 1 == 0 && numB % 1 == 0)
        {
            auto result = cast(long) numA + cast(long) numB;
            assert(result == cast(long) (numA + numB));
            return new immutable IntExpr(result);
        }
        return new immutable NumExpr(numA + numB);
    })(a, b);
    return result ? result : new immutable AddExpr(a, b);
}

/// ditto
immutable(Expr) subFolded(immutable Expr a, immutable Expr b) pure
in (a !is null)
in (b !is null)
out (result; result !is null)
{
    if (NumExpr.zero.equals(a) || IntExpr.zero.equals(a))
        return negFolded(b);
    if (NumExpr.zero.equals(b) || IntExpr.zero.equals(b))
        return a;
    
    if (auto newDiv = divMatcher!(
        (aa, ab, b) {
            // aa/ab - b = (aa - b*ab) / ab
            return orCreate!(tryCalcDiv, DivExpr)(
                subFolded(aa, mulFolded(b, ab)),
                ab,
            );
        },
        (a, ba, bb) {
            // a - ba/bb = (a*bb - ba) / bb
            return orCreate!(tryCalcDiv, DivExpr)(
                subFolded(mulFolded(a, bb), ba),
                bb,
            );
        },
        (aa, ab, ba, bb) {
            // aa/ab - ba/bb =
            // (aa*bb - ba*ab) / (ab*bb)
            return orCreate!(tryCalcDiv, DivExpr)(
                subFolded(mulFolded(aa, bb), mulFolded(ba, ab)),
                mulFolded(ab, bb),
            );
        },
    )(a, b))
        return newDiv;
    
    auto result = binaryMatcher!((numA, numB) {
        return numA % 1 == 0 && numB % 1 == 0
            ? new immutable IntExpr(cast(long) numA - cast(long) numB)
            : new immutable NumExpr(numA - numB);
    })(a, b);
    return result ? result : new immutable SubExpr(a, b);
}

/// ditto
immutable(Expr) mulFolded(immutable Expr a, immutable Expr b) pure
in (a !is null)
in (b !is null)
out (result; result !is null)
{
    if (auto result = tryCalcMul(a, b))
        return result;
    
    if (auto result = divMatcher!(
        (aa, ab, b) {
            // aa/ab * b = (aa*b) / ab
            return orCreate!(tryCalcDiv, DivExpr)(
                orCreate!(tryCalcMul, MulExpr)(aa, b),
                ab,
            );
        },
        (a, ba, bb) {
            // a * ba/bb = (a*ba) / bb
            return orCreate!(tryCalcDiv, DivExpr)(
                orCreate!(tryCalcMul, MulExpr)(a, ba),
                bb,
            );
        },
        (aa, ab, ba, bb) {
            // aa/ab * ba/bb = (aa*ba) / (ab*bb)
            return orCreate!(tryCalcDiv, DivExpr)(
                orCreate!(tryCalcMul, MulExpr)(aa, ba),
                orCreate!(tryCalcMul, MulExpr)(ab, bb),
            );
        },
    )(a, b))
        return result;
    
    return a.match!(
        (immutable NumExpr a) => b.match!(
            (immutable NumExpr b) {
                return cast(immutable(Expr)) new immutable NumExpr(
                    a.value * b.value
                );
            },
            (immutable IntExpr b) =>
                new immutable NumExpr(a.value * cast(Decimal) b.value),
            (immutable Expr b) => applyMul(b, a),
        ),
        (immutable IntExpr a) => b.match!(
            (immutable NumExpr b) =>
                cast(immutable(Expr)) new immutable NumExpr(cast(Decimal) a.value * b.value),
            (immutable IntExpr b) =>
                new immutable IntExpr(a.value * b.value),
            (immutable Expr b) => applyMul(b, a),
        ),
        (immutable Expr a) => b.match!(
            (immutable NumExpr b) => applyMul(a, b),
            (immutable IntExpr b) => applyMul(a, b),
            (immutable Expr b) => new immutable MulExpr(a, b),
        ),
    );
}

/// ditto
immutable(Expr) divFolded(immutable Expr a, immutable Expr b) pure
in (a !is null)
in (b !is null)
out (result; result !is null)
{
    if (auto result = tryCalcDiv(a, b))
        return result;
    
    if (auto result = divMatcher!(
        (aa, ab, b) {
            // aa/ab / b = aa / (ab*b)
            return orCreate!(tryCalcDiv, DivExpr)(
                aa,
                orCreate!(tryCalcMul, MulExpr)(ab, b),
            );
        },
        (a, ba, bb) {
            // a / (ba/bb) = a*bb / ba
            return orCreate!(tryCalcDiv, DivExpr)(
                orCreate!(tryCalcMul, MulExpr)(a, bb),
                ba,
            );
        },
        (aa, ab, ba, bb) {
            // (aa/ab) / (ba/bb) = aa*bb / (ab*ba)
            return orCreate!(tryCalcDiv, DivExpr)(
                orCreate!(tryCalcMul, MulExpr)(aa, bb),
                orCreate!(tryCalcMul, MulExpr)(ab, ba),
            );
        },
    )(a, b))
        return result;
    
    // FIXME: is applyDiv doing the same work as divMatcher up ^there?
    return b.match!(
        (immutable NumExpr b) => applyDiv(a, b),
        (immutable IntExpr b) => applyDiv(a, b),
        (immutable Constant b) => applyDiv(a, b),
        (immutable Expr b) => new immutable DivExpr(a, b),
    );
}

/// ditto
immutable(Expr) powFolded(immutable Expr a, immutable Expr b) pure
in (a !is null)
in (b !is null)
out (result; result !is null)
{
    if (NumExpr.zero.equals(b) || IntExpr.zero.equals(b)) // x ^ 0 = 1 (even for x=0)
        return IntExpr.one;
    if (NumExpr.one.equals(b) || IntExpr.one.equals(b)) // x ^ 1 = x
        return a;
    if (NumExpr.one.equals(a) || IntExpr.one.equals(a)) // 1 ^ x = 1
        return IntExpr.one;
    
    // TODO this doesn't work properly?
    if (auto base = a.downcast!IntExpr())
    {
        if (auto exponent = b.downcast!IntExpr())
            return new immutable IntExpr(base.value ^^ exponent.value);
    }
    
    return new immutable PowExpr(a, b);
}

package(exactmath.ops.simplify): // utility functions

/+
small utility function for throwing a type exception
+/
pragma(inline, true)
immutable(Expr) tupleError(string err)(immutable Expr a, immutable Expr b)
{
    import exactmath.ops.tostring : toFullString;
    
    throw new TypeException(
        "Cannot perform a binary operation on " ~ err ~ ": " ~
        a.toFullString() ~ " and " ~ b.toFullString(),
    );
}

/+
Attempts to match quotients, in which case it will call one of the callbacks.
e.g. 1/2 + 3/4 --> will call ondivs(1,2, 3,4) --> (1*4 + 3*2) / (4 * 2) = 10/8
e.g. 1/2 * 4   --> will call ondiv1(1,2, 4) --> (4 * 1) / 2 = 4 / 2
e.g. 4   - 1/2 --> will call ondiv2(4, 1,2) --> 8/2 - 1/2 = 7/2
otherwise returns null.
+/
immutable(Expr) divMatcher(alias ondiv1, alias ondiv2, alias ondivs)(immutable Expr a, immutable Expr b)
in (a !is null)
in (b !is null)
{
    return a.match!(
        (immutable NumExpr a) => b.match!(
            (immutable DivExpr b) => fractionMatcher!((ba, bb) => ondiv2(a, ba, bb))(b),
            (immutable Expr b) => null,
        ),
        (immutable IntExpr a) => b.match!(
            (immutable DivExpr b) => fractionMatcher!((ba, bb) => ondiv2(a, ba, bb))(b),
            (immutable Expr b) => null,
        ),
        (immutable DivExpr a) => b.match!(
            (immutable NumExpr b) => fractionMatcher!((aa, ab) => ondiv1(aa, ab, b))(a),
            (immutable IntExpr b) => fractionMatcher!((aa, ab) => ondiv1(aa, ab, b))(a),
            (immutable DivExpr b) => fractionMatcher!(
                (aa, ab) => fractionMatcher!(
                    (ba, bb) => ondivs(aa, ab, ba, bb),
                )(b),
            )(a),
            (immutable Expr b) => null,
        ),
        (immutable Expr a) => null,
    );
}

/+
Does the same as `tryApplyMul`, but always returns a meaningful result instead
of null.
+/
immutable(Expr) applyMul(immutable Expr a, immutable Expr factor) pure
in (a !is null)
in (factor !is null)
out (result; result !is null)
{
    auto result = tryApplyMul(a, factor);
    return result ? result : new immutable MulExpr(a, factor);
}

/+
Will attempt to rewrite a multiplication to provide a flatter structure with
fewer constants; if this is impossible, `null` is returned,
e.g. ``.
e.g. `(a + b) * num = a * num + b * num`,
e.g. `(num1 * b) * num2 = num3 * b`.
+/
immutable(Expr) tryApplyMul(immutable Expr a, immutable Expr factor) pure
in (a !is null)
in (factor !is null)
{
    return a.match!(
        (immutable NumExpr a) => orCreate!(tryCalcMul, MulExpr)(a, factor),
        (immutable IntExpr a) => orCreate!(tryCalcMul, MulExpr)(a, factor),
        (immutable AddExpr a) {
            // both terms must succeed
            if (auto a2 = tryApplyMul(a.a, factor))
            {
                if (auto b2 = tryApplyMul(a.b, factor))
                    return addFolded(a2, b2);
            }
            return null;
        },
        (immutable SubExpr a) {
            // both terms must succeed
            if (auto a2 = tryApplyMul(a.a, factor))
            {
                if (auto b2 = tryApplyMul(a.b, factor))
                    return subFolded(a2, b2);
            }
            return null;
        },
        (immutable MulExpr a) {
            // num1 * b * num2 = (num1*num2) * b
            if (auto aa2 = tryApplyMul(a.a, factor))
                return orCreate!(tryCalcMul, MulExpr)(aa2, a.b);
            // a * num1 * num2 = (num1*num2) * a
            if (auto ab2 = tryApplyMul(a.b, factor))
                return orCreate!(tryCalcMul, MulExpr)(ab2, a.a);
            return null;
        },
        (immutable DivExpr a) {
            // (num1 / b) * num2 = (num1*num2) / b
            if (auto aa2 = tryApplyMul(a.a, factor))
                return orCreate!(tryCalcDiv, DivExpr)(aa2, a.b);
            // (a / num1) * num2 = (num2/num1) * a
            if (auto ab2 = tryApplyDiv(factor, a.b))
                return orCreate!(tryCalcMul, MulExpr)(ab2, a.a);
            return null;
        },
        (immutable Expr a) => null,
    );
}

/+
Does the same as `tryApplyDiv`, but returns a meaningful result if
`tryApplyDiv` does not.
+/
immutable(Expr) applyDiv(immutable Expr a, immutable Expr divisor) pure
in (a !is null)
in (divisor !is null)
out (result; result !is null)
{
    auto result = tryApplyDiv(a, divisor);
    return result ? result : new immutable DivExpr(a, divisor);
}

/+
Will apply a division to some sub-expressions, to provide a flatter structure;
if this is impossibe, `null` is returned,
e.g. `num1 / b / num2 = (num1/num2) / b`,
e.g. `a * num1 / num2 = a * (num1/num2)`
e.g. `(a + b) / num = a/num + b/num`.
+/
immutable(Expr) tryApplyDiv(immutable Expr a, immutable Expr divisor) pure
in (a !is null)
in (divisor !is null)
{
    return a.match!(
        (immutable NumExpr a) => orCreate!(tryCalcDiv, DivExpr)(a, divisor),
        (immutable IntExpr a) => orCreate!(tryCalcDiv, DivExpr)(a, divisor),
        (immutable AddExpr a) { // (a + b) / num = a/num + b/num
            return cast(immutable(Expr)) addFolded(
                applyDiv(a.a, divisor),
                applyDiv(a.b, divisor),
            );
        },
        (immutable SubExpr a) { // (a - b) / num = a/num - b/num
            return subFolded(
                applyDiv(a.a, divisor),
                applyDiv(a.b, divisor),
            );
        },
        // TODO make this work for non-`SingleExpr`s as well
        // e.g. (x + 2) / x = 1 + 2 / x
        (immutable MulExpr a) {
            // (num1 * b) / num2 = (num1/num2) * b
            if (auto aa2 = tryApplyDiv(a.a, divisor))
                return orCreate!(tryCalcMul, MulExpr)(aa2, a.b);
            // (a * num1) / num2 = (num1/num2) * a
            if (auto ab2 = tryApplyDiv(a.b, divisor))
                return orCreate!(tryCalcMul, MulExpr)(ab2, a.a);
            return null;
        },
        (immutable DivExpr a) {
            // num1 / b / num2 = (num1/num2) / b
            if (auto aa2 = tryApplyDiv(a.a, divisor))
                return orCreate!(tryCalcDiv, DivExpr)(aa2, a.b);
            // a / num1 / num2 = a / (num1*num2)
            if (auto ab2 = tryApplyMul(a.b, divisor))
                return orCreate!(tryCalcMul, MulExpr)(a.a, ab2);
            return null;
        },
        (immutable Expr a) => null,
    );
}

/+
Attempts to multiply two numbers with each other, otherwise returns null.
e.g. `tryCalcMul(3, 5)` returns 15
e.g. `tryCalcMul(3, x)` returns null
+/
immutable(Expr) tryCalcMul(immutable Expr a, immutable Expr b)
in (a !is null)
in (b !is null)
{
    if (NumExpr.zero.equals(a) || IntExpr.zero.equals(a)) // a * 0 = 0
        return IntExpr.zero;
    if (NumExpr.zero.equals(b) || IntExpr.zero.equals(b))
        return IntExpr.zero;
    if (NumExpr.one.equals(a) || IntExpr.one.equals(a)) // 1 * b = b
        return b;
    if (NumExpr.one.equals(b) || IntExpr.one.equals(b)) // a * 1 = a
        return a;
    if (NumExpr.minOne.equals(a) || IntExpr.minOne.equals(a)) // a * -1 = -a
        return negFolded(b);
    if (NumExpr.minOne.equals(b) || IntExpr.minOne.equals(b))
        return negFolded(a);
    
    if (auto result = binaryMatcher!(
        (numA, numB) {
            if (numA % 1 == 0 && numB % 1 == 0) // int * int : int
            {
                auto result = cast(long) numA * cast(long) numB;
                assert(result == cast(long) (numA * numB), "overflow or something");
                return cast(immutable(Expr)) new immutable IntExpr(result);
            }
            return new immutable NumExpr(numA * numB);
        }
    )(a, b))
        return result;
    
    return null;
}

/+
Attempts to divide two numbers, otherwise returns null.
e.g. `tryCalcDiv(6, 2)` returns 3
e.g. `tryCalcDiv(x, 2)` returns null
+/
immutable(Expr) tryCalcDiv(immutable Expr dividend, immutable Expr divisor)
in (dividend !is null)
in (divisor !is null)
{
    if (NumExpr.zero.equals(dividend) || IntExpr.zero.equals(dividend)) // 0 / b = 0
        return IntExpr.zero;
    if (NumExpr.one.equals(divisor) || IntExpr.one.equals(divisor)) // a / 1 = a
        return dividend;
    
    if (auto result = binaryMatcher!(
        (numA, numB) {
            // number1 / number2 cannot always be simplified, because it may yield
            // inaccurate results
            // TODO add more possibilities
            // e.g. 2.4 / 2 = 1.2, without losing any precision
            // e.g. 6/4 = 3/2
            
            if (numA % numB == 0) // e.g. 6/2 = 3
            {
                auto result = cast(long) numA / cast(long) numB;
                assert(result == cast(long) (numA / numB));
                return cast(immutable(Expr)) new immutable IntExpr(result);
            }
            if (numB % numA == 0) // e.g. 2/6 = 1/3
            {
                auto result = cast(long) numB / cast(long) numA;
                assert(result == cast(long) (numB / numA));
                return new immutable DivExpr(IntExpr.one, new immutable IntExpr(result));
            }
            return null;
        }
    )(dividend, divisor))
        return result;
    
    return null;
}

/+
`fn` should return null if it cannot constant-fold the match.
`binaryMatcher` will return null if a fold is impossible
+/
immutable(Expr) binaryMatcher(alias fn)(immutable Expr a, immutable Expr b)
in (a !is null)
in (b !is null)
{
    return a.match!(
        (immutable NumExpr a) => cast(immutable(Expr)) b.match!(
            (immutable NumExpr b) => cast(immutable(Expr)) fn(a.value, b.value),
            (immutable IntExpr b) => fn(a.value, cast(Decimal) b.value),
            (immutable TupleExpr b) => tupleError!"a number and a tuple"(a, b),
            (immutable Expr b) => null,
        ),
        (immutable IntExpr a) => b.match!(
            (immutable NumExpr b) => cast(immutable(Expr)) fn(cast(Decimal) a.value, b.value),
            (immutable IntExpr b) => fn(a.value, b.value),
            (immutable TupleExpr b) => tupleError!"a number and a tuple"(a, b),
            (immutable Expr b) => null,
        ),
        /+(immutable TupleExpr a) => b.match!(
            (immutable TupleExpr b) {
                if (a.values.length != b.values.length)
                    return tupleError!"two tuples of different lengths"(expr);
                immutable(Expr)[] result;
                foreach (i, value; a.values)
                    result ~= binaryMatcher!(fn, T)(value, b.values[i]);
                return new immutable TupleExpr(result);
            },
            (immutable Expr b) => null,
        ),+/
        (immutable Expr a) => null,
    );
}

/+
Will attempt to match an expresssion as a fraction, meaning that the divisor is
a literal.
e.g. x / 2 --> onFraction(x, 2.value)
+/
immutable(Expr) fractionMatcher(alias onFraction)(immutable DivExpr expr)
in (expr !is null)
{
    return expr.b.match!(
        (immutable NumExpr b) => onFraction(expr.a, b),
        (immutable IntExpr b) => onFraction(expr.a, b),
        (immutable Expr b) => null,
    );
}
