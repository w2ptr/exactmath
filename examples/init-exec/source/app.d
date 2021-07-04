module app;

void main()
{
    import exactmath;
    
    auto x = parseMathExpression("(1 + 2) * ln(2)");
    writeln("(1 + 2) * ln(2) = ", x.calc());
}

