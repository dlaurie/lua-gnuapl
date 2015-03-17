// lua_gnuapl.c   © 2015 Dirk Laurie  GPL, see COPYING

#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <complex.h>
typedef double complex Complex;

#include <lua.h>
#if LUA_VERSION_NUM == 501
#error Required Lua version is >=5.2, this is 5.1.
#endif
#if LUA_VERSION_NUM < 502
#error Required Lua version is >=5.2.
#endif

#include <lualib.h>
#include <lauxlib.h>

/* check string literals in luaL_argcheck calls that test MAX_RANK */
#define MAX_RANK 8
#define to_complex(L,arg) luaL_testudata(L, arg, "complex number");
#define new_userdata(L,name,var) name* var =\
 (name*) lua_newuserdata(L,sizeof(name))

// #include "extra.h"
#include <apl/libapl.h>
/* This header provides type "APL_value", which is a pointer to an opaque
   structure "Value". It's the ideal setup for a light userdata, but we
   would like to use metamethods, so it has to be a full userdata, even 
   though it contains just the one pointer.
*/
#define to_APL_value(L,arg) *(APL_value*) luaL_testudata(L, arg, "APL object")
#define checkAPL(L,arg) *(APL_value*) luaL_checkudata(L,arg,"APL object")
/* The userdata holds an APL_value, but the Lua C API functions
   return a pointer to it, which must be dereferenced. */


/* if a metatable for "complex number" exists, push a complex number,
   otherwise push a table with fields x,y. Such a metatable is made by 
   LHF's module `lcomplex`.
   <http://tecgraf.puc-rio.br/~lhf/ftp/lua/5.2/lcomplex.tar.gz> */
