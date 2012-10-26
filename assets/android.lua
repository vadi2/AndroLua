require 'import'

-- public for debugging purposes...
android = {}

local LS = service -- which is global for now
local LPK = luajava.package
local L = LPK 'java.lang'
local C = LPK 'android.content'
local W = LPK 'android.widget'
local app = LPK 'android.app'
local V = LPK 'android.view'
local A = LPK 'android'
local G = LPK 'android.graphics'
local P = LPK 'android.provider'

local append = table.insert
local app_package

local function split (s,delim)
    local res,pat = {},'[^'..delim..']+'
    for p in s:gmatch(pat) do
        append(res,p)
    end
    return res
end


local function get_app_package (a)
    if not app_package then
        local package_name = a:toString():match '([^@]+)':gsub ('%.%a+$','')
        android.app = app_package
        app_package = LPK(package_name)
    end
    return app_package
end

function android.drawable (me,icon_name)
    local a = me.a
    -- icon is [android.]NAME
    local dclass
    local name = icon_name:match '^android%.(.+)'
    if name then
        dclass = A.R_drawable
    else
        dclass = get_app_package(a).R_drawable
        name = icon_name
    end
    local did = dclass[name]
    if not did then error(name..' is not a drawable') end
    return a:getResources():getDrawable(did)
end

local option_callbacks,entry_table = {},{}

