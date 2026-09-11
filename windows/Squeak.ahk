#Requires AutoHotkey v2.0
#SingleInstance Off
Persistent
SetWorkingDir A_ScriptDir
DetectHiddenWindows false
SetTitleMatchMode 3
global testMode := EnvGet("SQUEAK_TEST") = "1" || (A_Args.Length && InStr(A_Args[1], "test"))
global windowTitle := A_Args.Length && A_Args[1]="--test-preview" ? "Squeak 2.2 Aperçu" : testMode ? "Squeak 2.2 Tests" : "Squeak 2.2"
global configFile := A_ScriptDir "\squeak_apps.txt", settingsFile := A_ScriptDir "\settings.ini"
global appList := [], mainGui := "", appLv := "", statusText := ""
global refreshing := false, busy := false, activeHotkey := ""
if EnvGet("SQUEAK_TEST") = "1" || (A_Args.Length && (A_Args[1] = "--self-test" || A_Args[1] = "--integration-test"))
    OnError(TestFailure)
testServer := A_Args.Length && A_Args[1] = "--test-server"
if testServer {
    DirCreate(A_ScriptDir "\test-output")
    configFile := A_ScriptDir "\test-output\ipc-apps.txt"
}
if A_Args.Length && A_Args[1] = "--test-preview" {
    DirCreate(A_ScriptDir "\test-output")
    previewConfig := A_ScriptDir "\test-output\preview-apps.txt"
    if !FileExist(previewConfig) && FileExist(configFile)
        FileCopy(configFile,previewConfig)
    configFile := previewConfig
}
if A_Args.Length && A_Args[1] = "--self-test" {
    RunTests()
    ExitApp()
}
if A_Args.Length && A_Args[1] = "--integration-test" {
    RunIntegrationTests()
    ExitApp()
}
; Startup mutex serializes simultaneous Explorer requests, including first launch.
mutex := DllCall("CreateMutex", "Ptr", 0, "Int", 0, "Str", testMode ? "Local\Squeak22TestStartup" : "Local\Squeak22Startup", "Ptr")
waitResult := DllCall("WaitForSingleObject", "Ptr", mutex, "UInt", 10000)
if waitResult != 0 && waitResult != 0x80
    ExitApp(1)
DetectHiddenWindows true
existing := WinExist(windowTitle " ahk_class AutoHotkeyGUI")
if existing {
    result := 0
    try {
        if A_Args.Length >= 2 && A_Args[1] = "--add" {
            Loop A_Args.Length - 1
                SendToInstance(existing, "ADD|" A_Args[A_Index + 1])
        } else
            SendToInstance(existing, "SHOW")
    } catch as err {
        if EnvGet("SQUEAK_TEST") = "1"
            FileAppend("FAIL: " err.Message " at " err.Line "`n", "*")
        else
            MsgBox("Squeak ne répond pas : " err.Message)
        result := 1
    }
    DllCall("ReleaseMutex", "Ptr", mutex)
    DllCall("CloseHandle", "Ptr", mutex)
    ExitApp(result)
}
DetectHiddenWindows false
try {
    LoadApps()
    BuildGui()
    OnMessage(0x004A, ReceiveData)
} catch as err {
    MsgBox("Impossible de démarrer Squeak : " err.Message)
    ExitApp(1)
} finally {
    DllCall("ReleaseMutex", "Ptr", mutex)
    DllCall("CloseHandle", "Ptr", mutex)
}
if FileExist(A_ScriptDir "\Squeak.ico")
    TraySetIcon(A_ScriptDir "\Squeak.ico")
A_TrayMenu.Delete()
A_TrayMenu.Add("Ouvrir Squeak", (*) => mainGui.Show())
A_TrayMenu.Add("Fermer maintenant", (*) => CloseSelected())
A_TrayMenu.Add("Quitter", (*) => ExitApp())
A_TrayMenu.Default := "Ouvrir Squeak"
try {
    if !testMode
        SetShortcut(IniRead(settingsFile, "Keyboard", "Hotkey", "~p & Delete"), false)
}
catch as err
    SetStatus("Raccourci invalide : " err.Message)
