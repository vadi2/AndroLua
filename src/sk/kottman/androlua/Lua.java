package sk.kottman.androlua;

import android.app.Service;
import android.content.Context;
import android.content.Intent;
import android.content.res.AssetManager;
import android.os.Binder;
import android.os.Handler;
import android.os.IBinder;
import android.os.IInterface;
import android.os.Parcel;
import android.os.RemoteException;
import android.util.Log;

import java.io.*;
import java.net.*;

import org.keplerproject.luajava.*;

public class Lua extends Service {
	private final static int LISTEN_PORT = 3333, PRINT_PORT = 3334;
	private final static char REPLACE = '\001';
	public static LuaState L;
	boolean printToString = true;
	PrintWriter printer = null;
	
	static final StringBuilder output = new StringBuilder();

	Handler handler;
	ServerThread serverThread;
	
	// the binder just returns this service...
	public class LocalBinder extends Binder {
		Lua getService() {
			return Lua.this;
		}
	}
	
	private final IBinder binder = new LocalBinder();	

	
	@Override
	public int onStartCommand (Intent intent, int flags, int startid) {
		handler = new Handler();
		
		log("starting Lua service");

		L = LuaStateFactory.newLuaState();
		L.openLibs();
		

		try {
			setGlobal("service",this);
			
			JavaFunction print = new JavaFunction(L) {
				@Override
				public int execute() throws LuaException {
					for (int i = 2; i <= L.getTop(); i++) {
						int type = L.type(i);
						String stype = L.typeName(type);
						String val = null;
						if (stype.equals("userdata")) {
							Object obj = L.toJavaObject(i);
							if (obj != null)
								val = obj.toString();
						} else if (stype.equals("boolean")) {
							val = L.toBoolean(i) ? "true" : "false";
						} else {
							val = L.toString(i);
						}
						if (val == null)
							val = stype;						
						output.append(val);
						output.append("\t");
					}
					output.append("\n");
					
					if (! printToString && printer != null) {
						printer.println(output.toString() + REPLACE);
						printer.flush();
						output.setLength(0);						
					}
					
					return 0;
				}
			};
			
			JavaFunction assetLoader = new JavaFunction(L) {
				@Override
				public int execute() throws LuaException {
					String name = L.toString(-1);

					AssetManager am = getAssets();
					try {
						InputStream is = am.open(name + ".lua");
						byte[] bytes = readAll(is);
						L.LloadBuffer(bytes, name);
						return 1;
					} catch (Exception e) {
						ByteArrayOutputStream os = new ByteArrayOutputStream();
						e.printStackTrace(new PrintStream(os));
						L.pushString("Cannot load module "+name+":\n"+os.toString());
						return 1;
					}
				}
			};				

			print.register("print");	
			
			L.getGlobal("package");            // package
			L.getField(-1, "loaders");         // package loaders
			int nLoaders = L.objLen(-1);       // package loaders
			
			L.pushJavaFunction(assetLoader);   // package loaders loader
			L.rawSetI(-2, nLoaders + 1);       // package loaders
			L.pop(1);                          // package
						
			L.getField(-1, "path");            // package path
			String customPath = getFilesDir() + "/?.lua";
			L.pushString(";" + customPath);    // package path custom
			L.concat(2);                       // package pathCustom
			L.setField(-2, "path");            // package
			L.pop(1);
		} catch (Exception e) {
			log("Cannot override print "+e.getMessage());
		}			
		
		serverThread = new ServerThread();
		serverThread.start();
		
		
		return START_STICKY;
	}

	// currently this is just so that the main activity knows when the service is up...
	// will support a remote script running option
	@Override
	public IBinder onBind(Intent intent) {
		return binder;
	}
	
	public void launchLuaActivity(Context context, String mod) {
		boolean fromActivity = context != null;
		if (! fromActivity) {
			context = this;
		}		
		Intent intent = new Intent(context, LuaActivity.class);
		
		if (! fromActivity) {
			intent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK);
			intent.addFlags(Intent.FLAG_ACTIVITY_MULTIPLE_TASK);
		}
		
