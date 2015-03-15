# makefile for lua-gnuapl

# Uncomment for Lua 5.2
INC=/usr/local/include/lua5.2 
LIBLUA=/usr/local/lib/lua/5.2
LUA=lua5.2
# Uncomment for default Lua, assumend to be Lus 5.3
#LUA=lua

CFLAGS = -fPIC -I$(INC) -no-integrated-cpp

.c.o: makefile
	cc $(CFLAGS) -c -o $*.o $*.c

OFILES = lua_gnuapl.o
AUXFILES = luatex-gnuapl.aux luatex-gnuapl.log

all: test README.html

gnuapl_core.so: makefile $(OFILES)
	cc -shared -pthread $(OFILES) -o gnuapl_core.so

tryme: makefile gnuapl.lua gnuapl_core.so
	$(LUA) -i -e"apl=require'gnuapl'"

test: makefile gnuapl.lua gnuapl_core.so test.lua doc
	$(LUA) test.lua

luatex-gnuapl.pdf: luatex-gnuapl.tex
	lualatex luatex-gnuapl.tex
	rm $(AUXFILES)

doc: README.html luatex-gnuapl.pdf

clean:
	- rm $(OFILES) gnuapl_core.so README.html

README.html: README.txt
	pandoc -s README.txt -o README.html

.PHONY: all clean doc test tryme



