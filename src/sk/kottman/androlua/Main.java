package sk.kottman.androlua;

import android.app.Activity;
import android.content.ComponentName;
import android.content.Intent;
import android.content.ServiceConnection;
import android.os.Bundle;
import android.os.IBinder;

import android.text.method.ScrollingMovementMethod;
import android.util.Log;
import android.view.View;
import android.view.View.OnClickListener;
import android.view.View.OnLongClickListener;
import android.widget.Button;
import android.widget.EditText;
import android.widget.TextView;
import android.widget.Toast;

public class Main extends LuaActivity  {


	/** Called when the activity is first created. */
	@Override
	public void onCreate(Bundle savedInstanceState) {
		//Intent intent = getIntent();
		CharSequence mod = getResources().getText(R.string.main_module);
		getIntent().putExtra("LUA_MODULE", mod);
		//setIntent(intent);
		super.onCreate(savedInstanceState);

	}
	
}