		intent.putExtra("LUA_MODULE", mod);
		context.startActivity(intent);
	}	
	
	@Override
	public void onDestroy() {
		super.onDestroy();
		log("destroying Lua service");
		serverThread.close();
		L.close();
	}
	
	public static void log(String msg) {
		Log.d("lua",msg);
	}
	
	public String evalLua(String src) throws LuaException {
		L.setTop(0);
		int ok = L.LloadString(src);
		if (ok == 0) {
			L.getGlobal("debug");
			L.getField(-1, "traceback");
			L.remove(-2);
			L.insert(-2);
			printToString = true;
			ok = L.pcall(0, 0, -2);
			printToString = false;
			if (ok == 0) {				
				String res = output.toString();
				output.setLength(0);
				return res;
			}
		}
		throw new LuaException(errorReason(ok) + ": " + L.toString(-1));
		//return null;		
		
	}	
	
	public void setGlobal(String name, Object value) {
		L.pushJavaObject(value);
		L.setGlobal(name);
	}
	
	String safeEvalLua(String src) {
		String res = null;	
		try {
			res = evalLua(src);
		} catch(LuaException e) {
			res = e.getMessage()+"\n";
		}
		return res;		
	}	
	
	private static String errorReason(int error) {
		switch (error) {
		case 4:
			return "Out of memory";
		case 3:
			return "Syntax error";
		case 2:
			return "Runtime error";
		case 1:
			return "Yield error";
		}
		return "Unknown error " + error;
	}
	
	private class ServerThread extends Thread {
		public boolean stopped;
		public Socket client, writer;
		public ServerSocket server;

		@Override
		public void run() {
			stopped = false;
			try {
				server = new ServerSocket(LISTEN_PORT);
				log("Server started on port " + LISTEN_PORT);
				while (!stopped) {
					client = server.accept();					
					BufferedReader in = new BufferedReader(
							new InputStreamReader(client.getInputStream()));
					final PrintWriter out = new PrintWriter(client.getOutputStream());
					String line = in.readLine();
					if (line.equals("yes")) {
						ServerSocket writeServer = new ServerSocket(PRINT_PORT);
						out.println("waiting ");
						out.flush();						
						writer = writeServer.accept();
						printer = new PrintWriter(writer.getOutputStream());						
					}
					while (!stopped && (line = in.readLine()) != null) {						
						final String s = line.replace(REPLACE, '\n');
						if (s.startsWith("--mod:")) {
							int i1 = s.indexOf(':'), i2 = s.indexOf('\n');
							String mod = s.substring(i1+1,i2); 
							String file = getFilesDir()+"/"+mod.replace('.', '/')+".lua";
							FileWriter fw = new FileWriter(file);
							fw.write(s);
							fw.close();	
							// package.loaded[mod] = nil
							L.getGlobal("package");
							L.getField(-1, "loaded");
							L.pushNil();
							L.setField(-2, mod);
							out.println("wrote " + file + REPLACE);
							out.flush();
						} else {
							handler.post(new Runnable() {
								public void run() {
									String res = safeEvalLua(s);
									res = res.replace('\n', REPLACE);
									out.println(res);
									out.flush();
								}
							});
						}
					}
				}
				server.close();
			} catch (Exception e) {
				log(e.toString());
			}
		}

		public void close() {
			try {
				client.close();
				if (writer != null)
					writer.close();
				server.close();
			} catch(Exception e) {
				log("problem closing sockets " + e.getMessage());
			}
		}
	}
	
	private static byte[] readAll(InputStream input) throws Exception {
		ByteArrayOutputStream output = new ByteArrayOutputStream(4096);
		byte[] buffer = new byte[4096];
		int n = 0;
		while (-1 != (n = input.read(buffer))) {
			output.write(buffer, 0, n);
		}
		return output.toByteArray();
	}	
	

}
