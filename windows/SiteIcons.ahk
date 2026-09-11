; Fetch in a separate process so adding a URL never blocks the window.
SiteIconPath(row) {
    static requested := Map()
    fallback := A_ScriptDir "\theme\logo.png"
    if row.kind = "program" {
        program := StrLower(RegExReplace(row.name,"i)\.exe$",""))
        return FileExist(A_ScriptDir "\theme\" program ".png") ? A_ScriptDir "\theme\" program ".png" : fallback
    }
    try host := ParseUrl(row.name).host
    catch
        return fallback
    ; Bundled artwork only matches the real domain, never a substring in a URL.
    for domain, name in Map("youtube.com","youtube","spotify.com","spotify","discord.com","discord","snapchat.com","snapchat","steampowered.com","steam") {
        if host=domain || host="www." domain
            return A_ScriptDir "\theme\" name ".png"
    }
    path := A_ScriptDir "\site-icons\" StrReplace(host,":","_") ".png"
    if FileExist(path)
        return path
    if testMode || requested.Has(host)
        return fallback
    requested[host] := true
    failed := StrReplace(path,".png",".failed")
    if FileExist(failed) && DateDiff(A_Now,FileGetTime(failed),"Seconds")<3600
        return fallback
    IconDownloads.Enqueue(host)
    return fallback
}
class IconDownloads {
    static queue := [], pid := 0, poll := ObjBindMethod(IconDownloads,"Tick")
    static Enqueue(host) {
        this.queue.Push(host)
        SetTimer(this.poll,300)
    }
    static Tick() {
        if this.pid {
            if ProcessExist(this.pid)
                return
            this.pid := 0
            if IsObject(appLv)
                appLv.Render()
        }
        if this.queue.Length=0 {
            SetTimer(this.poll,0)
            return
        }
        host := this.queue.RemoveAt(1)
        try Run('powershell.exe -NoProfile -NonInteractive -WindowStyle Hidden -ExecutionPolicy Bypass -File "' A_ScriptDir '\Fetch-SiteIcon.ps1" -HostName "' host '"',A_ScriptDir,"Hide",&pid)
        catch
            return
        this.pid := pid
    }
}
