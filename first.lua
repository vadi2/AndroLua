require 'import'

import 'android.widget.*'
import 'android.app.*'
import 'android.view.*'
import 'android.content.*'
import 'android.*'
import 'java.util.*'

local classes = {}
local function bind (klassname)
    if not classes[klassname] then
        classes[klassname] = luajava.bindClass(klassname)
    end
    return classes[klassname]
end



local me

local function safe (callback,...)
    return function(...)
        local ok,res = pcall(callback,...)
        if not ok then
            me:log(res)
        elseif res ~= nil then
            return res
        end
    end
end

function on_click (btn,callback)
    btn:setOnClickListener(proxy('android.view.View_OnClickListener',{
        onClick = safe(callback)
    }))
end

function on_item_click (lv,callback)
    lv:setOnItemClickListener(proxy('AdapterView_OnItemClickListener',{
        onItemClick = safe(callback)
    }))
end

function alert(title,message,callback)
    local dlg = AlertDialog_Builder(me):create()
    dlg:setTitle(title)
    dlg:setMessage(message)
    dlg:setButton("OK",proxy('android.content.DialogInterface_OnClickListener', {
        onClick = safe(callback)
    }))
    dlg:show()
end

function toast(text)
    Toast:makeText(me,text,Toast.LENGTH_SHORT):show()
end

function no_initial_keyboard(me)
    me:getWindow():setSoftInputMode(WindowManager_LayoutParams.SOFT_INPUT_STATE_HIDDEN)
end

function dismiss_keyboard (v)
    local ime = v:getContext():getSystemService(Context.INPUT_METHOD_SERVICE)
    ime:hideSoftInputFromWindow(v:getWindowToken(),0)
end

local TAKE_PICTURE = 100


function take_picture (me,file)
    local MediaStore = bind 'android.provider.MediaStore'
    local intent = Intent(MediaStore.ACTION_IMAGE_CAPTURE)
    if file then
        local Uri = bind 'android.net.Uri'
        if not file:match '^/' then
            file = me:getFilesDir()..'/images/'..file
        end
        intent:putExtra(MediaStore.EXTRA_OUTPUT, Uri:fromFile(file))
    end
    me:startActivityForResult(intent,TAKE_PICTURE)
end

function layout (t)
    local me = t.context
    local ll = LinearLayout(me)
    ll:setOrientation(LinearLayout.VERTICAL)
    for i = 1,#t do
        local item = t[i]
        ll:addView(item)
    end
    return ll
end

first = {}

function first.onCreate(activity, bundle)
    me = activity
    first.a = me

    local edit,btn,txt,lv1, lv2

    edit = EditText(me)
    edit:setHint 'please?'
    btn = Button(me)
    btn:setText 'Click me'
    txt = TextView(me)
    txt:setText 'here we go\nagain'

    on_click(btn,function(v)
        dismiss_keyboard (edit)
        alert('Warning','AndroLua: '..edit:getText():toString(),function()
            me:log ('troubled!')
            toast 'hello'
        end)
    end)

    lv1 = ListView(me)
    local adapter = ArrayAdapter(me,
        R_layout.simple_list_item_checked,
       -- R_layout.simple_list_item_1,
        R_id.text1,
        String{'One','Two'}
    )
    lv1:setAdapter(adapter)

    on_item_click(lv1,function(p,v,pos,id)
        --toast('pos '..pos)
        local was_checked = v:isChecked()
        v:setChecked(not was_checked)
    end)

    local array = ArrayList()
    local map = HashMap()
    map:put('firstname','Steve')
    map:put('surname','Donovan')
    array:add(map)
    map = HashMap()
    map:put('firstname','Simon')
    map:put('surname','Jones')
    array:add(map)

    lv2 = ListView(me)
    adapter = SimpleAdapter(me,
        array,
        R_layout.simple_list_item_2,
        String {'firstname','surname'},
        Integer {R_id.text1,R_id.text2 }
    )
    lv2:setAdapter(adapter)

    no_initial_keyboard(me)


    return  layout {
        context = me;
        edit,
        btn,
        txt,
        lv1,
        lv2,
    }
end

function first.onActivityResult(request,result,intent)
    me:log(request..' '..result)
    INTENT = intent
end

function first.onStop()
    first.a = nil  -- flag us as being dead
end


--[[
function first.onStart()
    me:log 'starting...'
end

function first.onResume()
    me:log 'resuming...'
end

function first.onPause()
    me:log 'pausing...'
end

--]]


return first

