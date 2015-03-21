-- gnuapl.lua © Dirk Laurie 2015, MIT licence, see COPYING 

assert (_VERSION == "Lua 5.2" or _VERSION == "Lua 5.3")

local mathtype = math.type or -- needed for Lua 5.2
   function(x)
      if type(x)~='number' then return nil end
      if math.floor(x)==x then return "integer"
      else return "float"
      end
   end

local LIB = "libapl.so"
local DIR = "/usr/local/lib/apl/"
local APL_name = '^%s*[_%a][_%w]*%s*$'
local APL_command = '^%s*[%)%]][a-zA-Z]+'
local APL_OFF = "^%s*%)OFF%s*$"

local is_loaded_library = {}
-- The functions in this table return the fully qualified name of the 
-- loaded library or `false`. WARNING: They rely on undocumented 
-- features of Lua 5.2.x (x>0) and Lua 5.3.0. 

is_loaded_library["Lua 5.2"] = function (LIB_NAME)
   for key,val in pairs(debug.getregistry()._CLIBS) do
      if type(key)=='string' and key:match(LIB_NAME..'$') then return key end
   end
   return false
end

is_loaded_library["Lua 5.3"] = function (LIB_NAME)
   for key,val in pairs(debug.getregistry()) do
      if type(key)=='userdata' and type(val)=='table' then 
         for k in pairs(val) do
            if type(k)=='string' and k:match(LIB_NAME..'$') then 
               return k 
            end 
         end 
      end 
   end
   return false
end

if not is_loaded_library[_VERSION](LIB) and 
   not package.loadlib(DIR..LIB,"*") then
   error(LIB.." has not been loaded.")
end

pcall(require,"complex")

local found,core = pcall(require,"gnuapl_core")

if not found then
   error("Could not find required module `gnuapl_core`.\n"..core)
end

local core_exec = core.exec
local core_command = core.command
local core_get = core.get
local core_set = core.set
local core_new = core.new
local core_zeros = core.zeros

local MAXRANK = tonumber(core.exec"⎕SYL[7;2]")
core.MAXRANK = MAXRANK

core.exec = function(str)
   if type(str)~="string" then 
     error("Bad argument #1 to 'exec': expected string, got "..type(str));
   end
   if str:upper():match(APL_OFF) then
      error([[)OFF detected in 'gnuapl.exec'. Use 'gnuapl.OFF()',]])
   end
   return (core_exec(str):gsub("\n$",""))
end

core.command = function(str)
   if type(str)~="string" then 
     error("Bad argument #1 to 'command': expected string, got "..type(str));
   end
   if str:upper():match(APL_OFF) then
      os.exit(true,true)
   else
      return core_command(str)
   end
end

core.ERASE = function(arg) return core_command(")ERASE "..(arg or "")) end
core.FNS = function(arg) return core_command(")FNS "..(arg or "")) end
core.HELP = function() return core_command(")HELP") end
core.IN = function(arg) return core_command(")IN "..(arg or "")) end
core.KEYB = function() return core_command("]KEYB ") end
core.LOAD = function(arg) return core_command(")LOAD "..(arg or "")) end
core.SAVE = function(arg) return core_command(")SAVE "..(arg or "")) end
core.OUT = function(arg) return core_command(")OUT "..(arg or "")) end
core.VARS = function(arg) return core_command(")VARS "..(arg or "")) end
core.WSID = function(arg) return core_command(")WSID") end
core.OFF = function() print"Goodbye.";  os.exit() end

core.type = function(var)
  local mt = getmetatable(var)
  local name
  if mt then name=mt.__name end
  return name or type(var)
end

local function linecount(h)
   return select(2,h:gsub("[^\n]*",""))
end

core.what = function(tbl)
   if type(tbl)~="table" then error(
     ("Bad argument #1 to 'what': expected table, got %s"):format(type(tbl)))
   end
   local keys = {}
   local maxlen = 0
   local h
   for k in pairs(tbl) do if not tonumber(k) then
      keys[#keys+1] = k
      if #k>maxlen then maxlen = #k end
   end end
   if maxlen>60 then return table.concat(keys,"\n") end
   table.sort(keys)
   local apl_keys = core.new(keys)
   core_set("keys",apl_keys)
   for rows=1,15 do
      local cols=math.ceil(#keys/rows)
      local h = core_exec(("⍉%d %d⍴%d↑keys"):format(cols,rows,cols*rows))
      if #h<80 or linecount(h)==2*rows+1 then return h end
   end
end

local APL_mt = core.APL_metatable
local APL_index = APL_mt.__index

APL_mt.__index = function(self,index)
  if type(index)=="number" then return APL_index(self,index)
  else return APL_mt[index]
  end
end

APL_mt.shape = function(val)
   local rank=val:rank()
   local shape={}
   for k=1,rank do shape[k]=val:axis(k-1) end
   return shape
end

local apl2lua
apl2lua = function(apl)
  if apl:is_string() then return tostring(apl) end
  local n = #apl
  local t = {shape=apl:shape()}
  for k=1,n do
    local a=apl[k]
    if core.type(a)=="APL object" then 
       t[k]=apl2lua(a) 
    else
       t[k]=a
    end
  end
  if apl:rank()==0 then t=t[1] end
  return t
end

local lua2apl
lua2apl = function(lua)
   if core.type(lua)=="APL object" then return lua end
   if type(lua)~='table' then return core_new(lua) end
   local n
   local shape = lua.shape or {#lua}
   if type(shape)~='table' then error"field 'shape' must be a table" end
   local len=1
   for k,v in pairs(shape) do
      if k>MAXRANK then
         error("shape must not have more than "..MAXRANK.." elements")
      elseif mathtype(v)~='integer' or v<0 then
         error"shape element must be a non-negative integer"
      end
      len = len*v
   end
   local apl = core_zeros(shape)
   local default
   if type(lua[1]) == 'string' then default=' ' else default=0 end
   for k=1,len do 
      apl[k] = lua2apl(lua[k] or default)
   end
   return apl
end

core.set = function(name,val)
   if type(val)=="table" then val = lua2apl(val) end
   core_set(name,val)
end
   
core.new = lua2apl

APL_mt.lua = apl2lua
local APL_tostring = APL_mt.__tostring
APL_mt.__tostring = function(obj)
   return (APL_tostring(obj):gsub("\n$",""))
end
APL_mt.__name = APL_mt.__name or "APL object"  -- needed for Lua 5.2

core.lua = function(str) return core_get(str):lua() end

local celltype = APL_mt.celltype
APL_mt.celltype = function(var,idx)
   local ct = celltype(var,idx)
   return ({[0x02]='char', [0x04]='pointer', [0x10]='int',
     [0x20]='float', [0x40]='complex'})[ct] or ct
end
   
setmetatable(core,{__call = function(self,str) return core_exec(str) end})

core.texeval = 
function(str,option)
   option = option or 3
   local preamble = ""
   local result = apl.exec(str):gsub("[^\n]+","\\verb$%0$\\\\")
   if option%2>0 then preamble = "\\verb$      "..str.."$\\\\" end
   if option<2 then result = "" end
   return "\\noindent  \\\\" ..preamble..result
end 


return core

