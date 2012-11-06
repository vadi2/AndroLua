require 'import'
local IO = luajava.package 'java.io'
local N = luajava.package 'java.net'

return function(thrd,arg)
    local addr = arg:get 'addr'
    local port = arg:get 'port'
    local client, reader, line = N.Socket()
    client:connect(N.InetSocketAddress(addr,port),500)
    arg:put('socket',client)
    reader = IO.BufferedReader(IO.InputStreamReader(client:getInputStream()))
    client:setKeepAlive(true)
    line = reader:readLine()
    while line do
        thrd:setProgress(line)
        line = reader:readLine()
    end
    reader:close()
    client:close()
    return 'ok'
end
