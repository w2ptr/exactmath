/++
+/
module exactmath.init;

/++
+/
void initMath() pure
{
    import openmethods : updateMethods;
    import exactmath.ast.base : dbg;
    import exactmath.util : assumePure;
    
    assumePure!updateMethods();
    debug
    {
        if (dbg is null)
            dbg = (string s) {};
    }
}
