#Requires AutoHotkey v2.0

; if !A_IsAdmin {
;     Run "*RunAs " A_ScriptFullPath
;     ExitApp()
; }

; ───────── CONFIG ─────────
global Color := 0xffffb4           ; target pixel color (RGB hex) 0xffffb4 0xe600e6
global WinName := "Roblox"         ; ahk_exe or window title Roblox
global Fov := 350                  ; square search area (pixels)
global Tol := 25                   ; color tolerance (0‑255)

; Movement style
global JitterAmount := 2           ; pixel jitter
global CurveAmplitude := 15        ; how much curve to add
global CurveFrequency := 0.15      ; lower = slower curve oscillation
global StepDivisor := 5            ; higher = slower mouse approach

; Prediction settings
global MaxHistory := 5             ; history points for prediction
global PredictionFactor := 3       ; how far ahead to predict movement
global ToX := 1000
global ToY := 1000
global pressed := [false, false]

; History buffer for prediction
global History := []
global HistIndex := 0

Loop MaxHistory {
    History.Push({ x: 0, y: 0, t: 0 })  ; preallocate
}

; Define Pi value
global Pi := 3.14159265358979
global Step := 0 ; Used to vary curve shape frame-by-frame

CoordMode("Pixel", "Screen")
CoordMode("Mouse", "Screen")
SetTimer(Main, 1)
SetTimer(side, 2)

F2:: {
    global Color
    MouseGetPos &x, &y
    Color := PixelGetColor(x, y)
    ToolTip Color, 0, 0
}

F1:: ExitApp()


Main() {
    global WinName, Color, Fov, Tol, JitterAmount, CurveAmplitude, CurveFrequency, StepDivisor, Pi
    global MaxHistory, PredictionFactor, History, HistIndex, Step, shoot, ToX, ToY

    hwnd := WinExist(WinName)
    if !hwnd || !(GetKeyState("LButton", "P") || GetKeyState("RButton", "P")) {
        ToX := 1000
        ToY := 1000
        return
    }

    ; Center of client area
    WinGetClientPos(&cx, &cy, &cw, &ch, hwnd)
    centerX := cx + cw // 2
    centerY := cy + ch // 2

    half := Fov // 2
    x1 := centerX - half, y1 := centerY - half
    x2 := centerX + half, y2 := centerY + half

    ; Search for target pixel
    if !PixelSearch(&px, &py, x1, y1, x2, y2, Color, Tol) {
        ToX := 1000
        ToY := 1000
        return
    }

    ; Add current target position to history
    HistIndex := Mod(HistIndex + 1, MaxHistory)
    History[HistIndex + 1] := { x: px, y: py, t: A_TickCount }

    ; Not enough data for prediction?
    if HistIndex < 2 {
        ToX := 1000
        ToY := 1000
        return
    }

    ; Calculate velocity using previous points
    count := 0, totalDx := 0, totalDy := 0, totalDt := 0
    loopCount := Min(HistIndex, MaxHistory - 1)

    Loop loopCount {
        i := Mod(HistIndex - A_Index + MaxHistory, MaxHistory)
        j := Mod(i + 1, MaxHistory)

        pt1 := History[i + 1]
        pt2 := History[j + 1]
        dt := pt2.t - pt1.t
        if (dt > 0) {
            dx := pt2.x - pt1.x
            dy := pt2.y - pt1.y
            totalDx += dx
            totalDy += dy
            totalDt += dt
            count += 1
        }
    }

    if (count = 0 || totalDt = 0) {
        ToX := 1000
        ToY := 1000
        return
    }

    vx := totalDx / totalDt
    vy := totalDy / totalDt
    dtAhead := 16 * PredictionFactor ; ~16ms per frame * factor

    predX := Round(px + vx * dtAhead)
    predY := Round(py + vy * dtAhead)

    ; Get current mouse position
    MouseGetPos(&mx, &my)

    dx := predX - mx
    dy := predY - my

    ToX := dx
    ToY := dy
    ToolTip "X: " ToX " Y: " ToY, 0, 0

    ; Apply curved offset using sine wave
    Step += 1
    curve := Sin(Step * CurveFrequency) * CurveAmplitude

    ; Choose direction to apply curve (perpendicular to motion)
    angle := ATan2(dy, dx)
    offsetX := curve * Cos(angle + Pi / 2)
    offsetY := curve * Sin(angle + Pi / 2)

    ; Apply jitter to simulate human randomness
    jitterX := Random(-JitterAmount, JitterAmount)
    jitterY := Random(-JitterAmount, JitterAmount)

    ; Final movement calculation
    moveX := Ceil((dx + offsetX + jitterX) / StepDivisor)
    moveY := Ceil((dy + offsetY + jitterY) / StepDivisor)


    DllCall("mouse_event", "uint", 0x0001, "int", moveX, "int", moveY, "uint", 0, "ptr", 0)
}

side() {
    global ToX, ToY, pressed

    if Abs(Tox) <= 25 && Abs(ToY) <= 25 {
        pressed[1] := true
        Click "Down"
    } else if pressed[1] == true {
        pressed[1] := false
        Click "Up"
    }
}

; Cross-platform ATan2
ATan2(y, x) {
    return DllCall("msvcrt.dll\atan2", "double", y, "double", x, "cdecl double")
}