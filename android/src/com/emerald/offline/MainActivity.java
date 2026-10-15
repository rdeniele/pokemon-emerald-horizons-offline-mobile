package com.emerald.offline;
import android.app.Activity;
import android.os.Bundle;
import android.content.Intent;
import android.net.Uri;
import android.webkit.*;
import android.util.AtomicFile;
import android.view.View;
import android.view.WindowInsets;
import java.io.*;
import java.nio.charset.StandardCharsets;
import org.json.JSONObject;

public class MainActivity extends Activity {
  private WebView web;
  private String exportData;
  private static final String HOST="appassets.androidplatform.net";
  @Override public void onCreate(Bundle b){super.onCreate(b);web=new WebView(this);web.setBackgroundColor(0xffe9e1c9);setContentView(web);web.setOnApplyWindowInsetsListener((v,insets)->{v.setPadding(insets.getSystemWindowInsetLeft(),insets.getSystemWindowInsetTop(),insets.getSystemWindowInsetRight(),insets.getSystemWindowInsetBottom());return insets;});web.requestApplyInsets();WebSettings s=web.getSettings();s.setJavaScriptEnabled(true);s.setDomStorageEnabled(true);s.setAllowFileAccess(false);s.setAllowContentAccess(false);s.setMixedContentMode(WebSettings.MIXED_CONTENT_NEVER_ALLOW);s.setMediaPlaybackRequiresUserGesture(true);web.addJavascriptInterface(new LocalBridge(),"Native");web.setWebViewClient(new WebViewClient(){
    @Override public WebResourceResponse shouldInterceptRequest(WebView view,WebResourceRequest req){Uri u=req.getUrl();if(!"https".equals(u.getScheme())||!HOST.equals(u.getHost()))return blocked();String p=u.getPath();if(p==null||p.contains("..")||p.contains("\\"))return blocked();if(p.equals("/"))p="/index.html";try{String mime=p.endsWith(".js")?"text/javascript":p.endsWith(".css")?"text/css":p.endsWith(".html")?"text/html":p.endsWith(".gif")?"image/gif":p.endsWith(".png")?"image/png":p.endsWith(".mp3")?"audio/mpeg":p.endsWith(".woff2")?"font/woff2":"application/json";return new WebResourceResponse(mime,"UTF-8",getAssets().open(p.substring(1)));}catch(IOException e){return blocked();}}
    @Override public boolean shouldOverrideUrlLoading(WebView v,WebResourceRequest r){return !HOST.equals(r.getUrl().getHost());}
  });web.loadUrl("https://"+HOST+"/index.html");}
  private WebResourceResponse blocked(){return new WebResourceResponse("text/plain","UTF-8",new ByteArrayInputStream(new byte[0]));}
  public class LocalBridge {
    @JavascriptInterface public synchronized String load(String key){if(!key.equals("save")&&!key.equals("backup"))return "";try{AtomicFile f=new AtomicFile(new File(getFilesDir(),key+".json"));return new String(f.readFully(),StandardCharsets.UTF_8);}catch(IOException e){return "";}}
    @JavascriptInterface public synchronized boolean save(String key,String value){if((!key.equals("save")&&!key.equals("backup"))||value.length()>8000000)return false;AtomicFile f=new AtomicFile(new File(getFilesDir(),key+".json"));FileOutputStream out=null;try{out=f.startWrite();out.write(value.getBytes(StandardCharsets.UTF_8));f.finishWrite(out);return true;}catch(IOException e){if(out!=null)f.failWrite(out);return false;}}
    @JavascriptInterface public void exportSave(String value){exportData=value;runOnUiThread(()->{Intent i=new Intent(Intent.ACTION_CREATE_DOCUMENT);i.setType("application/json");i.addCategory(Intent.CATEGORY_OPENABLE);i.putExtra(Intent.EXTRA_TITLE,"emerald-horizons-save.json");startActivityForResult(i,10);});}
    @JavascriptInterface public void importSave(){runOnUiThread(()->{Intent i=new Intent(Intent.ACTION_OPEN_DOCUMENT);i.setType("*/*");i.addCategory(Intent.CATEGORY_OPENABLE);startActivityForResult(i,11);});}
  }
  @Override protected void onActivityResult(int request,int result,Intent data){super.onActivityResult(request,result,data);if(result!=RESULT_OK||data==null||data.getData()==null)return;try{if(request==10&&exportData!=null){try(OutputStream out=getContentResolver().openOutputStream(data.getData())){out.write(exportData.getBytes(StandardCharsets.UTF_8));}exportData=null;}else if(request==11){try(InputStream in=getContentResolver().openInputStream(data.getData());ByteArrayOutputStream out=new ByteArrayOutputStream()){byte[] buf=new byte[8192];int n,total=0;while((n=in.read(buf))!=-1){total+=n;if(total>8000000)throw new IOException("Save too large");out.write(buf,0,n);}String text=new String(out.toByteArray(),StandardCharsets.UTF_8);web.evaluateJavascript("window.importNativeSave("+JSONObject.quote(text)+")",null);}}}catch(IOException e){new android.app.AlertDialog.Builder(this).setMessage("Unable to read or write save: "+e.getMessage()).setPositiveButton("OK",null).show();}}
  @Override protected void onPause(){web.evaluateJavascript("window.pauseGame && window.pauseGame()",null);web.onPause();super.onPause();}
  @Override protected void onResume(){super.onResume();if(web!=null)web.onResume();}
  @Override public void onBackPressed(){web.evaluateJavascript("window.pauseGame && window.pauseGame()",null);}
}
