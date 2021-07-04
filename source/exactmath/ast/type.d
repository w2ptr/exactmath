/++
+/
module exactmath.ast.type;

import exactmath.ast.base;

/++
Represents a type `#(CanAdd a) a -> a` where `CanAdd` is `values[x].category`,
`a -> a` is `type` and `a` is a pointer to the first CanAdd category.
+/
/+final class CategoryType : Type
{
    /+
    +/
    /+static struct Pair
    {
        ///
        Identifier id;
        
        ///
        Category category;
    }+/
    
    ///
    immutable Category[] values;
    
    ///
    immutable Type type;
    
    this(immutable Category[] values, immutable Type type)
    {
        this.values = values;
        this.type = type;
    }
    
    //static immutable CategoryType unaryNumFunc;
    static immutable CategoryType binaryAddFunc; // #(CanAdd a) A -> A -> A
    static immutable CategoryType binaryMulFunc; // #(CanMul a) A -> A -> A
    
    shared static this()
    {
        immutable addPairs = [Category.canAdd];
        binaryAddFunc = new immutable CategoryType(
            addPairs,
            new immutable LambdaType(
                new immutable DeclType(&addPairs[0]),
                new immutable LambdaType(
                    new immutable DeclType(&addPairs[0]),
                    new immutable DeclType(&addPairs[0]),
                ),
            ),
        );
        
        immutable mulPairs = [Category.canMul];
        binaryMulFunc = new immutable CategoryType(
            mulPairs,
            new immutable LambdaType(
                new immutable DeclType(&mulPairs[0]),
                new immutable LambdaType(
                    new immutable DeclType(&mulPairs[0]),
                    new immutable DeclType(&mulPairs[0]),
                ),
            ),
        );
    }
}+/

/++
+/
@tag(Tag.anyType)
final class AnyType : Type
{
pure:
    private this() immutable { super(Tag.anyType); }
    
    override bool equals(const Type rhs) const
    {
        assert(this is instance, "Another AnyType instance was created!");
        return this is rhs;
    }

    ////
    static immutable AnyType instance;
    shared static this()
    {
        instance = new immutable AnyType;
    }
}

/++
+/
@tag(Tag.sumType)
final class SumType : Type
{
pure:
    ///
    immutable Type[] types;

    ///
    this(immutable Type[] types)
    {
        super(Tag.sumType);
        this.types = types;
    }
    
    override bool equals(const Type rhs) const
    {
        auto obj = rhs.downcast!SumType();
        if (obj is null)
            return false;
        if (types.length != obj.types.length)
            return false;
        foreach (a, type; obj.types)
        {
            if (!.equals(type, types[a]))
                return false;
        }
        return true;
    }
}

/++
+/
@tag(Tag.productType)
final class ProductType : Type
{
pure:
    ///
    immutable Type[] types;

    ///
    this(immutable Type[] types)
    {
        super(Tag.productType);
        this.types = types;
    }
    
    override bool equals(const Type rhs) const
    {
        auto obj = rhs.downcast!ProductType();
        if (obj is null)
            return false;
        if (types.length != obj.types.length)
            return false;
        foreach (a, type; obj.types)
        {
            if (!.equals(type, types[a]))
                return false;
        }
        return true;
    }
}

/++
+/
@tag(Tag.unknownType)
final class UnknownType : Type
{
pure:
    ///
    immutable string id;

    ///
    this(immutable string id)
    {
        super(Tag.unknownType);
        this.id = id;
    }
    
    override bool equals(const Type rhs) const
    {
        auto obj = rhs.downcast!UnknownType();
        return obj && id == obj.id;
    }
}

/++
+/
@tag(Tag.setType)
final class SetType : Type
{
pure:
    private this() immutable { super(Tag.setType); }

    ///
    static immutable SetType instance;
    shared static this()
    {
        instance = new immutable SetType;
    }
    
    override bool equals(const Type rhs) const
    {
        assert(this is instance, "Another SetType instance was created!");
        return this is rhs;
    }
}

/++
+/
@tag(Tag.typeofType)
final class TypeofType : Type
{
pure:
    ///
    immutable Expr expr;

    ///
    this(immutable Expr expr)
    {
        super(Tag.typeofType);
        this.expr = expr;
    }
    
    override bool equals(const Type rhs) const
    {
        auto obj = rhs.downcast!TypeofType();
        return obj && .equals(expr, obj.expr);
    }
}

/++
+/
@tag(Tag.inType)
final class InType : Type
{
pure:
    ///
    immutable Expr expr;

    ///
    this(immutable Expr expr)
    {
        super(Tag.inType);
        this.expr = expr;
    }
    
    override bool equals(const Type rhs) const
    {
        auto obj = rhs.downcast!InType();
        return obj && .equals(expr, obj.expr);
    }
    
    //static immutable InType naturals;
    //static immutable InType fulls;
    //static immutable InType reals;
    
    shared static this()
    {
        //naturals = cast(immutable) new InType(CollectionExpr.naturals);
        //fulls = cast(immutable) new InType(CollectionExpr.fulls);
        //reals = cast(immutable) new InType(CollectionExpr.reals);
    }
}

/++
+/
@tag(Tag.lambdaType)
final class LambdaType : Type
{
pure:
    ///
    immutable Type a;
    
    ///
    immutable Type b;

    ///
    this(immutable Type a, immutable Type b)
    {
        super(Tag.lambdaType);
        this.a = a;
        this.b = b;
    }
    
    override bool equals(const Type rhs) const
    {
        auto obj = rhs.downcast!LambdaType();
        return obj && .equals(a, obj.a) && .equals(b, obj.b);
    }
}
