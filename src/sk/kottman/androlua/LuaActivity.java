package sk.kottman.androlua;

import android.app.Activity;

import android.content.Intent;
import android.os.Bundle;
import android.view.View;

import org.keplerproject.luajava.*;

public class LuaActivity extends Activity {
	LuaState L;
	LuaObject modTable;
	static int REGISTRYINDEX = LuaState.LUA_REGISTRYINDEX.intValue();

	/** Called when the activity is first created. */
	@Override
	public void onCreate(Bundle savedInstanceState) {
	    super.onCreate(savedInstanceState);
	    
	    Intent intent = getIntent();
	    String mod = intent.getStringExtra("LUA_MODULE");
	    
	    log("module " + mod);
	
	    L = Lua.L;
	    
	    L.getGlobal("require");
	    L.pushString(mod);
	    if (L.pcall(1, 1, 0) != 0) {
	    	log("require "+L.toString(-1));
	    	finish();
	    	return;
	    }
	    modTable = L.getLuaObject(-1);
	    
	    
	    try {
			L.pushObjectValue(this);
		} catch (LuaException e) {
			Lua.log("cannot push");
		}
	    L.setGlobal("current_activity");
	    
	    Object res;
	    if (modTable.isFunction()) {
	    	try {
				res = modTable.call(new Object[]{this, savedInstanceState});
			} catch (LuaException e) {
				log("onCreate "+e.getMessage());				
				res = null;
			}
	    	modTable = null;
	    } else {
	    	res = invokeMethod("onCreate",this,savedInstanceState);
	    }
	    if (res instanceof View) {
	    	setContentView((View)res);
	    } else {
	    	log("onCreate must return a View");
	    	finish();
	    	return;
	    }
	    
	}
	
	Object invokeMethod(String name, Object... args) {
		if (modTable == null)
			return null;
		Object res = null;
	    try {
			LuaObject f = modTable.getField(name);
			if (f.isNil())
				return null;
			res = f.call(args);
		} catch (LuaException e) {
			log("method "+name+": "+e.getMessage());
		}		
		return res;
	}
	
	@Override
	protected void onActivityResult(int request, int result, Intent data) {
		invokeMethod("onActivityResult",request,result,data);
	}
	
	@Override
	public void onPause() {
		super.onPause();
		invokeMethod("onPause");
	}
	
	@Override
	public void onResume() {
		super.onResume();
		invokeMethod("onResume");
	}
	
	@Override
	public void onStart() {
		super.onStart();
		invokeMethod("onStart");
	}
	
	@Override
	public void onStop() {
		super.onStop();
		invokeMethod("onStop");
	}
	
	@Override
	public void onDestroy() {
		super.onDestroy();
		invokeMethod("onDestroy");
	}
	
	public void log(String msg) {
		Lua.log(msg);
	}

}
