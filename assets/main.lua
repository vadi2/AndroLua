-- main.lua
-- This is an AndroLua activity which uses a traditional layout defined
-- in XML. In this case, the `create` function does not return a view,
-- but must set the content view explicitly.
-- Note that `ctrls` is a cunning lazy table for accessing named
-- controls in the layout!

main = require 'android'.new()

local SMM = bind 'android.text.method.ScrollingMovementMethod'
local InputType = bind 'android.text.InputType'

function main.create(me)
    local a = me.a
    me:set_content_view 'main'
    local ctrls = me:wrap_widgets()
    local status = ctrls.statusText

    status:setText "listening on port 3333\n"
    local smm = SMM:getInstance()
    status:setMovementMethod(smm)

    ctrls.source:setText "require 'import'\nlocal L = luajava.package 'java.lang'\nprint(L.Math:sin(2.3))\n"

    me:on_click(ctrls.executeBtn,function()
        local src = ctrls.source:getText():toString()
        local ok,err = pcall(function()
            local res = service:evalLua(src,"tmp")
            status:append(res..'\n')
            status:append("Finished Successfully\n")
        end)
        if not ok then -- make a loonnng toast..
            me:toast(err,true)
        end
    end)

    local input_type = ctrls.source:getInputType()
    input_type = InputType.TYPE_CLASS_TEXT + InputType.TYPE_TEXT_FLAG_MULTI_LINE
    ctrls.source:setInputType( input_type + InputType.TYPE_TEXT_FLAG_NO_SUGGESTIONS)

    local function launch (name)
        return function() me:luaActivity('example.'..name) end
    end

    me:context_menu {
        view = ctrls.source;
        "list",launch 'list',
        "draw",launch 'draw',
        "pretty",launch 'pretty',

    }
    return true
end

return main
