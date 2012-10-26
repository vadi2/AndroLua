require 'socket'

interp = {}

local macros = {}

function interp.macro (def)
    macros[def.name] = def
end

local function expand_macro (m,a)
    if m.arg then
        if not a then
            a = m.last_arg
            if not a then
                return print 'you need to pass a parameter to this macro'
            end
        else
            m.last_arg = a
        end
    else
        a = '' -- keep format happy
    end
    for i,line in ipairs(m) do
        local cmd = line:format(a)
        print('! '..cmd)
        interp.process_line(cmd)
    end
end

local f,err = io.open 'defs.lua'
if f then
    f:close()
    dofile 'defs.lua'
end


local t,c2,err
local c = socket.connect('localhost',3333)
local req = arg[1] or 'no'
c:send (req..'\n')
if req == 'yes' then
    require 'winapi'
    c:receive()
    c2,err = socket.connect('localhost',3334)
    if err then
      return print('cannot connect to secondary socket',err)
    end
    t = winapi.thread(function()
      while true do
        local res = c2:receive()
        res = res:gsub('\001','\n')
        io.write(res)
      end
    end,'ok')
    winapi.sleep(50)
end

local log = io.open('log.txt','a')

local function prep_for_send (s)
    return (s:gsub('\n','\001'))
end

function readfile(file)
  local f,err = io.open(file)
  if not f then return nil,err end
  local contents = f:read '*a'
  f:close()
  return prep_for_send(contents)
end

function eval(line)
  c:send(line..'\n')
  local res = c:receive()
  return (res or '?'):gsub('\001','\n')
end


local init,err = readfile 'init.lua'
if init then
  print 'loading init.lua'
  eval(init)
end

function interp.process_line (line)
    log:write(line,'\n')
    local cmd,file = line:match '^%.(%S+)(.*)$'
    if cmd then
        file = file:gsub('^%s*','')
        file = #file > 0 and file or nil
        if macros[cmd] then
            expand_macro(macros[cmd],file)
            return
        elseif file then -- either .l (load) or .m (upload module)
            local mod,kind = file,'run'
            if cmd == 'm' then -- given in Lua module form
              file = mod:gsub('%.','/')..'.lua'
              kind = 'mod'
            end
            line,err = readfile(file)
            if err then
                return print(err)
            end
            line = '--'..kind..':'..mod..'\001'..line
        else
            return print 'unknown command'
        end
    else
        --  = EXPR becomes print(EXPR)
        local expr = line:match '^%s*=%s*(.+)$'
        if expr then
          line = 'print('..expr..')'
        end
    end
    if line then
        local res = eval(line)
        log:write(res,'\n')
        io.write(res)
    else
        print(err)
    end
end

io.write '> '
local line = io.read()

while line do
  interp.process_line(line)
  io.write '> '
  line = io.read()
end

log:close()
c:close()

if c2 then
    if t then t:kill() end
    c2:close()
end
