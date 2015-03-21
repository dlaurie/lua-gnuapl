`gnuapl`: Lua interface to GNU APL
==================================
 
The module `gnuapl` allows a running Lua program to communicate with 
a GNU APL interpreter (referred to as `APL`) loaded from a shared library.

The following services are provided.

1. Pass a C string to the interpreter for immediate execution as APL code.
2. Pass an APL command to the command processor and return its output.
3. Create a userdata with registry name "APL object" containing a pointer 
   to an APL value, with many access methods.
4. Construct an APL object initialized by the contents of a variable in 
   the current workspace.
5. Set the contents of a variable in the workspace to that of a given APL 
   object.

See INSTALL for installation instructions. The file `gnuapl.lua` must
be in your `package.path` and the file `gnuapl_core.so` in your
`package.cpath`.

This document is not a tutorial on APL or on Lua. Familiarity with 
both is assumed.

Loading the module
------------------

Simply put

    gnuapl = require"gnuapl"

If successful, you will also have loaded the APL shared library 
`libapl.so`. This library provides an APL interpreter, initialized with
a clear workspace, that expects to communicate via the usual standard 
input, output and error channels. Lua intercepts standard input, so 
`gnuapl` communicates with the APL interpreter by function calls instead, 
but the other two channels are shared between Lua and APL.

It may happen that you get the message "libapl.so has not been loaded". 
This can be solved in two ways:

a. Load the APL library yourself before requiring `gnuapl` with

        package.loadlib(FULL_FILENAME_OF_SHARED_LIBRARY,"*")

b. Edit `gnuapl.lua` so that the the variables `LIB` and `DIR` are
right for your installation.

Using the module
================

The returned value `gnuapl` is a table of functions.

