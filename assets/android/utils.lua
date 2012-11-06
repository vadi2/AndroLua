require 'import'
local L = luajava.package 'java.lang'
local IO = luajava.package 'java.io'
local BUFSZ = 4*1024

local utils = {}

function utils.readbytes(f)
    local buff = L.Byte{n = BUFSZ}
    local out = IO.ByteArrayOutputStream(BUFSZ)
    local n = f:read(buff)
    while n ~= -1 do
        out:write(buff,0,n)
        n = f:read(buff,0,BUFSZ)
    end
    f:close()
    return out:toByteArray()
end

function utils.readstring(f)
    return tostring(L.String(utils.readbytes(f)))
end

return utils

