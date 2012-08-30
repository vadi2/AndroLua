package sk.kottman.androlua;

import android.app.Activity;
import android.content.ComponentName;
import android.content.Intent;
import android.content.ServiceConnection;
import android.os.Bundle;
import android.os.IBinder;

import android.text.method.ScrollingMovementMethod;
import android.view.View;
import android.view.View.OnClickListener;
import android.view.View.OnLongClickListener;
import android.widget.Button;
import android.widget.EditText;
import android.widget.TextView;
import android.widget.Toast;

public class Main extends Activity implements OnClickListener,
		OnLongClickListener, ServiceConnection {

	Intent luaIntent;
	static Main instance;
	Button execute;
	
	Lua service;
	
	// public so we can play with these from Lua
	public EditText source;
	public TextView status;

	/** Called when the activity is first created. */
	@Override
	public void onCreate(Bundle savedInstanceState) {
		super.onCreate(savedInstanceState);
		setContentView(R.layout.main);

		execute = (Button) findViewById(R.id.executeBtn);
		execute.setOnClickListener(this);

		source = (EditText) findViewById(R.id.source);
		source.setOnLongClickListener(this);
		source.setText("require 'import'\nprint(Math:sin(2.3))\n");

		status = (TextView) findViewById(R.id.statusText);
		status.setMovementMethod(ScrollingMovementMethod.getInstance());
		
		luaIntent = new Intent(this,Lua.class);
		ComponentName name = startService(luaIntent);
		if (name == null) {
			Lua.log("unable to start Lua service!");
		} else {
			Lua.log("started service " + name.toString());
		}
		
		bindService(luaIntent,this,BIND_AUTO_CREATE);
		
		instance = this;

	}

	@Override
	protected void onStart() {
		Lua.log("starting");
		super.onStart();
	}

	@Override
	protected void onStop() {
		Lua.log("stopping");
		super.onStop();
	}
	
	@Override
	protected void onDestroy() {		
		Lua.log("destroying");
		stopService(luaIntent);
		unbindService(this);
		super.onDestroy();
	}

	public void onClick(View view) {
		String src = source.getText().toString();
		if (service == null) {
			status.setText("unbound Lua service!");
			return;
		} else {
			status.setText("");
		}
		try {
			String res = service.evalLua(src);
			status.append(res);
			status.append("Finished succesfully");
		} catch(Exception e) {			
			Toast.makeText(this, e.getMessage(), Toast.LENGTH_LONG).show();			
		}
	}

	public boolean onLongClick(View view) {
		source.setText("");
		return true;
	}

	// Yay, Lua service is up...
	public void onServiceConnected(ComponentName name, IBinder iservice) {
		Lua.log("setting activity");		
		service = ((Lua.LocalBinder)iservice).getService();
		service.setGlobal("activity", this);
		
	}

	public void onServiceDisconnected(ComponentName name) {
		// Really should not be called!
		this.service = null;
		
	}
}