`res = gnuapl.exec(apl_code)`
~   `apl_code` is passed to the APL interpreter, which will deal with it 
    as if entered from standard input. You have full access to all of GNU APL 
    through this function, including system commands (except `)OFF`) and 
    debug commands. 

    Printing of the result from APL is disabled. Instead, the string
    representation of the final value (which is no longer accessible) is 
    returned, even if APL would not have printed it. The final line break
    is trimmed off.
    
    APL may write to standard output or standard error, which will appear 
    interspersed with what Lua writes. APL functions like `⎕`, `⍞` and `∇`
    read from standard input.
 
    If the APL code appears to be an attempt to execute the command `)OFF`,
    an error message is issued (see below under `gnuapl.OFF()`. The
    check is straightforward; no attempt has been made to intercept 
    ingenious ways of smuggling `)OFF` through.

`gnuapl(apl_code)`
~   Same as `gnuapl.exec(apl_code)` (via `__call` metamethod).

`gnuapl.new(val)`
~   Returns a new APL object initialized with the given Lua value 
    (boolean, number, complex, UTF-8 string, table), converted as 
    described under [Correspondence between APL objects and Lua values]. 
    If the conversion fails, an error message is returned.

`gnuapl.zeros([arg1 [,arg2 [,arg3]])`
~   Returns a new APL object containing only zeros. If all the arguments
    are integers, they define the axes of an object of rank 0, 1,
    2 or 3. If `arg1` is a table, the table elements are used instead
    of the argument list to define the shape.

`gnuapl.get(apl_name)`
~   Returns a new APL object initialized from the APL variable 
    `name`. If no such APL variable exists, returns `nil`.

`gnuapl.set(apl_name,val)`
~   Stores an APL object in the workspace as `name`. If 
    `name` is not a valid name, an error is raised.

`gnuapl.lua(apl_name)`
~   Same as `gnuapl.get(apl_name):lua())`.

`gnuapl.command(apl_command)`
~   The given APL scommand (except `)OFF`) is executed and its output 
    returned. There are about 50 commands (use `gnuapl.HELP()`). 
    Shortcuts (below) are provided for the more commonly used commands.

`gnuapl.VARS()` etc
~   Same as `gnuapl.command")VARS"` etc. The commands available this way 
    are ERASE, FNS, HELP, IN, KEYB, LOAD, OUT, SAVE, VARS, WSID.

`gnuapl.OFF()` 
~   Terminates the Lua program, but not via the APL command `)OFF`,
    which is disabled. The reason is that APL does not know about Lua, 
    and will not close the Lua state, including closing of the APL 
    session. Unlike the APL interpreter, the Lua interpreter can also 
    be stopped cleanly by Ctrl-D.

`gnuapl.type(val)`
~   Returns the contents of the metafield `__name` if any, otherwise returns
    `type(val)`. In particular, returns `APL object` if `val` is an APL 
    object.

`gnuapl.what(tbl)`
~   Returns a sorted list of non-numeric keys in `tbl`. Thus `gnuapl:what()`
    gives a sorted list of keys in `gnuapl`.

`gnuapl.APL_metatable`
~   The metatable associated with APL objects.

`gnuapl.MAXRANK`
~   The maximum allowed value for the rank of an APL object. Other
    system limits can be queried by `apl"⎕SYL".

`gnuapl.texeval(str,option)`
~   Returns the APL code in `str` and/or the result of evaluating it,
    formatted for inclusion in a `lualatex` source file. More details
    are provided in the file `gnuapl.tex`.

Methods of an APL object `val`
-----------------------------
 
`val.__name`
~   A metafield containing `APL object`.

`val.__tostring`
~   Returns the string representation. The final line break is trimmed off.

`val.__is_string`
    Tests whether `val` is a simple string, i.e. every element is one 
    32-bit Unicode character. 

`val.__len`
~   The range of valid indices into the APL object `val` ranges from 
    1 to `#val`.

`val.__index`
~   `val[idx]` returns element `idx` of the APL object `val` as a Lua 
    value of `number`, `string`, or `userdata`. That is to say, if the 
    element is a nested array, it is not converted, but returned as an 
    APL object, except when it is a simple string.

`val.__newindex`
~   `val[idx]=val` replaces element `idx` of the APL object `val` by 
    a new APL object constructed from the given value, converting Lua 
    values of type `number`, `string` and `table`.

`val:lua()`
~   Recursively convert an entire APL object to an equivalent Lua 
    object which is returned.

`val:rank()`
    Returns the rank of object `val`.

`val:axis(k)`
     Returns the extent of the `k`-th axis of object `val`.

`val:shape()`
    Return a table containing the shape of object `val`.

`val:celltype(idx)`
    Return the type of element `idx` of object `val`. Possible return
    values are `char`, `int`, `float`, `complex` and `pointer`. If the
    cell contains none of those, return an integer giving the C value 
    of the offending type.

As is usual in Lua, the normal methods may also be called as e.g. 
`val.rank(obj)`, where `obj` may be any APL object, not only `val` itself.

See `test.lua` for examples.

Correspondence between APL objects and Lua values
-------------------------------------------------

The following table shows how `val.lua`, `gnuapl.new`, etc., do their 
conversions.

     APL                                  Lua
-----------------------  ----  -------------------------------------
Rank 0, character        <===   string, one byte (0x00–0xFF)
Rank 0, character        ===>   string, one UTF-8 codepoint
Rank 0, integer, 0/1     <===   boolean
Rank 0, integer-valued   ===>   integer [1]
Rank 0, integer          <===   integer-valued
Rank 0, double           <==>   number   
Rank 0, complex          <==>   complex [2]
Rank 1                   <==>   table [3]
Rank 1, all character    <==>   string, treated as UTF-8 codepoints
Rank >1                  ===>   table with `shape` field [3]
Any rank                 <===   table with `shape` field [3]

1. In Lua 5.3, that is. In Lua 5.2, there is no distinction between 
`integer` and `number`.
2. `complex` is a userdata, see below.
3. During Lua-to-APL conversion, the `shape` field defines the length
of the ravel, except when `shape` is absent, in which case the 
`len` operator is invoked. All fields outside the range except 
`shape` are silently ignored. The value of `shape` must be a proper 
sequence containing non-negative integers. If any element is `nil`,
it will be replaced by a blank if the first element is of type
`string` and by 0 otherwise.

Complex numbers
---------------

Since Lua 5.3 has no complex numbers, `gnuapl` tries to load LHF's 
module `lcomplex`, which supplies C99 complex numbers as a userdata 
with registry name "complex number".

If this module could not be loaded, loading of `gnuapl` will not
fail, but APL-to-Lua conversion will represent a complex number as 
a table of length 0 with keys `x` and `y`. Lua-to-APL conversion
of such a table will produce an empty vector, not a complex number.

Gotchas
-------

Things that the casual user might not expect: 

1. If `gnuapl.exec` is given a system command, its output is printed by 
APL but not returned to Lua. If you want its output returned, use 
`gnuapl.command` instead. You might not notice the difference, since Lua 
5.3 will by default print a returned value.

2. If you try to get a subscripted name by `gnuapl.get`, an error will 
be raised, since e.g. `a[1 2;3]` is not the name of an APL variable. 
If you give a subscripted name to `gnuapl.exec` its value will be printed 
but not returned. See item 1 above. You must first get the whole object 
and then access its parts by indexing.


Mapping of `libapl.h` to `lua_gnuapl.c` and `gnuapl.lua`
========================================================

        libapl.h             lua_gnuapl.c          gnuapl.lua 
    --------------------     -------------------  -------------------------
     apl_exec                 gnuapl_exec          gnuapl.exec 
     apl_command              gnuapl_command       gnuapl.command 
     get_var_value            gnuapl_get           gnuapl.get 
     int_scalar               gnuapl_new           gnuapl.new 
     double_scalar            gnuapl_new           gnuapl.new 
     complex_scalar           gnuapl_new           gnuapl.new 
     char_scalar              gnuapl_new           gnuapl.new 
     char_vector              gnuapl_new           gnuapl.new 
     apl_scalar               gnuapl_zeros         gnuapl.zeros() 
     apl_vector               gnuapl_zeros         gnuapl.zeros(d1) 
     apl_matrix               gnuapl_zeros         gnuapl.zeros(d1,d2) 
     apl_cube                 gnuapl_zeros         gnuapl.zeros(d1,d2,d3) 
     apl_value                gnuapl_zeros         gnuapl.zeros(shape) 
     release_value            APL_destructor       __gc 
     get_rank                 APL_rank             val.rank 
     get_axis                 APL_axis             val.axis 
     get_element_count        APL_len              __length 
     get_type                 APL_celltype         val.celltype 
     is_string                is_string            is_string
     is_char                 not needed           not needed
     is_int                  not needed           not needed
     is_double               not needed           not needed
     is_complex              not needed           not needed
     is_value                not needed           not needed
     get_char                 APL_index            __index 
     get_int                  APL_index            __index 
     get_real                 APL_index            __index 
     get_imag                 APL_index            __index 
     get_value                APL_index            __index 
     set_char                 APL_newindex         __newindex 
     set_int                  APL_newindex         __newindex  
     set_double               APL_newindex         __newindex  
     set_complex              APL_newindex         __newindex   
     set_value                APL_newindex         __newindex  
     set_var_value            gnuapl_set           gnuapl.set  
     print_value             debugging only       not needed
     print_value_to_string    APL_tostring         __tostring 
     UTF8_to_Unicode         not needed           not needed
     Unicode_to_UTF8         not needed           not needed
     res_callback             gnuapl_exec         not needed
    
