# makefile for lua-gnuapl  
# If you must, read INSTALL and LICENSE too.

# Uncomment one of the following two lines. 
LUA_VERSION=5.2
#LUA_VERSION=5.3
# ----------------------------------------

#    Targets
# test: build the shared library and run the test program
# install: install the Lua and C modules systemwide (requires root access)
# tryme: start a Lua session with the module preloaded
# doc: make HTML (requires Pandoc) and PDF (requires 5.2 and LuaLaTeX)
# clean: remove files that can be re-made
default: test 

LUA=lua$(LUA_VERSION)
LIBLUA=/usr/local/lib/lua/$(LUA_VERSION)
SHARE=/usr/local/share/lua/$(LUA_VERSION)
INC=/usr/local/include/lua$(LUA_VERSION)

CFLAGS = -fPIC -I$(INC) -no-integrated-cpp

.c.o: makefile
	cc $(CFLAGS) -c -o $*.o $*.c

OFILES = lua_gnuapl.o
AUXFILES = luatex-gnuapl.aux luatex-gnuapl.log
DOCFILES = README.html luatex-gnuapl.pdf
MODULE_FILES =  makefile gnuapl.lua gnuapl_core.so

gnuapl_core.so: makefile $(OFILES)
	cc -shared -pthread $(OFILES) -o gnuapl_core.so

tryme: $(MODULE_FILES)
	#### Try out 'gnuapl' module using *installed* packages
	$(LUA) -i -e"apl=require'gnuapl'"

test: $(MODULE_FILES) test.lua
	#### Test 'gnuapl' module using *local* packages (i.e. in PWD)
	$(LUA) test.lua

ifeq ($(LUA_VERSION),5.2)
luatex-gnuapl.pdf: luatex-gnuapl.tex $(MODULE_FILES)
	lualatex luatex-gnuapl.tex
	rm $(AUXFILES)
endif

doc: $(DOCFILES)

clean:
	- rm $(OFILES) gnuapl_core.so $(DOCFILES)

README.html: README.txt
	pandoc -s README.txt -o README.html

install: $(MODULE_FILES)
	cp gnuapl.lua $(SHARE)
	cp gnuapl_core.so $(LIBLUA)

.PHONY: clean default doc install test tryme texinstall

#--------- targets below this message are for the convenience of the
#--------- package maintainer and will need editing on other machines

ifeq ($(LUA_VERSION),5.2)
texinstall: $(MODULE_FILES)
	ln -s $(SHARE)/gnuapl.lua ~/texmf/scripts/lua
	ln -s $(LIBLUA)/gnuapl_core.so ~/texmf/clua
endif

GITFILES = INSTALL LICENSE README.txt gnuapl.lua lua_gnuapl.c luatex-gnuapl.tex makefile test.lua

git-add: $(GITFILES)
	git add $(GITFILES)
	echo "Now 'git commit -m "message"' and 'git push'."



