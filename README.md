Lua interface to GNU APL
========================

The module `gnuapl` allows a running Lua program to communicate with a GNU APL interpreter (referred to as `APL`) loaded from a shared library.

The following services are provided.

1. Pass a C string to the interpreter for immediate execution as APL code.
2. Pass an APL command to the command processor and return its output.
3. Create a userdata with registry name "APL object" containing a pointer to an APL value, with many access methods.
4. Construct an APL object initialized by the contents of a variable in the current workspace.
5. Set the contents of a variable in the workspace to that of a given APL object.

