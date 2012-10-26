require 'import'

function goapp(mod,arg)
    service:launchLuaActivity(activity,mod,arg)
end

PK = luajava.package
W = PK 'android.widget'
G = PK 'android.graphics'
V = PK 'android.view'
A = PK 'android'
L = PK 'java.lang'
U = PK 'java.util'

