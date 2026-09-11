; Native controls with a custom gold/charcoal renderer. No browser dependency.
BuildGoldGui() {
    global mainGui, appLv, statusText, inputApp, shortcutInput, shortcutBadge, defaultShortcut
    global uiScale, paintedButtons, themeBitmaps, settingsGui, drawCallback
    paintedButtons := Map(), themeBitmaps := Map(), settingsGui := ""
    MonitorGetWorkArea(MonitorGetPrimary(), &left, &top, &right, &bottom)
    uiScale := Min(1, (bottom - top - 46) / (870 * A_ScreenDPI / 96), (right - left - 46) / (1040 * A_ScreenDPI / 96))
    mainGui := Gui("-Caption +Border", windowTitle)
    SetSqueakWindowIcon(mainGui.Hwnd)
    mainGui.BackColor := "090909"
    mainGui.MarginX := 0, mainGui.MarginY := 0
    mainGui.AddPicture(Pos(0,0,1040,870), A_ScriptDir "\theme\background.png")
    mainGui.AddPicture(Pos(30,35,100,100), A_ScriptDir "\theme\logo.png").OnEvent("Click", (*) => DragSqueak())
    Label(145,40,440,54,"Squeak",34,"F5F5F3",700).OnEvent("Click", (*) => DragSqueak())
    Label(147,98,560,32,"Fermez rapidement vos applications et sites.",15,"B8B5AE").OnEvent("Click", (*) => DragSqueak())
    PaintedButton(919,10,34,30,"Réglages","flat",(*) => ShowSettings(),"⚙",16)
    PaintedButton(955,10,34,30,"Minimiser","flat",(*) => mainGui.Minimize(),"—",15)
    PaintedButton(991,10,34,30,"Masquer Squeak","flat",(*) => mainGui.Hide(),"×",21)
    shortcutBadge := Label(738,79,244,28,"Raccourci : P + Suppr",12,"EEECE7",600)
    shortcutBadge.OnEvent("Click", (*) => ShowSettings())
    Label(114,180,810,38,"Applications et URL à fermer",23,"F3F3F0",700)
    Label(115,219,830,25,"Cochez les éléments à fermer avec votre raccourci.",13,"B8B5AE")
    Label(65,258,440,28,"Élément",12,"E7E6E1",600)
    Label(552,258,180,28,"Type",12,"E7E6E1",600)
    Label(761,258,200,28,"Statut",12,"E7E6E1",600)
    appLv := GoldList()
    appLv.OnEvent("ItemCheck", ItemChecked)
    RefreshList()
    Label(109,609,810,24,"Ajouter un programme ou une URL",14,"F2F2EE",700)
    Label(123,649,36,26,"↗",17,"AAA69E")
    mainGui.SetFont("s" (13 * uiScale) " cECEBE5", "Segoe UI")
    inputApp := mainGui.AddEdit(Pos(158,649,622,25) " -E0x200 -Border Background101010", "")
    SendMessage(0x1501, true, StrPtr("Ex. Discord.exe ou youtube.com"), , "ahk_id " inputApp.Hwnd)
    PaintedButton(816,637,180,48,"＋  Ajouter","gold",(*) => AddFromInput())
    PaintedButton(46,737,245,53,"Retirer","dark",(*) => RemoveItem(),"⌫   Retirer")
    PaintedButton(322,737,400,53,"Fermer maintenant","gold",(*) => CloseSelected(),"▶   Fermer maintenant",15)
    PaintedButton(752,737,244,53,"Réduire","dark",(*) => mainGui.Hide(),"—   Réduire")
    Label(45,827,24,23,"●",13,"65E888")
    statusText := Label(76,828,914,23,"Version 2.2 active   ·   Fermeture normale   ·   URL : onglet actif uniquement",10,"9EDCAA")
    mainGui.OnEvent("Close", (*) => mainGui.Hide())
    mainGui.OnEvent("Escape", (*) => mainGui.Hide())
    drawCallback := CallbackCreate(GoldWindowProc,"",6)
    if !DllCall("comctl32\SetWindowSubclass","Ptr",mainGui.Hwnd,"Ptr",drawCallback,"UPtr",1,"UPtr",0)
        throw Error("Impossible d'initialiser les boutons.")
    OnMessage(0x0201, GoldDrag)
    corner := Buffer(4,0), NumPut("UInt",2,corner)
    try DllCall("dwmapi\DwmSetWindowAttribute", "Ptr",mainGui.Hwnd,"UInt",33,"Ptr",corner,"UInt",4)
    ; Keep the existing shortcut control API without occupying the main layout.
    settingsGui := Gui("+Owner" mainGui.Hwnd, "Réglages Squeak")
    SetSqueakWindowIcon(settingsGui.Hwnd)
    settingsGui.BackColor := "141414"
    settingsGui.SetFont("s11 cEAE7DE", "Segoe UI")
    settingsGui.AddText("w420", "Raccourci clavier")
    defaultShortcut := settingsGui.AddCheckbox("w420 Checked", "Utiliser P + Suppr (par défaut)")
    defaultShortcut.OnEvent("Click", (*) => shortcutInput.Enabled := !defaultShortcut.Value)
    settingsGui.AddText("w420", "Clique dans le champ puis tape la combinaison souhaitée.")
    settingsGui.SetFont("c000000")
    shortcutInput := settingsGui.AddHotkey("w420 h32 Disabled", "^!F12")
    settingsGui.AddButton("w180 h34", "Enregistrer").OnEvent("Click", (*) => SaveGoldShortcut())
    settingsGui.SetFont("cBDB8AD")
    settingsGui.AddText("w420", "Le forçage se règle dans le menu … de chaque programme.`nLes sites sont reconnus avec ou sans www. Les autres sous-domaines restent séparés.")
    settingsGui.OnEvent("Close", (*) => settingsGui.Hide())
    settingsGui.OnEvent("Escape", (*) => settingsGui.Hide())
}
SetSqueakWindowIcon(hwnd) {
    ; TraySetIcon only changes the notification icon. Windows needs both window sizes.
    ; Keep the handles alive while the windows use them (released with the process).
    static icons := Map()
    if icons.Count = 0 {
        for kind, metric in Map(0,49,1,11) {
            size := DllCall("GetSystemMetrics","Int",metric,"Int")
            handle := DllCall("LoadImageW","Ptr",0,"Str",A_ScriptDir "\Squeak.ico","UInt",1,"Int",size,"Int",size,"UInt",0x10,"Ptr")
            if !handle
                throw Error("Impossible de charger le logo de Squeak.")
            icons[kind] := handle
        }
    }
    for kind, handle in icons
        DllCall("SendMessageW","Ptr",hwnd,"UInt",0x80,"UPtr",kind,"Ptr",handle,"Ptr")
}
Pos(x,y,w,h) {
    return "x" Round(x*uiScale) " y" Round(y*uiScale) " w" Round(w*uiScale) " h" Round(h*uiScale)
}
Label(x,y,w,h,text,size:=13,color:="F2F2EE",weight:=400) {
    mainGui.SetFont("s" (size*uiScale) " c" color " w" weight, "Segoe UI")
    return mainGui.AddText(Pos(x,y,w,h) " BackgroundTrans +0x4100",text)
}
ShowGold() {
    mainGui.Show("w" Round(1040*uiScale) " h" Round(870*uiScale))
}
DragSqueak() {
    PostMessage(0x00A1,2,0,,"ahk_id " mainGui.Hwnd)
}
GoldDrag(wParam,lParam,msg,hwnd) {
    if hwnd = mainGui.Hwnd && ((lParam >> 16) & 0xFFFF) < Round(146*uiScale*A_ScreenDPI/96)
        DragSqueak()
}
ShowSettings() {
    settingsGui.Show()
}
SaveGoldShortcut() {
    try {
        SetShortcut(defaultShortcut.Value ? "~p & Delete" : shortcutInput.Value)
        UpdateGoldShortcut()
        SetStatus("Raccourci enregistré.")
        settingsGui.Hide()
    } catch as err
        MsgBox(err.Message,"Squeak","Icon!")
}
UpdateGoldShortcut() {
    if activeHotkey="~p & Delete" {
        shortcutBadge.Value := "Raccourci : P + Suppr"
        return
    }
    ; Modifier symbols are expanded independently of the literal plus separators.
    display := ""
    if InStr(activeHotkey,"^")
        display .= "Ctrl + "
    if InStr(activeHotkey,"!")
        display .= "Alt + "
    if InStr(activeHotkey,"+")
        display .= "Maj + "
    display .= RegExReplace(activeHotkey,"[!^+#]")
    shortcutBadge.Value := "Raccourci : " display
}
PaintedButton(x,y,w,h,label,tone,handler,display:="",size:=13) {
    mainGui.SetFont("s" (size*uiScale) " w600", "Segoe UI")
    button := mainGui.AddButton(Pos(x,y,w,h),label)
    ; AutoHotkey normalizes button style at creation. Apply owner-draw afterwards.
    SendMessage(0xF4,0xB,true,,"ahk_id " button.Hwnd)
    paintedButtons[button.Hwnd] := {tone:tone, display:display="" ? label : display}
    button.OnEvent("Click",handler)
    return button
}
DrawPaintedButton(wParam,lParam,*) {
    offset := A_PtrSize=8 ? 24 : 20
    hwnd := NumGet(lParam,offset,"Ptr")
    if !paintedButtons.Has(hwnd)
        return
    info := paintedButtons[hwnd]
    hdc := NumGet(lParam,offset+A_PtrSize,"Ptr")
    rc := lParam+offset+2*A_PtrSize
    w := NumGet(rc,8,"Int"), h := NumGet(rc,12,"Int")
    state := NumGet(lParam,16,"UInt")
    tone := info.tone
    if tone = "flat" {
        brush := DllCall("CreateSolidBrush","UInt",0x101010,"Ptr")
        DllCall("FillRect","Ptr",hdc,"Ptr",rc,"Ptr",brush)
        DllCall("DeleteObject","Ptr",brush)
    } else {
        if !themeBitmaps.Has(tone) {
            hbm := DllCall("LoadImageW","Ptr",0,"Str",A_ScriptDir "\theme\" tone ".bmp","UInt",0,"Int",0,"Int",0,"UInt",0x2010,"Ptr")
            dimensions := Buffer(A_PtrSize=8?32:24,0)
            DllCall("GetObjectW","Ptr",hbm,"Int",dimensions.Size,"Ptr",dimensions)
            themeBitmaps[tone] := {handle:hbm,w:NumGet(dimensions,4,"Int"),h:NumGet(dimensions,8,"Int")}
        }
        bitmap := themeBitmaps[tone]
        mem := DllCall("CreateCompatibleDC","Ptr",hdc,"Ptr")
        old := DllCall("SelectObject","Ptr",mem,"Ptr",bitmap.handle,"Ptr")
        DllCall("SetStretchBltMode","Ptr",hdc,"Int",4)
        DllCall("StretchBlt","Ptr",hdc,"Int",0,"Int",0,"Int",w,"Int",h,"Ptr",mem,"Int",0,"Int",0,"Int",bitmap.w,"Int",bitmap.h,"UInt",0xCC0020)
        DllCall("SelectObject","Ptr",mem,"Ptr",old)
        DllCall("DeleteDC","Ptr",mem)
    }
    DllCall("SetBkMode","Ptr",hdc,"Int",1)
    DllCall("SetTextColor","Ptr",hdc,"UInt",state&4 ? 0x777777 : tone="gold" ? 0x0A0B0D : 0xF0F2F3)
    font := SendMessage(0x31,0,0,,"ahk_id " hwnd)
    oldFont := DllCall("SelectObject","Ptr",hdc,"Ptr",font,"Ptr")
    DllCall("DrawTextW","Ptr",hdc,"Str",info.display,"Int",-1,"Ptr",rc,"UInt",0x825)
    DllCall("SelectObject","Ptr",hdc,"Ptr",oldFont)
    if state&0x10 {
        focusRect := Buffer(16,0)
        NumPut("Int",4,"Int",4,"Int",w-4,"Int",h-4,focusRect)
        DllCall("DrawFocusRect","Ptr",hdc,"Ptr",focusRect)
    }
    return true
}
GoldWindowProc(hwnd,msg,wParam,lParam,id,data) {
    if msg=0x2B {
        result := DrawPaintedButton(wParam,lParam)
        if result != ""
            return result
    }
    return DllCall("comctl32\DefSubclassProc","Ptr",hwnd,"UInt",msg,"Ptr",wParam,"Ptr",lParam,"Ptr")
}
class GoldList {
    __New() {
        this.rows := [], this.slots := [], this.selected := 0, this.page := 1, this._enabled := true
        this.checkHandler := ""
        Loop 5 {
            slot := A_Index, y := 296+(slot-1)*52
            check := PaintedButton(62,y+9,28,28,"Activer cet élément","unchecked",ObjBindMethod(this,"Toggle",slot)," ",17)
            icon := mainGui.AddPicture(Pos(111,y+7,34,34) " Hidden", A_ScriptDir "\theme\logo.png")
            name := Label(161,y+10,356,34,"",14)
            name.OnEvent("Click",ObjBindMethod(this,"Select",slot))
            badge := mainGui.AddPicture(Pos(544,y+5,151,36),A_ScriptDir "\theme\badge.png")
            kind := Label(552,y+12,178,28,"",12,"D5D2CA")
            dot := Label(761,y+12,20,28,"●",12,"66E888")
            status := Label(786,y+12,148,28,"",11,"D8D8CF")
            menu := PaintedButton(950,y+5,32,38,"Options de l’élément","flat",ObjBindMethod(this,"Menu",slot),"…",19)
            this.slots.Push({check:check,icon:icon,name:name,badge:badge,kind:kind,dot:dot,status:status,menu:menu})
        }
        this.counter := Label(48,556,810,20,"",9,"A39D90")
        this.prev := PaintedButton(918,552,32,22,"Page précédente","flat",(*)=>this.PageBy(-1),"‹",14)
        this.next := PaintedButton(957,552,32,22,"Page suivante","flat",(*)=>this.PageBy(1),"›",14)
    }
    OnEvent(event,callback) {
        this.checkHandler := callback
    }
    Delete() {
        this.rows := [], this.selected := 0
        this.Render()
    }
    Add(options,name,kind,force,result) {
        this.rows.Push({name:name,kind:kind,force:force,result:result,checked:InStr(options,"Check")>0})
        this.Render()
        return this.rows.Length
    }
    ModifyCol(*) {
    }
    GetCount() {
        return this.rows.Length
    }
    GetNext(start:=0,mode:="") {
        if mode="Checked" {
            for index,row in this.rows {
                if index>start && row.checked
                    return index
            }
            return 0
        }
        return this.selected>start ? this.selected : 0
    }
    Modify(index,options:="",values*) {
        if values.Length>=4 && values.Has(4)
            this.rows[index].result := values[4]
        this.Render()
    }
    Enabled {
        get => this._enabled
        set {
            this._enabled := value
            this.Render()
        }
    }
    RowFor(slot) {
        return (this.page-1)*5+slot
    }
    Toggle(slot,*) {
        index := this.RowFor(slot)
        if busy || index>this.rows.Length
            return
        this.rows[index].checked := !this.rows[index].checked
        this.selected := index
        this.checkHandler.Call(this,index,this.rows[index].checked)
        this.Render()
    }
    Select(slot,*) {
        this.selected := this.RowFor(slot)
        this.Render()
    }
    Menu(slot,*) {
        if busy
            return
        this.Select(slot)
        contextMenu := Menu()
        if this.rows[this.selected].kind="program"
            contextMenu.Add(appList[this.selected].force ? "Désactiver la fermeture forcée" : "Autoriser la fermeture forcée…",(*)=>ToggleForce())
        contextMenu.Add("Retirer de la liste",(*)=>RemoveItem())
        contextMenu.Show()
    }
    PageBy(delta) {
        this.page := Max(1,Min(Ceil(this.rows.Length/5),this.page+delta))
        this.Render()
    }
    Render() {
        this.page := Max(1,Min(Max(1,Ceil(this.rows.Length/5)),this.page))
        for slot,controls in this.slots {
            index := this.RowFor(slot), visible := index<=this.rows.Length
            for property in ["check","icon","name","badge","kind","dot","status","menu"]
                controls.%property%.Visible := visible
            if !visible
                continue
            row := this.rows[index]
            controls.name.Value := row.name
            controls.name.SetFont("c" (index=this.selected?"E4BB6C":"F2F2EE"))
            controls.kind.Value := (row.kind="program"?">_   Programme":row.kind="page"?"↗   Page exacte":"↗   URL") (row.force="Oui"?"  !":"")
            controls.badge.Move(,,Round((row.kind="url"?94:176)*uiScale))
            controls.status.Value := row.result="—" ? "Prêt" : row.result
            controls.dot.SetFont("c" (row.result="—" || row.result="Fermé" ? "65E888" : "D5AD60"))
            paintedButtons[controls.check.Hwnd].tone := row.checked ? "check" : "unchecked"
            paintedButtons[controls.check.Hwnd].display := row.checked ? "✓" : " "
            controls.check.Text := (row.checked?"Désactiver ":"Activer ") row.name
            controls.check.Enabled := this._enabled
            controls.menu.Enabled := this._enabled
            iconPath := SiteIconPath(row)
            if !controls.HasOwnProp("iconPath") || controls.iconPath != iconPath {
                controls.icon.Value := iconPath
                controls.iconPath := iconPath
            }
            DllCall("InvalidateRect","Ptr",controls.check.Hwnd,"Ptr",0,"Int",false)
        }
        this.counter.Value := this.rows.Length=0 ? "Votre liste est vide. Ajoutez un programme ou une URL." : this.rows.Length " éléments  ·  Page " this.page " / " Max(1,Ceil(this.rows.Length/5))
        this.prev.Visible := this.rows.Length>5, this.next.Visible := this.rows.Length>5
    }
}
