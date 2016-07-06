LABELS = {
    list = {},      -- { [lbl]={}, [i]=lbl }
}

local function new (lbl)
    if lbl[2] then
        lbl.id = 'CEU_LABEL_'..lbl[1]
    else
        lbl.id = 'CEU_LABEL_'..lbl[1]..'_'..#LABELS.list
    end
    LABELS.list[lbl] = true
    lbl.n = #LABELS.list                   -- starts from 0
    LABELS.list[#LABELS.list+1] = lbl

    return lbl
end

F = {
    ROOT__PRE = function (me)
        me.lbl_in = new{'ROOT', true}
    end,

    Do = function (me)
        local _,_,set = unpack(me)
        me.lbl_out = new{'Do'}
    end,

    ---------------------------------------------------------------------------

    Par_Or__PRE  = 'Par__PRE',
    Par_And__PRE = 'Par__PRE',
    Par__PRE = function (me)
        me.lbls_in = {}
        for i, sub in ipairs(me) do
            me.lbls_in[i] = new{me.tag..'_sub_'..i}
        end
        if me.tag ~= 'Par' then
            me.lbl_out = new{me.tag..'_out'}
        end
    end,

    ---------------------------------------------------------------------------

    Await_Wclock = function (me)
        me.lbl_out = new{'Await_Wclock'}
    end,
    Await_Ext = function (me)
        local ID_ext = unpack(me)
        me.lbl_out = new{'Await_'..ID_ext.dcl.id}
    end,

    Emit_Wclock = function (me)
        me.lbl_out = new{'Emit_Wclock'}
    end,
    Emit_Ext_emit = function (me)
        local ID_ext = unpack(me)
        me.lbl_out = new{'Emit_Ext_emit'..ID_ext.dcl.id}
    end,

    Async = function (me)
        me.lbl_in = new{'Async'}
    end,
}

AST.visit(F)
