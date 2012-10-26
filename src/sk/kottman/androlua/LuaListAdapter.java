package sk.kottman.androlua;

import org.keplerproject.luajava.LuaException;

import android.view.View;
import android.view.ViewGroup;
import android.widget.BaseAdapter;

public class LuaListAdapter extends BaseAdapter {

	Lua lua;
	Object impl, mod;
	
	public LuaListAdapter(Lua l, Object mod, Object impl) {
		lua = l;
		this.impl = impl;
		this.mod = mod;
	}

	public int getCount() {
		try {
			Lua.L.pushObjectValue(mod);
			int len = lua.L.objLen(-1);
			Lua.L.pop(1);
			return len;
		} catch (LuaException e) {
			return 0;
		}		
		//return (Integer)lua.invokeMethod(impl, "getCount");
	}

	public Object getItem(int position) {
		try {
			Lua.L.pushObjectValue(mod);
			Lua.L.rawGetI(-1, position);
			Object res = Lua.L.toJavaObject(-1);
			Lua.L.pop(1);  //2?
			return res;
		} catch (LuaException e) {
			return null;
		}		
		
		//return lua.invokeMethod(impl, "getItem",position);
	}

	public long getItemId(int position) {
		Object res = lua.invokeMethod(impl, "getItemId");
		return res != null ? (Long)res : position;		
	}

	public View getView(int position, View convertView, ViewGroup parent) {
		return (View)lua.invokeMethod(impl, "getView",impl,position,convertView,parent);
	}

}
