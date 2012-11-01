# Lua for Android using AndroLua

## Advantages

The Android Java development process is fairly clumsy, although the IDE support is excellent. ...

A dynamic language allows a much more interactive development flow, especially if there is an interactive prompt (REPL) hosted on the development machine. This allows you to learn a large API by experimentation, and test out small snippets of code, without actually having to rebuild, reinstall and relaunch.  The further advantage of Lua is its small footprint - the dynamic library `libluajava.so` is only 134Kb, and so the basic demonstration AndroLua application is just a 121Kb APK. Total memory use is about 8 Meg and compares favourably with larger languages. Here Lua's famous 'lack of batteries' is a virtue, since you can access practically all of the Android APIs through LuaJava.

The command `alshell` opens a network connection to your device and can execute Lua expressions, files and upload modules. You do not even need the ADK to experiment, if your device is on a local wireless network.  However, you will need the ADK to package your own AndroLua applications, and it's useful to access the documentation off-line.

## LuaJava

LuaJava is a JNI binding to the native Lua 5.1 shared library. This has its advantages and disadvantages; raw Lua speed is better, but you do pay for accessing the JVM through JNI.

It provides a table `luajava` containing functions for binding Java classes and instantiating Java objects. `bindClass` is passed the full qualified name of the class (like `java.lang.math')

    > Math = luajava.bindClass 'java.lang.Math'
    > = Math:sin(1.2)
    0.93203908596723

Please note that all java methods, even static ones, require a colon!

To instantiate an object of a class, use `new`:

> ArrayList = luajava.bindClass 'java.util.ArrayList'
> a = luajava.new(ArrayList)
> a:add(10)
> a:add('one')
> = a:size()
2
> = a:get(0)
10
> = a:get(1)
one

LuaJava automatically boxes Lua types as Java objects, and unboxes them when they are returned, even with tables.  So `a:get(1)` returns a Lua string.

Generally all Java `String` instances are converted into Lua strings; the exception is if you _explicitly_ create a Java string:

    > String = luajava.bindClass 'java.lang.String'
    > s = luajava.new(String,'hello dolly')
    > = s
    hello dolly
    > = s:startsWith 'hello'
    true

These functions are tedious to type, and of course you can define local aliases for them.  The `import` utility module goes a little further and provides a global function `bind`:

    > require 'import'
    > HashMap = bind 'java.util.HashMap'
    > h = HashMap()
    > h:put('hello',10)
    > h:put(42,'bonzo')
    > = h:get(42)
    bonzo
    > = h:get('hello')
    10

The chief thing to note is that `bind` makes the class callable, so we no longer have to explicitly use `new`.  If that constructor is passed a table, then an array of that type is generated. A special case is if the type represents a number:

> String = bind 'java.lang.String'
> ss = String{'one','two','three'}
> = ss
[Ljava.lang.String;@41558458
> Integer = bind 'java.lang.Integer'
> ii = Integer{10,20,30}
> = ii
[I@41578230

So `ii` is an array of actual primitive ints!

It's still awkward to have to specify the full name of each class to be accessed. So there is a way to make packages:

    > L = luajava.package 'java.lang'
    > = L.String
    class java.lang.String
    > = L.Boolean
    class java.lang.Boolean

`L` is a _smart table_ - if it can't find the field it uses `bind` to resolve the class, and thereafter contains a direct reference. So it's an efficient idiom, and generally you will not need to assign classses to their own variables.

`alshell` provides commands which begin with a dot:

    -- test.lua
    print 'hello world!'

    -- mod.lua
    mod = {}
    function mod.answer() return 42 end
    return mod

    > .l test.lua
    hello world!
    > .m mod
    wrote /data/data/sk.kottman.androlua/files/mod.lua
    > require 'mod'
    > = mod.answer()
    42

`.l` evaluates the Lua file directly, and `.m` writes the module to a location where `require` can find it. (It will clear out the package.loaded table entry so that subsequent `require` calls will pick up the new version.)

(A note on style: sometimes we have to be a little bad to do something good. In interactive work, it's useful to break the rule that we don't create too many globals, since it's only possible to access globals from the interactive prompt.)

The file `init.lua` is first loaded by `alshell`. It contains the following useful definitions:

    PK = luajava.package
    W = PK 'android.widget'
    G = PK 'android.graphics'
    V = PK 'android.view'
    A = PK 'android'
    L = PK 'java.lang'
    U = PK 'java.util'

Once the session has started, you may explore the Android API interactively. (`main.a` is a reference to the initial running `LuaActivity` instance):

    > r = main.a:getResources()
    > = r:getString(A.R_string.ok)
    OK
    > = r:getString(A.R_string.cancel)
    Cancel
    > = r:getString(A.R_string.dialog_alert_title)
    Attention



## Defining Activities in Lua

AndroLua provides a basic `LuaActivity` class derived from `Activity` which implements many of the useful methods and forwards them to a Lua table; so there's `onCreate`,`onPause`,'OnActivityResult'.

For instance, here is a layout-only version of the AndroLua main activity:


    -- raw.lua
    require 'import'

    local app = luajava.package 'sk.kottman.androlua'

    local raw = {}

    function raw.onCreate(a)
        a:setContentView(app.R_layout.main)
    end

    return raw

Note that `onCreate` receives a Java object of type `LuaActivity`; the base class method has already been called.

Also note that the nested class `R.layout` is written with an underscore; this is expanded to '$' when resolving the class. Since generally Java libraries don't use underscores and Lua identifiers cannot contain '$', this is a reasonable hack.

Launching the activity uses the `.a` macro, which ends the current instance, uploads the file and launches the activity:

    > .a raw
    ! MOD = raw
    ! if MOD and MOD.a then MOD.a:finish() end
    ! .m raw
    wrote /data/data/sk.kottman.androlua/files/raw.lua
    ! goapp 'raw'
    > starting Lua service

The beauty of this approach is that we can load and test an activity as fast as the device can create it!

The best way to understand how the ball gets rolling in an AndroLua application is to look at Main.java:

    package sk.kottman.androlua;

    import android.app.Activity;
    import android.os.Bundle;

    public class Main extends LuaActivity  {
        @Override
        public void onCreate(Bundle savedInstanceState) {
            CharSequence mod = getResources().getText(R.string.main_module);
            getIntent().putExtra("LUA_MODULE", mod);
            super.onCreate(savedInstanceState);

        }

    }

The key resource here is 'main_module', which is defined as 'main' in the project; `LuaActivity` looks at the intent parameter 'LUA_MODULE' and does a `require` on it.

This 'raw' style is fine, but we can make things even better:

    easy = require 'android'.new()

    function easy.create(me)
        local w = me:wrap_widgets()
        me:set_content_view 'main'

        print(w.executeBtn, w.statusText, w.source)

        return true
    end

    return easy

Note that the entry point is now called `create`, and it receives a Lua table which wraps the underlying activity object and provides a set of useful methods. `set_content_view` is straightforward enough, but the application's package is deduced for you.  `wrap_widgets` returns a lazy table which simplifies looking up a layout's widgets by name - it looks up the id in `R.id` and calls `findViewById` for you.

We don't have to use an XML layout, of course.  It's recommended practice because (a) separating layout from code is generally a good idea and (b) it's a pain to create layouts dynamically in Java.  (The second reason naturally feeds into the first reason - anybody who needs convincing should look at Swing GUI code.)

The `android` module provides a few useful helpers when you wish to avoid XML - such as prototyping a layout dynamically. Here is another version of the main AndroLua activity, this time sans layout:

    easy = require 'android'.new()

    local smm = bind 'android.text.method.ScrollingMovementMethod':getInstance()

    function easy.create(me)

        local executeBtn = me:button 'Execute!'
        local source = me:editText {
            size = '20sp',
            typeface = 'monospace',
            gravity = 'top|left'
        }
        local status = me:textView {'TextView', maxLines = 5 }
        status:setMovementMethod(smm) -- make us scrollable!

        source:setText "print 'hello, world!'"

        local layout =  me:vbox{
            executeBtn,
            source,'+',
            status
        }

        ...

        return layout
    end

    return easy

The `vbox` method generates a vertically oriented `LinearLayout`. It's passed a table of widgets which may be followed by layout commands. The simplest is '+', which gives the widget a weight.  So our edit view takes over most space, as desired. Unlike `onCreate` the `create` function returns the actual view.

Lua is particularly satisfying once you get to handling events; in many cases a first-class function is a better solution than the Java One True Way of creating Yet Another Class.

The following code attaches a callback to the button's click event:

        me:on_click(executeBtn,function()
            local src = source:getText():toString()
            local ok,err = pcall(function()
                local res = service:evalLua(src,"tmp")
                status:append(res..'\n')
                status:append("Finished Successfully\n")
            end)
            if not ok then -- make a loonnng toast..
                me:toast(err,true)
            end
        end)

The global `service` is a reference to the local Lua service object created by AndroLua, which is bound by `LuaActivity`.  (We could just as well have used `loadstring` and avoided having to do some exception catching.)

The `toast` method is an example of turning a common Android one-liner into a no-brainer.  There is only so much room in the average human mind for remembering incantations (and we are all average at least _sometimes_)

(alerts)

Another example is options and context menus. For instance, from the main AndroLua module:

        local function launch (name)
            return function() me:luaActivity(name) end
        end

        me:context_menu {
            view = ctrls.source;
            "list",launch 'list',
            "draw",launch 'draw',
            "icons",launch 'icons'
        }

`launch` is a classic factory function which generates callbacks. When you long-press the source widget, the context menu will appear.

`options_menu` works in the same way, except that there is no need to specify a view and you can also specify _icons_. This is activated either by the menu button on older phones or the little menu icon on the extreme bottom right.

## Custom List Views in Lua

Android has a number of list view adapters, which are convenient if you have your data as Java objects and if you have the exact layout you need as a resource.

AndroLua has a `LuaListAdapter` class which is backed by a Lua table. In `example/list.lua` (which shows the contents of the Lua global table), a custom view is defined like this:

    local lv = me:luaListView(items,function (impl,position,view,parent)
        local item = items[position+1] -- position is zero-based...
        local txt1,txt2
        if not view then
            txt1 = me:textView{id = 1, size = '20sp'}
            txt2 = me:textView{id = 2, background = '#222222'}
            view = me:hbox{
                txt1,'+',
                me:hbox{
                    txt2,
                    {fill=false,width=100,gravity='CENTER'}
                }
            }
        else
            txt1 = view:findViewById(1)
            txt2 = view:findViewById(2)
        end
        txt1:setText(item.name)
        txt2:setText(item.type)
        txt1:setTextColor(item.type=='table' and tableclr or otherclr)
        return view
    end)

This does the usual optimization and reuses the previously created view.

## Custom Views

A custom view is defined by a Lua table with an `onDraw` function, and optional `onSizeChanged` and `onTouchEvent` functions.  Thereafter things work pretty much as expected.

`example/draw.lua` shows a Lua version of an Android [Java example](http://bestsiteinthemultiverse.com/2008/11/android-graphics-example/)


## Performance Questions

LuaJava uses JNI to interface Lua with Java. Although calling C from Java is pretty fast (accessing the C Lua API), calling Java methods from C is slower - effectively a kind of reflection. Then there is the overhead of having to use reflection again to resolve each method call dynamically.  There's some additional performance issues to do with implementation details, which can be improved, but basically this means that you should rather write code in Lua directly than use Java APIs.

Another performance issue has to do with the _interesting_ memory management issues you have with _two_ garbage-collected languages. References to java objects on the Lua side are small objects, so the Lua GC has no way of knowing how important they are, and hang on to references longer than we would wish. So manually calling `collectgarbage` can be useful, but (as always) ensure that the Java objects aren't referenced somewhere sneaky.


