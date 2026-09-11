#define UNICODE
#define _UNICODE
#include <windows.h>
#include <shobjidl.h>
#include <shlwapi.h>
#include <string>

// Native shell command. No application code runs until Invoke.
static HMODULE module;
static LONG objects;
static const CLSID commandId = {0xfaa651e8,0xa70d,0x4e4f,{0x93,0xf6,0x93,0x79,0x83,0xb2,0xc7,0xa1}};
static std::wstring Folder() {
    wchar_t path[32768];
    DWORD n=GetModuleFileNameW(module,path,32768);
    if (!n || n>=32768) return L"";
    PathRemoveFileSpecW(path);
    return path;
}
static bool Supported(const wchar_t* path) {
    const wchar_t* ext=PathFindExtensionW(path);
    return !lstrcmpiW(ext,L".exe") || !lstrcmpiW(ext,L".lnk") || !lstrcmpiW(ext,L".url");
}
static std::wstring Quote(const std::wstring& s) {
    std::wstring out=L"\""; size_t slashes=0;
    for (wchar_t c:s) {
        if (c==L'\\') { ++slashes; continue; }
        out.append(slashes*(c==L'"'?2:1),L'\\'); slashes=0;
        if (c==L'"') out+=L'\\';
        out+=c;
    }
    out.append(slashes*2,L'\\'); out+=L'"'; return out;
}
static HRESULT Launch(IShellItemArray* items) {
    wchar_t app[32768];
    const auto ini=Folder()+L"\\app.ini";
    GetPrivateProfileStringW(L"Squeak",L"Folder",L"",app,32768,ini.c_str());
    if (!*app) {
        DWORD bytes=sizeof(app);
        if (RegGetValueW(HKEY_CURRENT_USER,L"Software\\Squeak",L"InstallDir",RRF_RT_REG_SZ,nullptr,app,&bytes)!=ERROR_SUCCESS) return HRESULT_FROM_WIN32(ERROR_PATH_NOT_FOUND);
    }
    wchar_t ps[MAX_PATH]; GetSystemDirectoryW(ps,MAX_PATH);
    std::wstring exe=std::wstring(ps)+L"\\WindowsPowerShell\\v1.0\\powershell.exe";
    std::wstring args=Quote(exe)+L" -NoProfile -WindowStyle Hidden -ExecutionPolicy Bypass -File "+Quote(std::wstring(app)+L"\\StartSafe.ps1");
    DWORD count=0;
    if (items) {
        HRESULT hr=items->GetCount(&count); if (FAILED(hr)) return hr;
        if (!count || count>100) return E_INVALIDARG;
    }
    for (DWORD i=0;i<count;++i) {
        IShellItem* item=nullptr; PWSTR path=nullptr;
        HRESULT hr=items->GetItemAt(i,&item);
        if (SUCCEEDED(hr)) { hr=item->GetDisplayName(SIGDN_FILESYSPATH,&path); item->Release(); }
        if (FAILED(hr)) return hr;
        bool ok=Supported(path);
        if (ok) args+=L" "+Quote(path);
        CoTaskMemFree(path);
        if (!ok) return E_INVALIDARG;
    }
    if (args.size()>30000) return E_INVALIDARG;
    STARTUPINFOW si={sizeof(si)}; si.dwFlags=STARTF_USESHOWWINDOW; si.wShowWindow=SW_HIDE;
    PROCESS_INFORMATION pi={};
    if (!CreateProcessW(exe.c_str(),&args[0],nullptr,nullptr,FALSE,CREATE_NO_WINDOW,nullptr,app,&si,&pi)) return HRESULT_FROM_WIN32(GetLastError());
    CloseHandle(pi.hThread); CloseHandle(pi.hProcess); return S_OK;
}
class Command final: public IExplorerCommand {
    LONG refs=1;
public:
    Command(){InterlockedIncrement(&objects);} ~Command(){InterlockedDecrement(&objects);}
    HRESULT STDMETHODCALLTYPE QueryInterface(REFIID id,void** p) override {
        if (!p) return E_POINTER; *p=nullptr;
        if (id==IID_IUnknown || id==__uuidof(IExplorerCommand)) {*p=static_cast<IExplorerCommand*>(this);AddRef();return S_OK;} return E_NOINTERFACE;
    }
    ULONG STDMETHODCALLTYPE AddRef() override {return InterlockedIncrement(&refs);}
    ULONG STDMETHODCALLTYPE Release() override {LONG n=InterlockedDecrement(&refs);if (!n) delete this;return n;}
    HRESULT STDMETHODCALLTYPE GetTitle(IShellItemArray*,PWSTR* p) override {return SHStrDupW(L"Int\x00e9grer \x00e0 Squeak",p);}
    HRESULT STDMETHODCALLTYPE GetIcon(IShellItemArray*,PWSTR* p) override {return SHStrDupW((Folder()+L"\\Squeak.ico").c_str(),p);}
    HRESULT STDMETHODCALLTYPE GetToolTip(IShellItemArray*,PWSTR* p) override { *p=nullptr;return E_NOTIMPL; }
    HRESULT STDMETHODCALLTYPE GetCanonicalName(GUID* p) override {*p=commandId;return S_OK;}
    HRESULT STDMETHODCALLTYPE GetState(IShellItemArray* a,BOOL,EXPCMDSTATE* p) override {
        *p=ECS_HIDDEN; if (!a) return S_OK; DWORD count=0;
        if (FAILED(a->GetCount(&count)) || !count || count>100) return S_OK;
        for(DWORD i=0;i<count;++i){
            IShellItem* item=nullptr; PWSTR path=nullptr;
            if(FAILED(a->GetItemAt(i,&item))) return S_OK;
            HRESULT hr=item->GetDisplayName(SIGDN_FILESYSPATH,&path);item->Release();
            if(FAILED(hr)) return S_OK;
            bool ok=Supported(path);CoTaskMemFree(path);if(!ok)return S_OK;
        }
        *p=ECS_ENABLED;return S_OK;
    }
    HRESULT STDMETHODCALLTYPE Invoke(IShellItemArray* a,IBindCtx*) override {if(!a)return E_INVALIDARG;try{return Launch(a);}catch(...){return E_OUTOFMEMORY;}}
    HRESULT STDMETHODCALLTYPE GetFlags(EXPCMDFLAGS* p) override {*p=ECF_DEFAULT;return S_OK;}
    HRESULT STDMETHODCALLTYPE EnumSubCommands(IEnumExplorerCommand** p) override {*p=nullptr;return E_NOTIMPL;}
};
class Factory final:public IClassFactory {
    LONG refs=1;
public:
    Factory(){InterlockedIncrement(&objects);} ~Factory(){InterlockedDecrement(&objects);}
    HRESULT STDMETHODCALLTYPE QueryInterface(REFIID id,void** p) override {*p=nullptr;if(id==IID_IUnknown||id==IID_IClassFactory){*p=this;AddRef();return S_OK;}return E_NOINTERFACE;}
    ULONG STDMETHODCALLTYPE AddRef() override {return InterlockedIncrement(&refs);}
    ULONG STDMETHODCALLTYPE Release() override {LONG n=InterlockedDecrement(&refs);if(!n)delete this;return n;}
    HRESULT STDMETHODCALLTYPE CreateInstance(IUnknown* outer,REFIID id,void** p) override {if(outer)return CLASS_E_NOAGGREGATION;try{Command* c=new Command;HRESULT hr=c->QueryInterface(id,p);c->Release();return hr;}catch(...){return E_OUTOFMEMORY;}}
    HRESULT STDMETHODCALLTYPE LockServer(BOOL lock) override {if(lock)InterlockedIncrement(&objects);else InterlockedDecrement(&objects);return S_OK;}
};
STDAPI DllGetClassObject(REFCLSID id,REFIID iid,void** p){if(id!=commandId)return CLASS_E_CLASSNOTAVAILABLE;try{Factory* f=new Factory;HRESULT hr=f->QueryInterface(iid,p);f->Release();return hr;}catch(...){return E_OUTOFMEMORY;}}
STDAPI DllCanUnloadNow(){return objects?S_FALSE:S_OK;}
BOOL WINAPI DllMain(HINSTANCE h,DWORD reason,LPVOID){if(reason==DLL_PROCESS_ATTACH){module=h;DisableThreadLibraryCalls(h);}return TRUE;}
int WINAPI wWinMain(HINSTANCE h,HINSTANCE,PWSTR,int){module=h;return FAILED(Launch(nullptr));}
