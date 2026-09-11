using System;
using System.IO;
using System.Text;
using System.Collections.Generic;
using System.Diagnostics;
using System.Runtime.InteropServices;
using System.Threading;
using System.Web.Script.Serialization;

internal static class SqueakBridge {
    static readonly JavaScriptSerializer Json = new JavaScriptSerializer { MaxJsonLength = 65536 };
    static Dictionary<string, object> config;
    [StructLayout(LayoutKind.Sequential)] struct CopyData { public IntPtr tag; public int size; public IntPtr data; }
    [DllImport("user32.dll", CharSet=CharSet.Unicode)] static extern IntPtr FindWindow(string cls, string title);
    [DllImport("user32.dll", CharSet=CharSet.Unicode, SetLastError=true)] static extern IntPtr SendMessageTimeout(IntPtr hwnd,uint msg,IntPtr w,ref CopyData data,uint flags,uint timeout,out UIntPtr result);
    static string Value(Dictionary<string,object> data,string key) { object value; return data.TryGetValue(key,out value) ? value as string : null; }
    static byte[] ReadExact(Stream input,int length) {
        byte[] bytes=new byte[length]; int offset=0;
        while(offset<length) { int count=input.Read(bytes,offset,length-offset); if(count==0) throw new EndOfStreamException(); offset+=count; }
        return bytes;
    }
    static void Reply(object result) {
        byte[] bytes=Encoding.UTF8.GetBytes(Json.Serialize(result));
        using(Stream output=Console.OpenStandardOutput()) { output.Write(BitConverter.GetBytes(bytes.Length),0,4); output.Write(bytes,0,bytes.Length); output.Flush(); }
    }
    [STAThread] static int Main(string[] args) {
        try {
            string folder=Path.GetDirectoryName(System.Reflection.Assembly.GetExecutingAssembly().Location);
            config=Json.Deserialize<Dictionary<string,object>>(File.ReadAllText(Path.Combine(folder,"bridge.json"),Encoding.UTF8));
            if(args.Length==0 || args[0]!=Value(config,"origin")) throw new Exception("Extension non autorisée.");
            Stream input=Console.OpenStandardInput();
            int size=BitConverter.ToInt32(ReadExact(input,4),0);
            if(size<2 || size>32768) throw new Exception("Requête trop volumineuse.");
            var request=Json.Deserialize<Dictionary<string,object>>(new UTF8Encoding(false,true).GetString(ReadExact(input,size)));
            string method=Value(request,"method");
            if(method!="status" && method!="add-site" && method!="add-page") throw new Exception("Action inconnue.");
            Uri url=WebUrl(Value(request,"url"));
            string site=Authority(url), page=Canonical(url);
            if(method!="status") {
                string item=method=="add-site" ? site : page;
                Add((method=="add-page"?"PAGE|":"ADD|")+item);
            }
            Reply(Status(url)); return 0;
        } catch(Exception error) {
            try { Reply(new {ok=false,error=error.Message}); } catch { }
            return 1;
        }
    }
    static Uri WebUrl(string value) {
        Uri uri;
        if(String.IsNullOrWhiteSpace(value) || value.Length>8192 || value.IndexOfAny(new[]{'\r','\n','\0','|','"'})>=0 || !Uri.TryCreate(value,UriKind.Absolute,out uri)
            || (uri.Scheme!="https" && uri.Scheme!="http") || uri.UserInfo!="" || uri.HostNameType!=UriHostNameType.Dns)
            throw new Exception("Adresse web invalide.");
        return uri;
    }
    static string Authority(Uri uri) { return uri.IdnHost.ToLowerInvariant()+(uri.IsDefaultPort?"":":"+uri.Port); }
    static string Canonical(Uri uri) { return Authority(uri)+uri.AbsolutePath.TrimEnd('/')+uri.Query+uri.Fragment; }
    static object Status(Uri current) {
        string site=Authority(current), page=Canonical(current);
        bool siteAdded=false,pageAdded=false,covered=false,enabled=false;
        string file=Value(config,"configFile") ?? Path.Combine(Value(config,"appDir"),"squeak_apps.txt");
        string[] lines=new string[0];
        for(int attempt=0;attempt<3;attempt++) {
            try { if(File.Exists(file)) lines=File.ReadAllLines(file,Encoding.UTF8); break; }
            catch(IOException) { if(attempt==2) throw; Thread.Sleep(50); }
        }
        foreach(string line in lines) {
            string[] fields=line.Split('|');
            if(fields.Length<3 || (fields[2]!="url" && fields[2]!="page")) continue;
            Uri pattern;
            try { pattern=WebUrl("https://"+fields[0]); } catch { continue; }
            string target=Canonical(pattern);
            bool exact=String.Equals(target,page,StringComparison.Ordinal);
            bool isSite=fields[2]=="url" && String.Equals(target,site,StringComparison.Ordinal);
            bool matches=fields[2]=="page" ? exact : MatchPattern(current,pattern);
            siteAdded|=isSite;
            pageAdded|=fields[2]=="page" && exact;
            covered|=matches;
            enabled|=matches && fields[1]=="1";
        }
        return new {ok=true,siteAdded=siteAdded,pageAdded=pageAdded,covered=covered,enabled=enabled};
    }
    static bool MatchPattern(Uri current,Uri pattern) {
        if(Authority(current)!=Authority(pattern)) return false;
        string p=pattern.AbsolutePath.TrimEnd('/'), c=current.AbsolutePath.TrimEnd('/');
        if(p!="" && c!=p && !c.StartsWith(p+"/",StringComparison.Ordinal)) return false;
        return (pattern.Query=="" || pattern.Query==current.Query) && (pattern.Fragment=="" || pattern.Fragment==current.Fragment);
    }
    static void Add(string message) {
        string title=Value(config,"windowTitle") ?? "Squeak 2.2";
        IntPtr hwnd=FindWindow("AutoHotkeyGUI",title);
        if(hwnd==IntPtr.Zero) {
            string script=Path.Combine(Value(config,"appDir"),"Squeak.ahk");
            if(!File.Exists(script)) throw new Exception("Squeak est introuvable.");
            var start=new ProcessStartInfo(Value(config,"autoHotkey"),"/CP65001 \""+script+"\"") {UseShellExecute=false,CreateNoWindow=true,WorkingDirectory=Value(config,"appDir")};
            Process.Start(start);
            for(int i=0;i<50 && hwnd==IntPtr.Zero;i++) { Thread.Sleep(100); hwnd=FindWindow("AutoHotkeyGUI",title); }
        }
        if(hwnd==IntPtr.Zero) throw new Exception("Squeak n’a pas démarré.");
        byte[] bytes=Encoding.Unicode.GetBytes(message+"\0");
        if(bytes.Length>32768) throw new Exception("Adresse trop longue.");
        IntPtr ptr=Marshal.AllocHGlobal(bytes.Length);
        try {
            Marshal.Copy(bytes,0,ptr,bytes.Length);
            var data=new CopyData {tag=new IntPtr(1),size=bytes.Length,data=ptr};
            UIntPtr result;
            if(SendMessageTimeout(hwnd,0x4A,IntPtr.Zero,ref data,2,5000,out result)==IntPtr.Zero)
                throw new Exception("Squeak ne répond pas. Réessayez.");
            if(result.ToUInt64()!=1) throw new Exception("Ajout refusé. Vérifiez Squeak et réessayez.");
        } finally { Marshal.FreeHGlobal(ptr); }
    }
}