void pushcomplex(lua_State* L, double x, double y) {
#if LUA_VERSION_NUM == 502
  luaL_getmetatable(L,"complex number");
  if (!lua_isnoneornil(L,-1)) {
#else
  if (luaL_getmetatable(L,"complex number")) {
#endif
    lua_pop(L,1);
    new_userdata(L,Complex,p); 
    *p = (x,y);
    luaL_setmetatable(L,"complex number");
    return;
  }
  lua_pop(L,1);
  lua_newtable(L);
  lua_pushnumber(L,x);
  lua_setfield(L,-2,"x");
  lua_pushnumber(L,y);
  lua_setfield(L,-2,"y");
}

// The following function creates a new APL value, which must be released.
APL_value string_to_APL(const char* str) {
   if (strlen(str)==1) 
      return char_scalar(*(unsigned char*)str,LOC);
   else 
      return char_vector(str,LOC);
}

static int gnuapl_set(lua_State* L) {
  const char* str = luaL_checkstring(L,1);
  int err;
  Complex* Z;
  APL_value apl;
  if (lua_isnoneornil(L,2))
    err = set_var_value(str,NULL,NULL);
  if (lua_isboolean(L,2)) 
    err = set_var_value(str,int_scalar(lua_toboolean(L,2),LOC),LOC);
#if LUA_VERSION_NUM > 502
  else if (lua_isinteger(L,2)) 
    err =set_var_value(str,int_scalar(lua_tointeger(L,2),LOC),LOC);
#endif
  else if (lua_isnumber(L,2)) 
    err =set_var_value(str,double_scalar(lua_tonumber(L,2),LOC),LOC);
  else if (lua_isuserdata(L,2)) {
    Z=to_complex(L,2);
    if (Z) 
      err = set_var_value(str,complex_scalar(creal(*Z),cimag(*Z),LOC),LOC);
    else {
      apl = to_APL_value(L,2);
      if (apl) err = set_var_value(str,apl,LOC); 
      else luaL_error (L,"Can't convert type %s to APL",luaL_typename(L,2));
    }
  }
  else if (lua_isstring(L,2)) {
    apl = string_to_APL(lua_tostring(L,2)); 
    err = set_var_value(str,apl,LOC);
    release_value(apl,LOC);
  }
  else luaL_error (L,"Can't convert type %s to APL",luaL_typename(L,2));
  switch(err) {
  case 1: return luaL_error(L,"Illegal first character in name: %s",str);
  case 2: return luaL_error(L,"Illegal character in name: %s",str);
  case 3: return luaL_error(L,"Can't find name: %s",str);
  case 4: return luaL_error(L,"Name already in use for non-variable: %s",str);
  }
  return 0;
}

result_callback res_callback = 0;  // external variable for callback
static lua_State* saved_L = 0;     // needed inside the callback

int push_apl_output(const APL_value apl,int committed) {
  lua_pushstring(saved_L,print_value_to_string(apl));  
  return 0;
}

static int gnuapl_exec(lua_State* L) {
  saved_L = L;  
  res_callback = push_apl_output;
  apl_exec(luaL_checkstring(L,1));
  saved_L = NULL;
  res_callback = NULL;
  return 1;
}


/* The userdata holds an APL_value, but the Lua C API functions
   return a pointer to it, which must be dereferenced. */
void pushAPLvalue(lua_State *L, const APL_value apl) {
  new_userdata(L,APL_value,newapl);
  luaL_setmetatable(L,"APL object");
  *newapl = apl;
}

static int gnuapl_get(lua_State* L) {
  APL_value apl = (APL_value) get_var_value(luaL_checkstring(L,1),LOC);
  pushAPLvalue(L,apl);
  return 1;
} 

static int gnuapl_command(lua_State* L) {
  lua_pushstring(L,apl_command(luaL_checkstring(L,1)));
  return 1;
}

static int gnuapl_zeros(lua_State* L) {
  int rank = lua_gettop(L);
  int64_t axis[MAX_RANK];
  int k;
  int64_t v;  
  switch (rank) {
case 0: pushAPLvalue(L,apl_scalar(LOC)); return 1;
case 1: 
#if LUA_VERSION_NUM > 502
  if (lua_isinteger(L,1))
    pushAPLvalue(L,apl_vector(luaL_checkinteger(L,1),LOC)); 
  else 
#endif
  {
    luaL_checktype(L,1,LUA_TTABLE);
    rank = luaL_len(L,1);
    luaL_argcheck(L,0<=rank && rank<=MAX_RANK,1,"must be in range 0-8");
    for (k=1;k<=rank;k++) { 
       lua_rawgeti(L,1,k);
       v = luaL_checkinteger(L,-1);
       axis[k-1] = v;
       lua_pop(L,1);
    }
    pushAPLvalue(L,apl_value(rank,axis,LOC));
  }
return 1;
case 2: pushAPLvalue(L,apl_matrix(luaL_checkinteger(L,1),
   luaL_checkinteger(L,2),LOC)); return 1;
case 3: pushAPLvalue(L,apl_cube(luaL_checkinteger(L,1),
   luaL_checkinteger(L,2), luaL_checkinteger(L,3), LOC)); return 1;
default: return luaL_error(L,"zeros takes 0 to 3 arguments, got %d",rank);
  }
}

static int gnuapl_new(lua_State* L) {
  int t=lua_type(L,1);
  Complex* Z;
  APL_value apl;
  switch(t) {
case LUA_TBOOLEAN:
  pushAPLvalue(L,int_scalar(lua_toboolean(L,1),LOC)); 
  return 1;
case LUA_TNUMBER: 
#if LUA_VERSION_NUM > 502
   if (lua_isinteger(L,1)) 
      pushAPLvalue(L,int_scalar(lua_tointeger(L,1),LOC));
      else 
#endif
      pushAPLvalue(L,double_scalar(lua_tonumber(L,1),LOC)); 
   return 1; 
case LUA_TUSERDATA:
   Z=to_complex(L,1);
   if (Z) 
      pushAPLvalue(L,complex_scalar(creal(*Z),cimag(*Z),LOC));
   else 
      luaL_error (L,"Can't convert type %s to APL",luaL_typename(L,1));
   return 1;
case LUA_TSTRING:
   apl = string_to_APL(lua_tostring(L,1));
   pushAPLvalue(L,apl);
   return 1;
default: 
    luaL_error (L,"Can't convert type %s to APL",luaL_typename(L,1));
  }
}

static const luaL_Reg gnuapl_funcs [] = {
  {"exec",gnuapl_exec},
  {"command",gnuapl_command},
  {"get",gnuapl_get},
  {"set",gnuapl_set},
  {"zeros",gnuapl_zeros},
  {"new",gnuapl_new},
  {NULL,NULL}
};

// Check whether the index at stack position argno is valid for `apl`
// and adjust for origin-0
int checkindex(lua_State *L,APL_value apl,int argno) {
  int k = luaL_checkinteger(L,argno);
  if (k>0 && k <= get_element_count(apl)) return k-1;
  luaL_argcheck(L,(0<k && k<=get_element_count(apl)),argno,
    "index out of range");
}

static int APL_tostring(lua_State* L) {
  APL_value apl = checkAPL(L,1); 
  lua_pushstring(L,strdup(print_value_to_string(apl)));
  return 1;
} 

static int APL_index(lua_State* L) {
  APL_value apl = checkAPL(L,1);
  int k = checkindex(L,apl,2);
  int len;
  unsigned char buffer[8];
  switch (get_type(apl,k)) {
case CCT_CHAR:  
#if LUA_VERSION_NUM > 502
   lua_pushfstring(L,"%U",get_char(apl,k)); 
#else
   Unicode_to_UTF8(get_char(apl,k),buffer,&len);
   lua_pushstring(L,buffer);
#endif
   return 1;
case CCT_INT:   lua_pushinteger(L,get_int(apl,k)); return 1;
case CCT_FLOAT: lua_pushnumber(L,get_real(apl,k)); return 1;
case CCT_COMPLEX: pushcomplex(L,get_real(apl,k),get_imag(apl,k)); return 1; 
case CCT_POINTER: pushAPLvalue(L,get_value(apl,k)); return 1;
default: luaL_error(L,"Can't handle type %d",get_type(apl,k));  
  }
}

static int APL_len(lua_State* L) {
  lua_pushinteger(L,get_element_count(checkAPL(L,1)));
  return 1;
}

static int APL_rank(lua_State* L) {
  lua_pushinteger(L,get_rank(checkAPL(L,1)));
  return 1;
}

static int APL_axis(lua_State* L) {
  lua_pushinteger(L,get_axis(checkAPL(L,1),luaL_checkinteger(L,2)));
  return 1;
}

static int APL_newindex(lua_State* L) {
  APL_value apl = checkAPL(L,1);
  APL_value pav;
  int k = checkindex(L,apl,2);
  Complex* Z;
  switch (lua_type(L,3)) {
case LUA_TBOOLEAN:
  set_int(lua_toboolean(L,3),apl,k); break;
case LUA_TNUMBER: 
#if LUA_VERSION_NUM > 502
  if (lua_isinteger(L,2)) set_int(lua_tointeger(L,3),apl,k);
  else 
#endif
  set_double(lua_tonumber(L,3),apl,k); 
  break;
case LUA_TSTRING:
  pav = string_to_APL(lua_tostring(L,3));
  set_value(pav,apl,k);
  release_value(pav,LOC);
  break;
case LUA_TUSERDATA:
    Z=to_complex(L,3);
    if (Z) 
      set_complex(creal(*Z),cimag(*Z),apl,k);
    else {
      pav = to_APL_value(L,3);
      if (pav) set_value(pav,apl,k);
      else luaL_error (L,"Can't convert type %s to APL",luaL_typename(L,3));
    }
    break; 
default: luaL_error (L,"Can't convert type %s to APL",luaL_typename(L,3));
  }
  return 0;
}

static int APL_destructor(lua_State* L) {
  APL_value apl = checkAPL(L,1); 
  release_value(apl,LOC);
  return 0;
}    

static int APL_celltype(lua_State *L) {
  APL_value apl = checkAPL(L,1);
  int k = checkindex(L,apl,2); 
  lua_pushinteger(L,get_type(apl,k));  
  return 1;
}

static int APL_is_string(lua_State *L) {
  APL_value apl = checkAPL(L,1);
  lua_pushboolean(L,is_string(apl));  
  return 1;
}


static const luaL_Reg APL_funcs [] = {
  {"__index",APL_index},
  {"__len",APL_len},
  {"__newindex",APL_newindex},
  {"__tostring",APL_tostring},
  {"__gc",APL_destructor},
  {"celltype",APL_celltype},
  {"rank",APL_rank},
  {"axis",APL_axis},
  {"is_string",APL_is_string},
  {NULL,NULL}
};

LUAMOD_API int luaopen_gnuapl_core (lua_State *L) {

  init_libapl("gnuapl_core", /* do not log startup */ 0);

  luaL_newmetatable(L,"APL object");
  luaL_setfuncs(L,APL_funcs,0);

  lua_newtable(L);
  luaL_setfuncs(L,gnuapl_funcs,0);

  lua_insert(L,-2);
  lua_setfield(L,-2,"APL_metatable");

  return 1;
} 


