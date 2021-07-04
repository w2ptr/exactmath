# Grammar

```
Statement:
    Equation
    LambdaExpr
    "type" Type
    "type" Identifier "=" Type

// equations

Equation:
    ImpliesEquation
    TypeEquation
    MultiEquation
    CmpEquation

ImpliesEquation:
    MultiEquation "=>" MultiEquation

TypeEquation:
    LambdaExpr ":" Type

MultiEquation:
    OrEquation
    AndEquation

OrEquation:
    CmpEquation ("or" CmpEquation)+

AndEquation:
    CmpEquation (";" CmpEquation)+

CmpEquation:
    LambdaExpr "=" LambdaExpr
    LambdaExpr "!=" LambdaExpr
    LambdaExpr "<" LambdaExpr
    LambdaExpr "<=" LambdaExpr
    LambdaExpr ">" LambdaExpr
    LambdaExpr ">=" LambdaExpr
    "[" Equation "]"

// expressions

LambdaExpr: // right-associative: a -> b -> c = a -> (b -> c)
    ToExpr
    ToExpr "->" LambdaExpr

ToExpr:
    AddExpr
    ToExpr "to" AddExpr

AddExpr:
    MulExpr
    AddExpr "+" MulExpr
    AddExpr "-" MulExpr

MulExpr:
    UnaryExpr
    MulExpr "*" UnaryExpr
    MulExpr "/" UnaryExpr
    MulExpr "%" UnaryExpr
    UnaryExpr UnitExpr

UnaryExpr:
    PowExpr
    "-" UnaryExpr

PowExpr:
    PrimaryExpr
    PowExpr "^" PowExponent

// is unimplemented right now
PowExponent: // like UnaryExpr, just without nested PowExpr
   PrimaryExpr
    "-" PowExponent

PrimaryExpr:
    "(" LambdaExpr ")"
    TupleExpr
    ListExpr
    TestExpr
    PrimaryExpr "'"
    PrimaryExpr "." Identifier
    PrimaryExpr "[" Expr "]"
    PrimaryExpr "(" Expr ")"
    UnitExpr
    UnknownExpr
    LocalExpr
    IntExpr
    NumExpr
    "let" Equation "in" Expr // is unimplemented right now

ArgList:
    [LambdaExpr ("," LambdaExpr)* [","]] // trailing comma

TupleExpr:
    "(" ArgList ")"

ListExpr:
    "{" [ListElement ("," ListElement)* [","]] "}" // literals e.g. { 1, 2, 3 }
    "{" Expr "|" Equation "}" // with condition e.g. { x | x < 2 }

ListElement:
    "..."
    LambdaExpr

TestExpr:
    "test" Equation

UnitExpr:
    Identifier
    Identifier UnitExpr
    Identifier "^" UnaryExpr // e.g. 5 metre^3
    Identifier "^" UnaryExpr UnitExpr // e.g. 5 metre^2 second^-1

UnknownExpr:
    Identifier

LocalExpr:
    "$" Identifier

IntExpr:
    Digits

NumExpr:
    Digits "." Digits

// types

Type: // right-associative: A -> B -> C = A -> (B -> C)
    SumType "->" Type
    SumType

SumType:
    ProductType
    SumType "+" ProductType

ProductType:
    PrimaryType
    ProductType "*" PrimaryType

PrimaryType:
    Identifier
    "Any"
    "typeof" LambdaExpr
    "(" Type ")"
    "Collection"
    InType

InType:
    "in" LambdaExpr
```

Unresolved are `Identifier` and `Digits`. An Identifier is a string of alphanumerical characters or underscores (a-z, A-Z, 0-9, _) that doesn't start with a digit, and
`Digits` is a string of digits (0-9).