local function create_menu (me,is_context,t)

    local mymod = me.mod

    local view,on_create,on_select
    if is_context then
        view = t.view
        if not view then error("must provide view for context menu!") end
        me.a:registerForContextMenu(view)
        on_create, on_select = 'onCreateContextMenu','onContextItemSelected'
    else
        on_create, on_select = 'onCreateOptionsMenu','onOptionsItemSelected'
    end

    local entries = {}
    for i = 1,#t,2 do
        local label,icon = t[i]
        -- label is TITLE[|ICON]
        local title,icon_name = label:match '([^|]+)|(.+)'
        if not icon_name then
            title = label
        else
            if is_context then error 'cannot set an icon in a context menu' end
            icon = me:drawable(icon_name)
        end
        local entry = {title=title,id=#option_callbacks+1,icon = icon}
        append(entries,entry)
        append(option_callbacks,t[i+1])
    end

    entry_table[view and view:getId() or 0] = entries

    -- already patched the activity table!
    if is_context and mymod.onCreateContextMenu then return end

    mymod[on_create] = function (menu,v)
        local entries = entry_table[v and v:getId() or 0]
        local NONE = menu.NONE
        for _,entry in ipairs(entries) do
            local item = menu:add(NONE,entry.id,NONE,entry.title)
            if entry.icon then
                item:setIcon(entry.icon)
            end
        end
        return true
    end

    mymod[on_select] = function (item)
        local id = item:getItemId()
        option_callbacks[id](item,id)
        return true
    end

end

--- create an options menu.
-- @param me
-- @param t a table containing 2n items; each row is label,callback.
-- The label is either TITLE or TITLE:ICON; if ICON is prefixed by
-- 'android.' then we look up a stock drawable, otherwise in this
-- app package.
function android.options_menu (me,t)
    create_menu(me,false,t)
end

--- create a context menu on a particular view.
-- @param me
-- @param t a table containing 2n items; each row is label,callback.
-- You cannot set icons on these menu items and `t.view` must be
-- defined!
function android.context_menu (me,t)
    create_menu(me,true,t)
end

--- return a lazy table for looking up controls in a layout.
-- @param me
function android.wrap_widgets (me)
    local rclass = get_app_package(me.a).R_id
    return setmetatable({},{
        __index = function(t,k)
            local c = me.a:findViewById(rclass[k])
            rawset(t,k,c)
            return c
        end
    })
end

--- set the content view of this activity using the layout name.
-- @param me
-- @param me a layout name
function android.set_content_view (me,name)
    me.a:setContentView(get_app_package(me.a).R_layout[name])
end


local function safe (a,callback,...)
    return function(...)
        local ok,res = pcall(callback,...)
        if not ok then
           LS:log(res)
        elseif res ~= nil then
            return res
        end
    end
end

--- make a Vew.OnClickListener.
-- @param me
-- @param callback a Lua function
function android.on_click_handler (me,callback)
    return (proxy('android.view.View_OnClickListener',{
        onClick = safe(me,callback)
    }))
end

--- attach a click handler.
-- @param me
-- @param b a widget
-- @param callback a Lua function
function android.on_click (me,b,callback)
    b:setOnClickListener(me:on_click_handler(callback))
end

--- make a Vew.OnLongClickListener.
-- @param me
-- @param callback a Lua function
function android.on_long_click_handler (me,callback)
    return (proxy('android.view.View_OnLongClickListener',{
        onClick = safe(me,callback)
    }))
end

--- attach a long click handler.
-- @param me
-- @param b a widget
-- @param callback a Lua function
function android.on_long_click (me,b,callback)
    b:setOnLongClickListener(me:on_long_click_handler(callback))
end

--- make an AdapterView.OnItemClickListener.
-- @param me
-- @param callback a Lua function
function android.on_item_click (me,lv,callback)
    lv:setOnItemClickListener(proxy('android.widget.AdapterView_OnItemClickListener',{
        onItemClick = safe(me,callback)
    }))
end

local function drawable(prefix,name)
    return A.R_drawable[prefix..'_'..name]
end

--- show an alert.
-- @param me
-- @param title caption of dialog - can be an array {icon,text}
-- where icon is one of the android.R.drawable.btnXXX constants
-- @param message text within dialog
-- @param callback optional Lua function to be called
function android.alert(me,title,kind,message,callback)
    local Builder = bind 'android.app.AlertDialog_Builder'
    local db = Builder(me.a)
    local parts = split(title,'|')
    db:setTitle(parts[1])
    if parts[2] then
        db:setIcon(me:drawable(parts[2]))
    end
    db:setMessage(message)
    callback = callback or function() end -- for now
    local listener = proxy('android.content.DialogInterface_OnClickListener', {
        onClick = safe(me,callback)
    })
    if kind == 'ok' then
        db:setNeutralButton("OK",listener)
    elseif kind == 'yesno' then
        db:setPositiveButton("Yes",listener)
        db:setNegativeButton("No",listener)
    end
    dlg = db:create()
    dlg:setOwnerActivity(me.a)
    dlg:show()
end

--- show a toast
-- @param me
-- @param text to show
-- @param long true if you want a long toast!
function android.toast(me,text,long)
    W.Toast:makeText(me.a,text,long and W.Toast.LENGTH_LONG or W.Toast.LENGTH_SHORT):show()
end

--- suppress initial soft keyboard with edit view.
-- @param me
function android.no_initial_keyboard(me)
    local WM_LP = bind 'android.view.WindowManager_LayoutParams'
    me.a:getWindow():setSoftInputMode(WM_LP.SOFT_INPUT_STATE_HIDDEN)
end

--- make the soft keyboard go bye-bye.
-- @param v an edit view
function android.dismiss_keyboard (v)
    local ime = v:getContext():getSystemService(C.Context.INPUT_METHOD_SERVICE)
    ime:hideSoftInputFromWindow(v:getWindowToken(),0)
end

local TAKE_PICTURE, TAKE_PICTURE_EXTRA = 100,101

local handlers = {}

local RESULT_CANCELED = app.Activity.RESULT_CANCELED

function android.take_picture (me,file,callback)
    local MediaStore = bind 'android.provider.MediaStore'
    local intent = C.Intent(MediaStore.ACTION_IMAGE_CAPTURE)
    local request
    callback = safe(me,callback)
    if file then
        local Uri = bind 'android.net.Uri'
        if not file:match '^/' then
            file = me.a:getFilesDir()..'/images/'..file
        end
        intent:putExtra(MediaStore.EXTRA_OUTPUT, Uri:fromFile(file))
        request = TAKE_PICTURE_EXTRA
        handlers[request] = function(_,result,intent)
            callback(result ~= RESULT_CANCELED)
        end
    else
        request = TAKE_PICTURE
        handlers[request] = function(_,result,intent)
            local data
            print(result,intent)
            if result ~= RESULT_CANCELED then
                data = intent:getExtras():get 'data'
            end
            callback(data,result,intent)
        end
    end
    LS:log('request '..request)
    me.a:startActivityForResult(intent,request)
end

local function get_string(c,key,def)
    local idx = c:getColumnIndex(key)
    if idx == -1 then return def end
    return c:getString(idx)
end

function android.pick_contact(me,callback)
    local request = 102
    local CCC = P.ContactsContract_Contacts
    local CCP = P.ContactsContract_CommonDataKinds_Phone
    local CCE = P.ContactsContract_CommonDataKinds_Email
    callback = safe(me,callback)
    handlers[request] = function(_,result,intent)
        if result ~= RESULT_CANCELED then
            local c = me.a:managedQuery(intent:getData(),nil,nil,nil,nil)
            if c:moveToFirst() then
                local res = { uri = intent:getData()}
                res.id = get_string(c,CCC._ID)
                res.name = get_string(c,CCC.DISPLAY_NAME)
                if get_string(c,CCC.HAS_PHONE_NUMBER,'0') ~= '0' then
                    local phones = me.a:getContentResolver():query(
                        CCP.CONTENT_URI, nil, CCP.CONTACT_ID..' = '..res.id,
                        nil,nil
                    )
                    phones:moveToFirst()
                    res.phone = get_string(phones, "data1")
                end
                callback(res)
            end
        end
    end
    local intent = C.Intent(C.Intent.ACTION_PICK,CCC.CONTENT_URI)
    me.a:startActivityForResult(intent,request)
end

function android.onActivityResult(request,result,intent,mod_handler)
    print('request '..request,result,intent,mod_handler)
    local handler = handlers[request]
    if handler then handler(request,result,intent)
    elseif mod_handler then
        mod_handler(request,result,intent)
    else
        android.activity_result = {request,result,intent}
    end
end

local next_id = 1

local function give_id (w)
    if w:getId() == -1 then
        w:setId(next_id)
        next_id = next_id + 1
    end
    return w
end

--- make a button.
-- @param me
-- @param text of button
-- @param callback a Lua function or an existing click listener.
-- This is passed the button as its argument
function android.button (me,text,callback)
    local b = W.Button(me.a)
    b:setText(text)
    if type(callback) == 'function' then
        callback = me:on_click_handler(callback)
    end
    b:setOnClickListener(callback)
    return give_id(b)
end


local function set_edit_args (txt,args)
    if args.id then
        txt:setId(args.id)
    end
    if args.textcolor then
        txt:setTextColor(android.parse_color(args.textcolor))
    end
    if args.background then
        txt:setBackgroundColor(android.parse_color(args.background))
    end
    if args.size then
        txt:setTextSize(android.parse_size(args.size))
    end
    if args.maxLines then
        txt:setMaxLines(args.maxLines)
    end
    if args.minLines then
        txt:setMinLines(args.minLines)
    end
    local Typeface,tface = G.Typeface
    if args.typeface or args.textStyle then
        if args.typeface then
            tface = Typeface:create(args.typeface,Typeface.NORMAL)
        else
            tface = txt:getTypeface()
        end
        if args.textStyle then
            local style = args.textStyle:upper()
            tface = Typeface:create(tface,Typeface[style])
        end
        txt:setTypeface(tface)
    end
    if args.gravity then
        local gg = split(args.gravity,'|')
        local g = 0
        for _,p in ipairs(gg) do
            g = g + V.Gravity[p:upper()]
        end
        txt:setGravity(g)
    end
    give_id(txt)
end

--- parse a colour value.
-- @param c either a number (passed through) or a string like #RRGGBB,
-- #AARRGGBB or colour names like 'red','blue','black','white' etc
function android.parse_color(c)
    if type(c) == 'string' then
        local ok
        ok,c = pcall(function() return G.Color:parseColor(c) end)
        if not ok then
            LS:log("converting colour "..tostring(c).." failed")
            return G.Color.WHITE
        end
    end
    return c
end

local TypedValue = bind 'android.util.TypedValue'

--- parse a size specification.
-- @param size a number is interpreted as pixels, otherwise a string like '20sp'
-- or '30dp'. (See android.util.TypedValue.COMPLEX_UNIT_*)
-- @return unit
-- @return size
function android.parse_size(size)
    local sz,unit
    if type(size) == 'string' then
        sz,unit = size:match '(%d+)(.+)'
        sz = tonumber(sz)
        unit = TypedValue['COMPLEX_UNIT_'..unit:upper()]
    else
        sz = size
        unit = TypedValue.COMPLEX_UNIT_PT
    end
    return unit,sz
end

local function handle_args (args)
    if type(args) == 'string' then
        args = {args}
    end
    return args[1] or '',args
end

--- create an edit widget.
-- @param me
-- @param args either a string (which is usually the hint, or the text if it
-- starts with '!') or a table with fields `textColor`, `id`, `background` or `size`
function android.editText (me,args)
    local text,args = handle_args(args)
    local txt = W.EditText(me.a)
    if text:match '^!' then
        txt:setText(text:sub(1))
    else
        txt:setHint(text)
    end
    set_edit_args(txt,args)
    return txt
end

-- create a text view.
-- @param me
-- @param args as with `android.editText`
function android.textView (me,args)
    local text,args = handle_args(args)
    local txt = W.TextView(me.a)
    txt:setText(text)
    set_edit_args(txt,args)
    return txt
end

function android.imageView(me)
    --local text,args = handle_args(args)
    local image = W.ImageView(me.a)

    return give_id(image)
end

--- create a simple list view.
-- @param me
-- @param items a list of strings
function android.listView(me,items)
    local lv = W.ListView(me.a)
    local adapter = ArrayAdapter(me.a,
        A.R_layout.simple_list_item_checked,
       -- R_layout.simple_list_item_1,
        A.R_id.text1,
        L.String(items)
    )
    lv:setAdapter(adapter)
    return give_id(lv)
end

--- create a Lua View.
-- @param me
-- @param t may be a drawing function, or a table that defines `onDraw`
-- and optionally `onSizeChanged`. It will receive the canvas.
function android.luaView(me,t)
    if type(t) == 'function' then
        t = { onDraw = t }
    end
    return give_id(service:launchLuaView(me.a,t))
end


local function parse_gravity (s)
    if type(s) == 'string' then
        return V.Gravity[s:upper()]
    else
        return s
    end
end


local function linear (me,vertical,t)
    local LL = not t.radio and W.LinearLayout or W.RadioGroup
    local LP = W.LinearLayout_LayoutParams
    local wc = LP.WRAP_CONTENT
    local fp = LP.FILL_PARENT
    local xp, yp, parms
    if vertical then
        xp = fp;  yp = wc;
    else
        xp = wc;  yp = fp
    end
    local margin
    if t.margin then
        if type(t.margin) == 'number' then
            t.margin = {t.margin,t.margin,t.margin,t.margin}
        end
        margin = t.margin
    end
    local ll = LL(me.a)
    ll:setOrientation(vertical and LL.VERTICAL or LL.HORIZONTAL)
    for i = 1,#t do
        local w, gr = t[i]
        if type(w) == 'userdata' then
            local spacer
            if i < #t and type(t[i+1])~='userdata' then
                local mods = t[i+1]
                local weight,gr,nofill,width
                if type(mods) == 'string' then
                    if mods == '+' then
                        weight = 1
                    elseif mods == '...' then
                        spacer = true
                    end
                elseif type(mods) == 'table' then
                    weight = mods.weight
                    nofill = mods.fill == false
                    gr = parse_gravity(mods.gravity)
                    width = mods.width or mods.height
                end
                local axp,ayp = xp,yp
                if nofill then
                    if vertical then axp = wc else ayp = wc end
                end
                if width then
                    if vertical then ayp = width else axp = width end
                end
                parms = LP(axp,ayp,weight or 0)
                i = i + 1
            else
                parms = LP(xp,yp)
            end
            if margin then
                parms:setMargins(margin[1],margin[2],margin[3],margin[4])
            end
            if gr then
                parms.gravity = gr
            end
            ll:addView(w,parms)
            if spacer then
                ll:addView(me:textView'',LP(xp,yp,10))
            end
        end
    end
    return ll
end

--- a vertical layout.
-- @param me
-- @param t a list of controls, optionally separated by layout strings or tables
-- for example, `{w1,'+',w2} will give `w1` a weight of 1 in the layout.
-- Tables of form {width=number,fill=false,gravity=string,weight=number}
function android.vbox (me,t)
    return linear(me,true,t)
end

--- a horizontal layout.
-- @param me
-- @param t a list of controls, as in `android.vbox`.
function android.hbox (me,t)
    return linear(me,false,t)
end

--- launch a Lua activity.
-- @param me
-- @param mod a Lua module name that defines the activity
-- @param arg optional extra value to pass to activity
function android.luaActivity (me,mod,arg)
    return service:launchLuaActivity(me.a,mod,arg)
end

local function lua_adapter(me,items,impl)
    if type(impl) == 'function' then
        impl = { getView = impl; items = items }
    end
    return service:createLuaListAdapter(items,impl or me)
end

--- create a Lua list view.
-- @param me
-- @param items a table of Lua values
-- @param optional implementation - not needed if `me`
-- has a getView function. May be a function, and then it's
-- assumed to be getView.
-- @return list view
-- @return adapter
function android.luaListView (me,items,impl)
    local adapter = lua_adapter(me,items,impl)
    local lv = W.ListView(me.a)
    lv:setAdapter(adapter)
    return give_id(lv), adapter
end

--- create a Lua grid view.
-- @param me
-- @param items a table of Lua values
-- @param number of columns (-1 for as many as possible)
-- @param optional implementation - not needed if `me`
-- has a getView function. May be a function, and then it's
-- assumed to be getView.
-- @return list view
-- @return adapter
function android.luaGridView (me,items,ncols,impl)
    local adapter = lua_adapter(me,items,impl)
    local lv = W.GridView(me.a)
    lv:setNumColumns(ncols or -1)
    lv:setAdapter(adapter)
    return give_id(lv), adapter
end


--- make a new AndroLua module.
function android.new()
    local mod = {}
    mod.onCreate = function (activity,arg)
        local me = {a = activity, mod = mod}
        for k,v in pairs(android) do me[k] = v end
        -- want any module functions available from the wrapper
        setmetatable(me,{
            __index = mod
        })
        mod.me = me
        mod.a = activity
        local view = mod.create(me,arg)
        mod.view = view
        return view
    end
    local oldActivityResult = mod.onActivityResult
    local thisActivityResult = android.onActivityResult
    if oldActivityResult then
        mod.onActivityResult = function(r,R,i)
            thisActivityResult(r,R,i,oldActivityResult)
        end
    else
        mod.onActivityResult = thisActivityResult
    end
    return mod
end

return android
