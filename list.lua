-- list.lua
-- This is a AndroLua activity where the view is an explicitly generated
-- custom Lua ListView, where we define the layout of each item
-- programmatically.
--
-- Note that these activities can be passed any Lua data, which allows us
-- to _recursively_ create child activities.

list = require 'android'.new()

A = luajava.package 'android'
W = luajava.package 'android.widget'
V = luajava.package 'android.view'

function contents_of (T)
    local items,append = {},table.insert
    for k,v in pairs(T) do
        append(items,{name=k,type=type(v),value=v})
    end
    return items
end

local PC = android.parse_color
local tableclr, otherclr =  PC'#FFEEAA', PC'#EEFFEE'

function list.create (me,arg)

    local items = contents_of(arg or _G)

    local lv = me:luaListView(items,function (impl,position,view,parent)
        local item = items[position+1]
        local txt1,txt2
        if not view then
            txt1 = me:textView{id = 1, size = '20sp'}
            txt2 = me:textView{id = 2, background = '#222222'}
            view = me:hbox{txt1,'+',me:hbox{txt2,{fill=false,width=100,gravity='CENTER'}}}
        else
            txt1 = view:findViewById(1)
            txt2 = view:findViewById(2)
        end
        txt1:setText(item.name)
        txt2:setText(item.type)
        txt1:setTextColor(item.type=='table' and tableclr or otherclr)
        return view
    end)

    me:on_item_click(lv,function(av,view,idx)
        local item = items[idx+1]
        if item.type == 'table' then
            me:luaActivity('list',item.value)
        end
    end)

    return lv
end

return list
