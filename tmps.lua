local VARS = {}

if not ANA then
    return          -- isTmp=false for all vars
end

F = {
    Dcl_var_pre = function (me)
        local var = me.var

        if var.cls then
            VARS = {}       -- org dcls eliminate all current possible tmps
            return
        end

        if var.pre~='var' or var.cls or var.inTop then
            return                  -- only normal vars can be tmp
        end

        VARS[var] = true
        if var.isTmp ~= false then  -- already preset as false
            var.isTmp = true
        end

        if AST.par(me,'Dcl_adt') then
            var.isTmp = false
        end

        -- inside a recursive loop
        -- TODO: check if tmp is crossed by "recurse" (otherwise could be tmp)
        for loop in AST.iter'Loop' do
            if loop.iter_tp == 'data' then
error'not implemented (locals inside iter)'
                var.isTmp = false
                break;
            end
        end
    end,

    Var_pos = function (me)
        -- force __ceu_adt_* to be tmp
        -- (even if in top level block)
        if string.sub(me.var.id,1,10) == '__ceu_adt_' then
            me.var.isTmp = true
        end

        -- force __ceu_adt_root_* not to be tmp
        --[[
        -- TODO (-RAM)
        -- Could be tmp if we kill/free the "to" branch before
        -- allocating the new subtree.
        -- This would also allow more allocation (i.e., free->alloc).
        --]]
        if string.sub(me.var.id,1,15) == '__ceu_adt_root_' then
            me.var.isTmp = false
        end
    end,
    Var = function (me)
        local var = me.var

        -- uses inside threads
        local thr = AST.iter'Thread'()
        if thr then
            if me.var.blk.__depth < thr.__depth then
                var.isTmp = false
                return              -- defined outside: isTmp=false
            else
                return              -- defined inside: isTmp=true
            end
        end

        -- all function vars are "tmp"
        if AST.iter'Dcl_fun'() then
            return
        end

        -- only normal vars can be tmp
        if var.pre~='var' or var.cls then
            var.isTmp = false
            return
        end

        --[[
        --  var int i;
        --  var T[2] t with
        --      i = i + 1;      // "i" cannot be tmp
        --  end;
        --]]
        local constr = AST.par(me, 'Dcl_constr')
        if constr and (var.blk.__depth < constr.__depth) then
            local org = AST.par(me, 'Dcl_var')
            if org then
                local _, tp = unpack(org)
                if tp.arr then
                    var.isTmp = false
                end
            end
        end

        local glb = ENV.clss.Global
        if var.inTop or
            (var.blk==ENV.clss.Main.blk_ifc and glb and glb.is_ifc and
             glb.blk_ifc.vars[var.id])
        then
            var.isTmp = false
            return                  -- vars in interfaces cannot be tmp
        end

        local dcl = AST.iter'Dcl_var'()
        if dcl and dcl[1]==var.id then
            return                  -- my declaration is not an access
        end

        if me.__par.tag == 'SetBlock' then
            return                  -- set is performed on respective `return´
        end

        local v = VARS[var]

        local op = AST.iter'Op1_&'()
        local isRef = op and (op.base == me)

        local AwaitInt = function ()
            local n = AST.iter'Await'()
            return n and n[1].tag~='Ext'
        end

        if AST.iter'Finally'() or   -- finally executes through "call"
           AwaitInt() or            -- await ptr:a (ptr is tested on awake)
           isRef or                 -- reference may escape
           var.tp.arr               -- array may escape: TODO conservative
                                    -- (arrays as parameters)
        then
            var.isTmp = false
            VARS[var] = nil
            return
        end

        -- Not tmp if defined in the same block of an org:
        --      var T t;
        --      var int ret = 1;
        -- becomes
        --      var int ret;
        --      start t
        --      ret = 1;
        for _,oth in pairs(var.blk.vars) do
            if oth.cls then
                v = false
            end
        end

        if v == true then
            VARS[var] = me.ana.pre
            return                  -- first access
        end

        if not (v and ANA.CMP(v,me.ana.pre)) then
            var.isTmp = false       -- found a Par or Await in the path
            return
        end
    end,

    ['Op1_&'] = function (me)
        local op, e1 = unpack(me)
        if e1.fst.var then
            e1.fst.var.isTmp = false    -- assigned to a pointer
        end
    end,
    Set = function (me)
        local _, _, fr = unpack(me)
        if fr.byRef and fr.fst.var then
            fr.fst.var.isTmp = false    -- assigned to a pointer
        end
    end,

    EmitNoTmp = 'EmitInt',
    EmitInt = function (me)
        VARS = {}   -- NO: run in different ceu_call
    end,
    EmitExt = function (me)
        local op, ext, param = unpack(me)
        local evt = ext.evt
        if evt.pre == 'input' then
            VARS = {}
        end
    end,

    Spawn_pre = function (me)
        VARS = {}   -- NO: start organism
    end,

    Loop_pre = function (me)
        local awaits = false
        AST.visit(
            {
                Await = function (me)
                    awaits = true
                end,
                AwaitN   = 'Await',
                EmitInt  = 'Await',
                Async    = 'Await',
                Thread   = 'Await',
                Spawn    = 'Await',
            },
            me)

        if ((not awaits) and (not AST.iter(AST.pred_async)())) or
            me.isAwaitUntil then
            return      -- OK: (tight loop outside Async) or (await ... until)
        end
        VARS = {}       -- NO: loop in between Dcl/Accs is dangerous
        --[[
            -- x is on the stack but may be written in two diff reactions
            -- a non-ceu code can reuse the stack in between
            input int E;
            var int x;
            loop do
                var int tmp = await E;
                if tmp == 0 then
                    break;
                end
                x = tmp;
            end
            return x;
        ]]
    end,
--[[
]]

    ParOr_pre = function (me)
        for var, v in pairs(VARS) do
            if v ~= true then
                VARS[var] = nil     -- remove previously accessed vars
            end
        end
    end,
    ParAnd_pre  = 'ParOr_pre',
    ParEver_pre = 'ParOr_pre',
    ParOr   = 'ParOr_pre',
    ParAnd  = 'ParOr_pre',
    ParEver = 'ParOr_pre',

    -- TODO: should pre's be already different?
    Async_pre = 'ParOr_pre',
    Async     = 'ParOr_pre',
}

AST.visit(F)
