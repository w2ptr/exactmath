# ExactMath: Symbolic math library and calculator

This repository consists of two parts.

The first part is the general underlying library, that is used to do parsing of the DSL, to perform operations and to output the result. It is mainly used for the calculator, but can be used as a stand-alone library as well.

The second part is the calculator that consists of a GUI (using the `dlangui` library) and a user interface to the `exactmath` library, which takes the math DSL as input and outputs a textual representation of the result. This calculator is implemented in the w2ptr/eqpad repository, of which the source code is currently private.

## Downloading

Go to [releases](https://github.com/w2ptr/exactmath/releases) for the latest download (includes `.exe` file for windows only currently).

## Required tools for development

Either the DMD or the LDC compiler is required to compile the source files and dependencies. Dub is not technically required, but it will simplify the build process a lot.

## Library

To use the library independently, clone the source folder, add the import path and use `import exactmath;`.

Almost all functions are `pure` and can be used without side-effects from the outside. `immutable` is generally used for expression objects. Parallellisation is currently not done, but could easily be added, since `immutable` makes objects safe to access among threads without requiring the use of mutexes.

## Small source guide

### Files

* `exactmath.ast.*`: the AST (statement, expression, type, equation) definition files.

* `exactmath.ops.*`: operations that can be performed on an AST.

* `exactmath.init`: small utility module for initialising some global state.

* `exactmath.lexer`: the lexer, which splits the input string into tokens (currently stolen from my generic lexer implementation). TODO: make one separate library of this.

* `exactmath.parser`: the parser, which interprets the tokens from the lexer and outputs an AST.

* `exactmath.state`: the state which keeps definitions and equations around.

* `exactmath.util`: generic utilities.

### Dependencies

The library currently uses the `openmethods` library for runtime double/triple matching of objects. For example, if an expression needs to be tried to be matched as a `CallExpr(f, AddExpr(x, y))`, this library takes care of that.
