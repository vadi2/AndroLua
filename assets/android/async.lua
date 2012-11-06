require 'import'
local LS = service -- global for now
local PK = luajava.package
local L = PK 'java.lang'
local U = PK 'java.util'

local async = {}

function async.runnable (callback)
    return proxy('java.lang.Runnable',{
        run = function()
            local ok,err = pcall(callback)
            if not ok then service:log(err) end
        end
    })
end

local handler = bind 'android.os.Handler'()
local runnable_cache = {}

function async.post (callback,later)
    local runnable = runnable_cache[callback]
    if not runnable then
        runnable = async.runnable(callback)
        runnable_cache[callback] = runnable
    elseif later ~= nil then
        handler:removeCallbacks(runnable)
    end
    if not later then
        handler:post(runnable)
    elseif type(later) == 'number' then
        handler:postDelayed(runnable,later)
    end
end

function async.read_http(request,gzip,callback)
    return LS:createLuaThread('android.http_async',L.Object{request,gzip},nil,callback)
end

function async.read_socket_lines(address,port,on_line,on_error)
    local args = U.HashMap()
    args:put('addr',address)
    args:put('port',port)
    LS:createLuaThread('android.socket_async',args,
        on_line,on_error or function(...) print(...) end
    )
    return function()
        args:get('socket'):close()
    end
end


return async
