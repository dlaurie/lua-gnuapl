package.path = "./?.lua"
package.cpath = "./?.so"
apl = require "gnuapl"
keyboard = [[
US Keyboard Layout:

╔════╦════╦════╦════╦════╦════╦════╦════╦════╦════╦════╦════╦════╦═════════╗
║ ~  ║ !⌶ ║ @⍫ ║ #⍒ ║ $⍋ ║ %⌽ ║ ^⍉ ║ &⊖ ║ *⍟ ║ (⍱ ║ )⍲ ║ _! ║ +⌹ ║         ║
║ `◊ ║ 1¨ ║ 2¯ ║ 3< ║ 4≤ ║ 5= ║ 6≥ ║ 7> ║ 8≠ ║ 9∨ ║ 0∧ ║ -× ║ =÷ ║ BACKSP  ║
╠════╩══╦═╩══╦═╩══╦═╩══╦═╩══╦═╩══╦═╩══╦═╩══╦═╩══╦═╩══╦═╩══╦═╩══╦═╩══╦══════╣
║       ║ Q  ║ W⍹ ║ E⋸ ║ R  ║ T⍨ ║ Y¥ ║ U  ║ I⍸ ║ O⍥ ║ P⍣ ║ {⍞ ║ }⍬ ║  |⊣  ║
║  TAB  ║ q? ║ w⍵ ║ e∈ ║ r⍴ ║ t∼ ║ y↑ ║ u↓ ║ i⍳ ║ o○ ║ p⋆ ║ [← ║ ]→ ║  \⊢  ║
╠═══════╩═╦══╩═╦══╩═╦══╩═╦══╩═╦══╩═╦══╩═╦══╩═╦══╩═╦══╩═╦══╩═╦══╩═╦══╩══════╣
║ (CAPS   ║ A⍶ ║ S  ║ D  ║ F  ║ G  ║ H⍙ ║ J⍤ ║ K  ║ L⌷ ║ :≡ ║ "≢ ║         ║
║  LOCK)  ║ a⍺ ║ s⌈ ║ d⌊ ║ f_ ║ g∇ ║ h∆ ║ j∘ ║ k' ║ l⎕ ║ ;⍎ ║ '⍕ ║ RETURN  ║
╠═════════╩═══╦╩═══╦╩═══╦╩═══╦╩═══╦╩═══╦╩═══╦╩═══╦╩═══╦╩═══╦╩═══╦╩═════════╣
║             ║ Z  ║ Xχ ║ C¢ ║ V  ║ B£ ║ N  ║ M  ║ <⍪ ║ >⍙ ║ ?⍠ ║          ║
║  SHIFT      ║ z⊂ ║ x⊃ ║ c∩ ║ v∪ ║ b⊥ ║ n⊤ ║ m| ║ ,⍝ ║ .⍀ ║ /⌿ ║  SHIFT   ║
╚═════════════╩════╩════╩════╩════╩════╩════╩════╩════╩════╩════╩══════════╝

]]

print("=== Test suite evaluated under ".._VERSION.." ===")
print()
print("Module 'gnuapl' contains:")
print(apl:what())
print"The above table is obtained by 'apl_what()'.\n"
print("APL_metatable contains:")
print(apl.what(apl.APL_metatable))


local _ENV = setmetatable({},{__index=_G})

alltests = true

preliminaries = [[
]]

for task in preliminaries:gmatch"[^\n]+" do
   if task:match"%S" then
      
   end
end

tests = [[
apl.MAXRANK == 8
-- boolean constructor
apl.new(true)[1] == 1
-- string constructor from one-byte string makes scalar
! hat_i = apl.new(string.char(238))
hat_i:rank() == 0
-- but APL scalars may be indexed
hat_i[1] == 'î'
-- string constructor from UTF-8 encoding string makes vector
! hat_i = apl.new'î'
hat_i:rank() == 1
hat_i[1] == 'î'
-- table constructor
!C = apl.new{"the","quick","brown","fox","jumps","over","the","lazy","dog"}
apl.type(C) == 'APL object'
C:is_string() == false
C:celltype(1) == 'pointer'
-- workspace retrieval
apl.exec"A←2 3⍴⍳6" == "1 2 3\n4 5 6"
apl.get"A"[4] == 4
-- three-dimensional array
#apl.zeros(3,4,5) == 60 
-- return value from apl.exec ends in newline
apl"1 2 3 ○ (○÷6),(○1),○÷4" == "0.5 ¯1 1\n"
-- A simple string can have elements that translate to multi-byte strings
! D = apl.new"A←2 3⍴⍳6"
D:is_string() == true
D[2] == '←'
table.concat({D[2]:byte(1,6)},",") == "226,134,144"
-- table workspace assignment
apl.set("S",{"abc",{3,1,4,1,5,9},3.14159,C}) == nil
apl.get"S"[2][5] == 5
apl.get"S":celltype(4) == "pointer"
-- demonstration that C and S[4] are now different
! C[3]="red"
apl.get"S"[4]:celltype(3) == "pointer"
tostring(apl.get"S"[4][3]) == "brown"
--
apl.WSID() == "IS CLEAR WS\n"
--
apl"midpoint_rule ← { ((2÷⍵)×⍵⍴1) ,[0.5] ¯1+(2÷⍵)×¯0.5+⍳⍵ }" == "midpoint_rule\n"
apl"midpoint_rule 10"
apl"integrated_by ← { ⍵[1;] +.× ⍶ ⍵[2;] }" == "integrated_by\n"
apl"* integrated_by midpoint_rule 10" == "2.346489615\n"
]]

for test in tests:gmatch"[^\n]+" do
   if test:match"^!" then
      test = test:sub(2)
      load(test,nil,nil,_ENV)()
      print ("Did: "..test)
   elseif test:match"^%-%-" then
      print(test)
   else
      local result = load('return '..test,nil,nil,_ENV)()
      if result then
         print ("Passed:  "..test)
      else
         result = load('return '..test:gsub("==.*",""),nil,nil,_ENV)() or ""
         print ("Failed:  "..test.." ("..tostring(result)..")")
         alltests = false
      end
   end
end

if alltests then print"All tests passed"
else print"Some tests failed: see above"
end

for k,v in pairs(_ENV) do _ENV[k]=nil end
collectgarbage()

print("\n Running check whether all APL values have been released\n")

apl.command")CHECK"

-- The value that C[3] had before the assignment `C[3] = "red"` has
-- not been released.