if A_Args.Length >= 2 && A_Args[1] = "--add" {
    Loop A_Args.Length - 1
        AddRaw(A_Args[A_Index + 1])
}
if !testServer
    ShowGold()

SendToInstance(hwnd, data) {
    bytes := (StrLen(data) + 1) * 2
    payloadBuffer := Buffer(bytes, 0)
    StrPut(data, payloadBuffer, "UTF-16")
    cds := Buffer(A_PtrSize * 3, 0)
    NumPut("UPtr", 1, cds, 0)
    NumPut("UInt", bytes, cds, A_PtrSize)
    NumPut("Ptr", payloadBuffer.Ptr, cds, 2 * A_PtrSize)
    DetectHiddenWindows true
    if !SendMessage(0x004A, 0, cds.Ptr, , "ahk_id " hwnd, , , , 5000)
        throw Error("Ajout refusé ou traitement en cours. Réessaie.")
}
ReceiveData(wParam, lParam, *) {
    if busy
        return 0
    bytes := NumGet(lParam, A_PtrSize, "UInt")
    if bytes < 2 || bytes > 32768 || Mod(bytes, 2)
        return 0
    ptr := NumGet(lParam, A_PtrSize * 2, "Ptr")
    if !ptr
        return 0
    data := StrGet(ptr, bytes // 2 - 1, "UTF-16")
    if data = "HEALTH"
        return IsObject(appLv) && activeHotkey != "" ? 22 : 0
    mainGui.Show()
    if data = "SHOW"
        return 1
    if SubStr(data, 1, 5) = "PAGE|"
        return AddRaw(SubStr(data, 6), "page")
    if SubStr(data, 1, 4) = "ADD|"
        return AddRaw(SubStr(data, 5))
    return 0
}
NormalizeItem(value, depth := 0) {
    value := Trim(value, " `"`t`r`n")
    if depth > 5 || value = "" || RegExMatch(value, "[|\r\n]")
        throw Error("Élément invalide.")
    if FileExist(value) {
        SplitPath(value, &name, , &ext)
        if StrLower(ext) = "lnk" {
            FileGetShortcut(value, &target)
            return NormalizeItem(target, depth + 1)
        }
        if StrLower(ext) = "url"
            return NormalizeItem(IniRead(value, "InternetShortcut", "URL", ""), depth + 1)
        if StrLower(ext) != "exe"
            throw Error("Choisis un programme .exe ou un raccourci.")
        value := name
    }
    if RegExMatch(value, "i)\.exe$") && !InStr(value, "/") {
        SplitPath(value, &name)
        if RegExMatch(name, '[<>:"/\\|?*]') || StrLen(name) <= 4
            throw Error("Nom de programme invalide.")
        return {name: name, kind: "program", enabled: true, force: false}
    }
    if InStr(value, ".") || InStr(value, "/") {
        url := ParseUrl(value)
        return {name: url.host url.path url.query url.fragment, kind: "url", enabled: true, force: false}
    }
    return NormalizeItem(value ".exe", depth + 1)
}
ParseUrl(value) {
    value := RegExReplace(Trim(value), "i)^https?://", "")
    if !RegExMatch(value, "^([^/?#]+)(/[^?#]*)?(\?[^#]*)?(#.*)?$", &parts)
        throw Error("URL invalide.")
    host := StrLower(parts[1])
    if !RegExMatch(host, "i)^(?:[a-z0-9](?:[a-z0-9-]*[a-z0-9])?\.)+[a-z]{2,}(?::[0-9]+)?$")
        throw Error("Domaine invalide.")
    return {host: host, path: RTrim(parts[2], "/"), query: parts[3], fragment: parts[4]}
}
UrlMatches(current, pattern, exact := false) {
    try {
        actual := ParseUrl(current), expected := ParseUrl(pattern)
        if (exact ? actual.host != expected.host : RegExReplace(actual.host, "^www\.") != RegExReplace(expected.host, "^www\."))
            return false
        if exact
            return actual.path == expected.path && actual.query == expected.query && actual.fragment == expected.fragment
        if expected.query != "" && actual.query !== expected.query
            return false
        if expected.fragment != "" && actual.fragment !== expected.fragment
            return false
        return expected.path = "" || actual.path == expected.path
            || InStr(actual.path, expected.path "/", true) = 1
    } catch
        return false
}
LoadApps() {
    global appList
    if !FileExist(configFile)
        return
    seen := Map()
    for line in StrSplit(FileRead(configFile, "UTF-8"), "`n", "`r") {
        if Trim(line) = ""
            continue
        fields := StrSplit(line, "|")
        item := NormalizeItem(fields[1])
        if fields.Length>=3 && fields[3]="page" && item.kind="url"
            item.kind := "page"
        item.enabled := fields.Length >= 2 && fields[2] = "1"
        item.force := item.kind = "program" && fields.Length >= 4 && fields[4] = "1"
        key := (item.kind="program" ? StrLower(item.name) : item.name) "|" item.kind
        if !seen.Has(key) {
            appList.Push(item)
            seen[key] := true
        }
    }
}
SaveApps() {
    Critical "On"
    text := ""
    for item in appList
        text .= item.name "|" (item.enabled ? 1 : 0) "|" item.kind "|" (item.force ? 1 : 0) "`n"
    temporary := configFile ".tmp"
    try {
        file := FileOpen(temporary, "w", "UTF-8")
        file.Write(text)
        DllCall("FlushFileBuffers", "Ptr", file.Handle)
        file.Close()
        if FileRead(temporary, "UTF-8") != text
            throw Error("Vérification de sauvegarde échouée.")
        if FileExist(configFile)
            FileCopy(configFile, configFile ".bak", true)
        if !DllCall("MoveFileExW", "Str", temporary, "Str", configFile, "UInt", 9)
            throw OSError()
        return true
    } catch as err {
        SetStatus("Réglages non enregistrés : " err.Message)
        return false
    } finally {
        Critical "Off"
    }
}
BuildGui() {
    BuildGoldGui()
}
SetStatus(message) {
    if IsObject(statusText)
        statusText.Value := message
}
RefreshList() {
    global refreshing
    refreshing := true
    try {
        appLv.Delete()
        for item in appList
            appLv.Add(item.enabled ? "Check" : "", item.name, item.kind, item.force ? "Oui" : "Non", "—")
        appLv.ModifyCol(1, 360), appLv.ModifyCol(2, 95), appLv.ModifyCol(3, 75), appLv.ModifyCol(4, 245)
    } finally
        refreshing := false
}
ItemChecked(control, row, checked) {
    if refreshing || busy
        return
    appList[row].enabled := checked
    SaveApps()
}
AddFromInput() {
    if AddRaw(inputApp.Value)
        inputApp.Value := ""
}
AddRaw(raw, kindOverride := "") {
    if busy
        return false
    try {
        item := NormalizeItem(raw)
        if kindOverride="page" {
            if item.kind!="url"
                throw Error("Une page doit être une adresse web.")
            item.kind := "page"
        }
        for existing in appList {
            if (item.kind="program" ? StrLower(existing.name)=StrLower(item.name) : existing.name==item.name) && existing.kind = item.kind {
                SetStatus("Déjà présent : " item.name)
                return SaveApps()
            }
        }
        appList.Push(item)
        RefreshList()
        if !SaveApps()
            return false
        SetStatus("Ajouté : " item.name)
        return true
    } catch as err {
        SetStatus(err.Message)
        return false
    }
}
RemoveItem() {
    if busy || !(row := appLv.GetNext())
        return
    appList.RemoveAt(row)
    RefreshList()
    if SaveApps()
        SetStatus("Élément retiré.")
}
ToggleForce() {
    if busy || !(row := appLv.GetNext())
        return
    item := appList[row]
    if item.kind != "program"
        return
    if !item.force && MsgBox("Autoriser la fermeture forcée de " item.name " ? Les documents non enregistrés peuvent être perdus.", "Squeak", "YesNo Icon!") != "Yes"
        return
    item.force := !item.force
    RefreshList()
    SaveApps()
}
SetShortcut(value, persist := true) {
    global activeHotkey
    if value != "~p & Delete" && (value = "" || !RegExMatch(value, "[!^+#]"))
        throw Error("Choisis P + Suppr ou un raccourci avec Ctrl, Alt ou Maj.")
    if value = activeHotkey
        return
    Hotkey(value, value="~p & Delete" ? CloseWithPDelete : (*) => CloseSelected(), "On")
    try {
        if persist
            IniWrite(value, settingsFile, "Keyboard", "Hotkey")
    } catch as err {
        Hotkey(value, "Off")
        throw err
    }
    if activeHotkey != ""
        Hotkey(activeHotkey, "Off")
    activeHotkey := value
    defaultShortcut.Value := value="~p & Delete"
    shortcutInput.Enabled := value!="~p & Delete"
    if value!="~p & Delete"
        shortcutInput.Value := value
    UpdateGoldShortcut()
}
CloseWithPDelete(*) {
    try CloseSelected()
    finally KeyWait("Delete")
}
ChangeShortcut() {
    try {
        SetShortcut(shortcutInput.Value)
        SetStatus("Raccourci enregistré.")
    } catch as err
        SetStatus(err.Message)
}
CloseSelected() {
    global busy
    if busy
        return
    busy := true
    browser := WinExist("A")
    appLv.Enabled := false
    try {
        if !SaveApps()
            return
        urlRows := [], programRows := []
        for row, item in appList {
            if item.enabled {
                if item.kind != "program"
                    urlRows.Push(row)
                else
                    programRows.Push(row)
            }
        }
        if urlRows.Length {
            result := CloseActiveUrl(browser, urlRows)
            for row in urlRows
                appLv.Modify(row, "", , , , result.row && row != result.row ? "Aucune correspondance" : result.text)
        }
        for row in programRows {
            result := CloseProgram(appList[row])
            appLv.Modify(row, "", , , , result)
        }
        SetStatus(urlRows.Length + programRows.Length ? "Traitement terminé. Consulte les résultats, les applications encore ouvertes sont conservées." : "Coche au moins un élément.")
    } catch as err
        SetStatus("Traitement interrompu : " err.Message)
    finally {
        busy := false
        appLv.Enabled := true
    }
}
CloseProgram(item) {
    windows := WinGetList("ahk_exe " item.name)
    if !ProcessExist(item.name)
        return "Introuvable"
    failed := false
    for hwnd in windows {
        try WinClose("ahk_id " hwnd)
        catch
            failed := true
    }
    deadline := A_TickCount + 2200
    while ProcessExist(item.name) && A_TickCount < deadline
        Sleep(100)
    if item.force {
        pids := []
        for process in ComObjGet("winmgmts:").ExecQuery("SELECT ProcessId, Name FROM Win32_Process") {
            if StrLower(process.Name) = StrLower(item.name)
                pids.Push(process.ProcessId)
        }
        for pid in pids {
            try {
                if StrLower(ProcessGetName(pid)) = StrLower(item.name)
                    ProcessClose(pid)
            } catch
                failed := true
        }
        Sleep(200)
    }
    if !ProcessExist(item.name)
        return "Fermé"
    return failed ? "Échec / encore ouvert" : "Encore ouvert"
}
EnsureActive(hwnd) {
    if !hwnd || !WinActive("ahk_id " hwnd)
        throw Error("Fenêtre active changée, fermeture URL annulée.")
}
CloseActiveUrl(hwnd, rows) {
    try {
        EnsureActive(hwnd)
        exe := StrLower(WinGetProcessName("ahk_id " hwnd))
        if !RegExMatch(exe, "^(chrome|msedge|firefox|brave|opera)\.exe$")
            return {row: 0, text: "Navigateur non actif"}
        saved := ClipboardAll()
        try {
            EnsureActive(hwnd)
            A_Clipboard := ""
            Send("^l")
            Sleep(100)
            EnsureActive(hwnd)
            Send("^c")
            if !ClipWait(0.7)
                return {row: 0, text: "Lecture URL impossible"}
            current := Trim(A_Clipboard)
            EnsureActive(hwnd)
            Send("{Esc}")
            for row in rows {
                if UrlMatches(current, appList[row].name, appList[row].kind="page") {
                    EnsureActive(hwnd)
                    Send("^w")
                    return {row: row, text: "Fermeture demandée"}
                }
            }
            return {row: 0, text: "Aucune correspondance"}
        } finally {
            A_Clipboard := saved
        }
    } catch as err
        return {row: 0, text: "Annulé : focus / lecture"}
}
RunTests() {
    cases := [
        ["https://youtube.com/watch?v=1", "youtube.com", true],
        ["https://youtube.com.evil.org/", "youtube.com", false],
        ["https://example.org/?next=youtube.com", "youtube.com", false],
        ["https://www.youtube.com/", "youtube.com", true],
        ["https://site.fr/page/enfant", "site.fr/page", true],
        ["https://site.fr/page-autre", "site.fr/page", false],
        ["https://site.fr/Page", "site.fr/page", false],
        ["https://site.fr/page?id=2", "site.fr/page?id=1", false],
        ["https://site.fr/page?id=1", "site.fr/page?id=1", true]]
    for test in cases {
        if UrlMatches(test[1], test[2]) != test[3]
            throw Error("URL test failed: " test[1])
    }
    for name in ["chrome.exe", "My Application.exe", "Discord"] {
        if NormalizeItem(name).kind != "program"
            throw Error("Program test failed")
    }
    FileAppend("PASS: 12 normalization and URL tests`n", "*")
    Assert(UrlMatches("https://site.fr/page?id=1","site.fr/page?id=1",true),"exact page matches")
    Assert(UrlMatches("https://youtube.com/", "www.youtube.com"), "www alias matches both directions")
    Assert(!UrlMatches("https://music.youtube.com/", "youtube.com"), "other subdomains remain separate")
    Assert(!UrlMatches("https://www.youtube.com/", "youtube.com", true), "exact pages retain exact host")
    Assert(!UrlMatches("https://site.fr/page/enfant","site.fr/page",true),"exact page excludes descendants")
    Assert(!UrlMatches("https://site.fr/page?id=2","site.fr/page",true),"exact page excludes another query")
    Assert(!UrlMatches("https://site.fr/Page","site.fr/page",true),"exact page preserves case")
    Assert(SiteIconPath({name:"youtube.com",kind:"url"})=A_ScriptDir "\theme\youtube.png","bundled icon matches actual domain")
    Assert(SiteIconPath({name:"example.org/youtube.com",kind:"url"})=A_ScriptDir "\theme\logo.png","URL path does not impersonate site icon")
    if FileExist(A_ScriptDir "\site-icons\instagram.com.png")
        Assert(SiteIconPath({name:"instagram.com/profile",kind:"url"})=A_ScriptDir "\site-icons\instagram.com.png","Instagram cached icon reused across paths")
}
Assert(condition, label) {
    if !condition
        throw Error("FAIL: " label)
    FileAppend("PASS: " label "`n", "*")
}
TestFailure(err, *) {
    FileAppend("FAIL: " err.Message " at " err.Line "`n", "*")
    ExitApp(1)
}
RunIntegrationTests() {
    global configFile, appList
    testDir := A_ScriptDir "\test-output"
    DirCreate(testDir)
    configFile := testDir "\apps.txt"
    appList := []
    BuildGui()
    Assert(SaveApps(), "save empty list")
    LoadApps()
    Assert(appList.Length = 0, "empty list remains empty")
    Assert(AddRaw("My Application.exe"), "add name with spaces")
    Assert(AddRaw("chrome.exe"), "add executable")
    Sleep(50)
    Assert(appList.Length = 2 && appLv.GetCount() = 2, "UI refresh preserves full list")
    Assert(appList[1].name = "My Application.exe", "spaces preserved")
    appList[1].enabled := false
    appList[2].force := true
    Assert(SaveApps(), "save selection and force flag")
    LoadApps()
    Assert(!appList[1].enabled && appList[2].force, "reload selection and force flag")
    Assert(FileExist(configFile ".bak"), "backup exists")
    before := FileRead(configFile, "UTF-8")
    lock := FileOpen(configFile, "r", "UTF-8")
    ; A directory at the temporary file path reliably simulates a write failure.
    DirCreate(configFile ".tmp")
    try {
        Assert(!SaveApps(), "write failure reported")
        Assert(FileRead(configFile, "UTF-8") = before, "write failure preserves configuration")
    } finally {
        lock.Close()
        DirDelete(configFile ".tmp")
    }
    Assert(NormalizeItem("https://example.org/download.exe").kind = "url", "URL ending exe remains URL")
    Assert(CloseProgram({name: "SqueakNonexistentFixture.exe", force: false}) = "Introuvable", "missing process reported")
    Assert(CloseActiveUrl(0, []).text = "Annulé : focus / lecture", "invalid focus cancels URL action")
    appList := []
    RefreshList()
    SaveApps()
    LoadApps()
    Assert(appList.Length = 0, "deleting last item persists")
    Loop 7
        Assert(AddRaw("SqueakRow" A_Index ".exe"), "add paginated row " A_Index " : " statusText.Value)
    appLv.PageBy(1)
    Assert(appLv.page=2 && appLv.RowFor(1)=6,"second page maps to sixth row")
    appLv.Toggle(1)
    Assert(!appList[6].enabled && appList[1].enabled,"checkbox targets correct page")
    appLv.Select(1)
    RemoveItem()
    Assert(appList.Length=6 && appList[6].name="SqueakRow7.exe","remove targets selected page")
    appList := []
    RefreshList()
    SaveApps()
    fixtureExe := testDir "\SqueakTestFixture.exe"
    FileCopy(A_AhkPath, fixtureExe, true)
    fixtureScript := testDir "\fixture.ahk"
    fixtureCode := '#Requires AutoHotkey v2.0`n#SingleInstance Off`ng := Gui(, "Squeak test fixture")`ng.AddText(, "Test Squeak uniquement")`nif A_Args.Length && A_Args[1] = "refuse"`n    g.OnEvent("Close", (*) => true)`nelse`n    g.OnEvent("Close", (*) => ExitApp())`ng.Show("Minimize")'
    fixtureFile := FileOpen(fixtureScript, "w", "UTF-8")
    fixtureFile.Write(fixtureCode)
    fixtureFile.Close()
    for mode in ["normal", "refuse"] {
        Run('"' fixtureExe '" "' fixtureScript '" ' mode, , , &pid)
        try {
            Assert(WinWait("ahk_pid " pid, , 3), "fixture window ready " mode)
            result := CloseProgram({name: "SqueakTestFixture.exe", force: false})
            Assert(result = (mode = "normal" ? "Fermé" : "Encore ouvert"), "normal closure respects refusal " mode)
            if mode = "refuse"
                Assert(CloseProgram({name: "SqueakTestFixture.exe", force: true}) = "Fermé", "explicit force closes fixture")
        } finally {
            if ProcessExist(pid)
                ProcessClose(pid)
        }
    }
}

#Include Theme.ahk
#Include SiteIcons.ahk
