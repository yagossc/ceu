LUA_EXE = ...
CEU_VER = '0.20'
CEU_GIT = ''
    do
        local f = assert(io.popen('git rev-parse HEAD'))
        CEU_GIT = string.sub(f:read'*a',1,-2)
        assert(f:close())
    end

if not LUA_EXE then
    io.stderr:write('Usage: <lua> pak.lua <lua>\n')
    os.exit(1)
end

local fout = assert(io.open('ceu','w'))
local fin  = assert(io.open'ceu.lua'):read'*a'

local function subst (name, returns)
    local s, e = string.find(fin, "dofile '"..name.."'")
    local src do
        if returns then
            src = '\n(function()\n' ..
                    assert(io.open(name)):read'*a' ..
                  '\nend)()\n'
        else
            src = '\ndo\n' ..
                    assert(io.open(name)):read'*a' ..
                  '\nend\n'
        end
    end
    fin = string.sub(fin, 1, (s-1)) .. src .. string.sub(fin, (e+1))
end

subst('optparse.lua', true)
subst 'dbg.lua'
subst 'cmd.lua'
subst 'pre.lua'
subst 'lines.lua'
subst 'parser.lua'
subst 'ast.lua'
subst 'adjs.lua'
subst 'types.lua'
subst 'dcls.lua'
subst 'names.lua'
subst 'exps.lua'
subst 'consts.lua'
subst 'stmts.lua'
subst 'inits.lua'
subst 'scopes.lua'
subst 'tight_.lua'
subst 'props_.lua'
subst 'trails.lua'
subst 'labels.lua'
subst 'vals.lua'
subst 'multis.lua'
subst 'mems.lua'
subst 'codes.lua'
subst 'env.lua'
subst 'cc.lua'

fout:write([=[
#!/usr/bin/env ]=]..LUA_EXE..[=[

--[[
-- This file is automatically generated.
-- Check the github repository for a readable version:
-- http://github.com/fsantanna/ceu
--
-- Céu is distributed under the MIT License:
--

Copyright (C) 2012-2016 Francisco Sant'Anna

Permission is hereby granted, free of charge, to any person obtaining a copy of
this software and associated documentation files (the "Software"), to deal in
the Software without restriction, including without limitation the rights to
use, copy, modify, merge, publish, distribute, sublicense, and/or sell copies
of the Software, and to permit persons to whom the Software is furnished to do
so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all
copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
SOFTWARE.

--
--]]

PAK = {
    lua_exe = ']=]..LUA_EXE..[=[',
    ceu_ver = ']=]..CEU_VER..[=[',
    ceu_git = ']=]..CEU_GIT..[=[',
    files = {
        ceu_c =
            [====[]=]..'\n'..assert(io.open'../c/ceu_vector.c'):read'*a'..[=[]====]..
            [====[]=]..'\n'..assert(io.open'../c/ceu_pool.c'):read'*a'..[=[]====]..
            [====[]=]..'\n'..assert(io.open'../c/ceu.c'):read'*a'..[=[]====],
    }
}
]=]..fin)

fout:close()
os.execute('chmod +x ceu')
