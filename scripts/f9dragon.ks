set F9DImg to "f9_img/".
set F9DMono to "Consolas".
set F9DAcc to rgb(0.31, 0.64, 1).
set F9DGray to rgb(0.54, 0.59, 0.64).
set F9DDim to rgb(0.43, 0.47, 0.53).
set F9DTxt to rgb(0.78, 0.82, 0.87).
set F9DYel to rgb(0.96, 0.71, 0).
set F9DRed to rgb(0.9, 0.28, 0.3).
set F9DCmd to "".
set F9DAuto to true.
set F9DBurning to false.
set F9DHold to false.
set F9DOk to false.
set F9DShroud to "".
set F9DEnState to lexicon().
set F9DBgState to lexicon().
set F9DPhase to "".
set F9DAbort to false.
set F9DWantOcean to true.
set F9DWantDay to true.
set F9DSgn to 1.
set F9DAccEst to 0.3.
set F9DBurnT to 0.
set F9DPlanTxt to "".
set F9DLogNext to 0.
set F9DDownLogged to false.
set F9DLogPath to "0:/f9dragon.log".
set F9DRcsIsp to 240.
set F9DLead to 600.
set F9DEccOk to 0.01.
set F9DPrep to 120.
set F9DSteps to 24.
set F9DSearchH to 12.
set F9DRangeK to 0.5.
set F9DTrTries to 20.
set F9DSunMin to 10.
set F9DTrunkK to 1.1.
set F9DDrogueH to 6000.
set F9DDrogueV to 300.
set F9DMainH to 2000.
set F9DMainV to 120.
set F9DRnEccOk to 0.01.
set F9DRnIncOk to 0.05.
set F9DRnIncWarn to 1.
set F9DAppFar to 50000.
set F9DAppStop to 50.
set F9DAppK to 0.05.
set F9DAppVmax to 20.
set F9DAppGain to 0.6.
set F9DAppTmax to 3600.
set F9DDockNear to 300.
set F9DDockHold to 15.
set F9DDockVmax to 1.
set F9DDockVmin to 0.15.
set F9DDockLat to 0.3.
set F9DDockGain to 2.
set F9DDockTmax to 3600.
set F9DPushDir to V(0, 0, 1).
set F9DDockDir to V(0, 0, 1).

set F9DKinds to lexicon(
    "btn", list("btn", "btn_hover", "btn_on", "btn_on", 10),
    "blue", list("btn_on", "btn_hover", "btn_on", "btn_on", 10),
    "red", list("btn_red", "btn_red_hover", "btn_red_active", "btn_red_active", 12),
    "off", list("btn_off", "btn_off", "btn_off", "btn_off", 10)).

function F9DPad2 {
    parameter n.
    return choose "0" + n if n < 10 else "" + n.
}

function F9DHms {
    parameter s.
    local sec is max(0, floor(s)).
    return F9DPad2(floor(sec / 3600)) + ":" + F9DPad2(floor(mod(sec, 3600) / 60)) + ":" + F9DPad2(mod(sec, 60)).
}

function F9DLog {
    parameter msg.
    print msg.
    if homeconnection:isconnected log ("T+" + F9DHms(missiontime) + " " + msg) to F9DLogPath.
}

function F9DSkin {
    parameter b, kind.
    local k is F9DKinds[kind].
    set b:style:normal:bg to F9DImg + k[0].
    set b:style:focused:bg to F9DImg + k[0].
    set b:style:hover:bg to F9DImg + k[1].
    set b:style:active:bg to F9DImg + k[2].
    set b:style:on:bg to F9DImg + k[3].
    set b:style:hover_on:bg to F9DImg + k[3].
    set b:style:active_on:bg to F9DImg + k[3].
    set b:style:focused_on:bg to F9DImg + k[3].
    set b:style:border:h to k[4].
    set b:style:border:v to k[4].
    local tc is choose F9DDim if kind = "off" else white.
    set b:style:normal:textcolor to tc.
    set b:style:focused:textcolor to tc.
    set b:style:hover:textcolor to tc.
    set b:style:active:textcolor to white.
    set b:style:on:textcolor to white.
    set b:style:hover_on:textcolor to white.
    set b:style:active_on:textcolor to white.
    set b:style:focused_on:textcolor to white.
}

function F9DButton {
    parameter parent, txt, kind, h, fs.
    local b is parent:addbutton(txt).
    F9DSkin(b, kind).
    set b:style:height to h.
    set b:style:font to F9DMono.
    set b:style:fontsize to fs.
    set b:style:hstretch to true.
    set b:style:align to "center".
    return b.
}

function F9DEnable {
    parameter id, b, kind, en.
    if F9DEnState:haskey(id) and F9DEnState[id] = en return.
    set F9DEnState[id] to en.
    set b:enabled to en.
    F9DSkin(b, choose kind if en else "off").
}

function F9DLabel {
    parameter parent, txt, fs, col, mono is true, al is "left".
    local l is parent:addlabel(txt).
    set l:style:fontsize to fs.
    set l:style:textcolor to col.
    if mono set l:style:font to F9DMono.
    set l:style:align to al.
    return l.
}

function F9DText {
    parameter l, txt.
    if l:text <> txt set l:text to txt.
}

function F9DBg {
    parameter id, w, img.
    if F9DBgState:haskey(id) and F9DBgState[id] = img return.
    set F9DBgState[id] to img.
    set w:style:bg to F9DImg + img.
}

function F9DNoBorder {
    parameter w.
    set w:style:border:h to 0.
    set w:style:border:v to 0.
    set w:style:padding:h to 0.
    set w:style:padding:v to 0.
}

function F9DLamp {
    parameter parent.
    local l is parent:addlabel("").
    set l:style:bg to F9DImg + "lamp_off".
    F9DNoBorder(l).
    set l:style:width to 12.
    set l:style:height to 12.
    set l:style:margin:top to 3.
    return l.
}

function F9DLamps {
    parameter parent, names.
    local rw is parent:addhlayout().
    local out is list().
    for nm in names {
        if out:length > 0 rw:addspacing(-1).
        out:add(F9DLamp(rw)).
        F9DLabel(rw, nm, 10, F9DGray).
    }
    return out.
}

function F9DDivider {
    parameter parent.
    local d is parent:addlabel("").
    set d:style:bg to F9DImg + "divider".
    F9DNoBorder(d).
    set d:style:height to 1.
    set d:style:hstretch to true.
    set d:style:margin:top to 6.
    set d:style:margin:bottom to 6.
}

function F9DBar {
    parameter parent, w.
    local bb is parent:addhbox().
    set bb:style:bg to F9DImg + "bar_bg".
    F9DNoBorder(bb).
    set bb:style:border:h to 3.
    set bb:style:width to w.
    set bb:style:height to 6.
    set bb:style:margin:top to 6.
    local fl is bb:addlabel("").
    set fl:style:bg to F9DImg + "bar_blue".
    F9DNoBorder(fl).
    set fl:style:border:h to 3.
    set fl:style:height to 6.
    set fl:style:width to 6.
    set fl:style:margin:h to 0.
    set fl:style:margin:v to 0.
    return lexicon("fill", fl, "w", w, "col", "blue", "px", -1).
}

function F9DBarSet {
    parameter b, frac, col.
    local px is round(max(0, min(1, frac)) * b["w"]).
    local img is choose "bg" if px < 6 else col.
    set px to max(6, px).
    if px <> b["px"] {
        set b["px"] to px.
        set b["fill"]:style:width to px.
    }
    if img <> b["col"] {
        set b["col"] to img.
        set b["fill"]:style:bg to F9DImg + "bar_" + img.
    }
}

function F9DBarRow {
    parameter parent, nm.
    local rw is parent:addhlayout().
    local l is F9DLabel(rw, nm, 10, F9DGray).
    set l:style:width to 56.
    local b is F9DBar(rw, 290).
    local pc is F9DLabel(rw, "", 10, F9DTxt, true, "right").
    set pc:style:width to 40.
    set b["pct"] to pc.
    return b.
}

function F9DBarPct {
    parameter b, frac, col.
    F9DBarSet(b, frac, col).
    F9DText(b["pct"], round(100 * max(0, min(1, frac))) + "%").
}

function F9DField {
    parameter parent, nm, val, unit.
    local rw is parent:addhlayout().
    local l is F9DLabel(rw, nm, 13, F9DTxt, false).
    set l:style:hstretch to true.
    local f is rw:addtextfield("" + val).
    set f:style:width to 118.
    set f:style:height to 30.
    set f:style:font to F9DMono.
    set f:style:fontsize to 13.
    set f:style:align to "right".
    set f:style:padding:h to 10.
    set f:style:border:h to 6.
    set f:style:border:v to 6.
    set f:style:normal:bg to F9DImg + "field".
    set f:style:hover:bg to F9DImg + "field".
    set f:style:focused:bg to F9DImg + "field_focus".
    set f:style:normal:textcolor to white.
    set f:style:focused:textcolor to white.
    local u is F9DLabel(rw, unit, 11, F9DGray).
    set u:style:width to 22.
    set u:style:margin:top to 9.
    return f.
}

function F9DFieldErr {
    parameter f, err.
    local img is choose "field_error" if err else "field".
    if F9DBgState:haskey("fe") and F9DBgState["fe"] = img return.
    set F9DBgState["fe"] to img.
    set f:style:normal:bg to F9DImg + img.
    set f:style:hover:bg to F9DImg + img.
    set f:style:normal:textcolor to choose F9DYel if err else white.
}

function F9DNum {
    parameter f, dflt.
    return f:text:replace(",", "."):trim:tonumber(dflt).
}

function F9DBig {
    parameter parent, cap.
    local b is parent:addvbox().
    set b:style:bg to F9DImg + "box".
    set b:style:border:h to 12.
    set b:style:border:v to 12.
    set b:style:padding:h to 12.
    set b:style:padding:v to 10.
    set b:style:hstretch to true.
    F9DLabel(b, cap, 9, F9DGray).
    local vl is F9DLabel(b, "—", 19, white).
    set vl:style:richtext to true.
    return vl.
}

function F9DKm {
    parameter x.
    if x <= 0 return "—".
    return round(x / 1000, 1) + " <size=11><color=#8A96A3>km</color></size>".
}

function F9DEvName {
    parameter ev.
    local nm is ev.
    if nm:contains(")") set nm to nm:substring(nm:find(")") + 1, nm:length - nm:find(")") - 1).
    if nm:contains(",") set nm to nm:substring(0, nm:find(",")).
    return nm:trim.
}

function F9DModHas {
    parameter pm, frag.
    for ev in pm:allevents {
        if F9DEvName(ev):tolower:contains(frag) return true.
    }
    return false.
}

function F9DModDo {
    parameter pm, frag.
    for ev in pm:allevents {
        local nm is F9DEvName(ev).
        if nm:tolower:contains(frag) and pm:hasevent(nm) {
            pm:doevent(nm).
            return true.
        }
    }
    return false.
}

function F9DPartDo {
    parameter prt, frag.
    from { local i is 0. } until i >= prt:modules:length step { set i to i + 1. } do {
        if F9DModDo(prt:getmodulebyindex(i), frag) return true.
    }
    return false.
}

function F9DEvents {
    parameter prt.
    local out is list().
    from { local i is 0. } until i >= prt:modules:length step { set i to i + 1. } do {
        for ev in prt:getmodulebyindex(i):allevents { out:add(F9DEvName(ev)). }
    }
    return out:join("; ").
}

function F9DAttached {
    return ship:partsnamedpattern("Dragon[._]Decoupler"):length > 0.
}

function F9DDown {
    return ship:status = "LANDED" or ship:status = "SPLASHED" or ship:status = "PRELAUNCH".
}

function F9DShroudMod {
    local pp is core:part.
    from { local i is 0. } until i >= pp:modules:length step { set i to i + 1. } do {
        local pm is pp:getmodulebyindex(i).
        if F9DModHas(pm, "shroud") return pm.
    }
    return "".
}

function F9DNoseOpen {
    if F9DShroud:istype("String") return false.
    return F9DModHas(F9DShroud, "close").
}

function F9DNose {
    parameter wantOpen.
    if F9DShroud:istype("String") or wantOpen = F9DNoseOpen() return.
    F9DModDo(F9DShroud, choose "open" if wantOpen else "close").
    F9DLog("nose cone: " + (choose "open" if wantOpen else "closed")).
}

function F9DTrunk {
    local l is ship:partsnamedpattern("DRAGONV2[._]TRUNK").
    if l:length = 0 return "".
    return l[0].
}

function F9DJettison {
    local tr is F9DTrunk().
    if tr:istype("String") return.
    if F9DPartDo(tr, "decouple") or F9DPartDo(tr, "jettison") {
        F9DLog("trunk jettisoned · h " + round(ship:altitude / 1000, 1) + " km").
        wait 2.
    } else F9DLog("trunk has no jettison event: " + F9DEvents(tr)).
}

function F9DChuteMods {
    parameter grp.
    local out is list().
    for p in ship:partsnamedpattern("CD2[._]POD[._]" + grp) {
        if p:hasmodule("ModuleParachute") out:add(p:getmodule("ModuleParachute")).
    }
    return out.
}

function F9DChuteSt {
    parameter grp.
    local ms is F9DChuteMods(grp).
    if ms:length = 0 return "none".
    for pm in ms { if F9DModHas(pm, "deploy") return "stowed". }
    for pm in ms { if F9DModHas(pm, "cut") return "open". }
    for pm in ms { if F9DModHas(pm, "disarm") return "armed". }
    return "spent".
}

function F9DArm {
    parameter grp.
    local n is 0.
    for pm in F9DChuteMods(grp) {
        if F9DModDo(pm, "deploy") set n to n + 1.
    }
    F9DLog(grp + " armed: " + n + " · h " + round(alt:radar) + " m · v " + round(ship:airspeed) + " m/s").
}

function F9DRes {
    parameter nm.
    for rs in ship:resources {
        if rs:name = nm return rs.
    }
    return "".
}

function F9DResFrac {
    parameter nm.
    local rs is F9DRes(nm).
    if rs:istype("String") or rs:capacity <= 0 return 0.
    return rs:amount / rs:capacity.
}

function F9DDvAvail {
    local rs is F9DRes("MonoPropellant").
    if rs:istype("String") return 0.
    local fm is rs:amount * rs:density.
    if ship:mass <= fm return 0.
    return F9DRcsIsp * constant:g0 * ln(ship:mass / (ship:mass - fm)).
}

function F9DDeorbitDv {
    parameter peT.
    local rr is body:radius + ship:altitude.
    local vNew is sqrt(body:mu * max(0, 2 / rr - 2 / (rr + body:radius + peT))).
    return max(0, ship:velocity:orbit:mag - vNew).
}

function F9DValidate {
    local pe is F9DNum(F9DFPe, -1).
    local err is "".
    local dv is 0.
    local av is F9DDvAvail().
    if pe < 0 set err to "enter a number".
    else if pe * 1000 >= body:atm:height set err to "entry periapsis must be inside atmosphere".
    else if ship:periapsis <= pe * 1000 set err to "already on entry trajectory".
    else {
        set dv to F9DDeorbitDv(pe * 1000).
        if dv > av set err to "not enough monopropellant".
    }
    set F9DOk to err = "".
    F9DFieldErr(F9DFPe, pe < 0 or err:contains("inside")).
    if F9DOk {
        F9DText(F9DWarn, "DEORBIT ΔV ~" + round(dv) + " m/s · AVAILABLE ~" + round(av) + " m/s (DRACO)").
        set F9DWarn:style:textcolor to F9DGray.
    } else {
        F9DText(F9DWarn, "• " + err).
        set F9DWarn:style:textcolor to choose F9DGray if err:contains("already") else F9DRed.
    }
}

function F9DLng {
    parameter x.
    local y is mod(x + 180, 360).
    if y < 0 set y to y + 360.
    return y - 180.
}

function F9DGeoTxt {
    parameter lat, lng.
    return round(abs(lat), 1) + "°" + (choose "N" if lat >= 0 else "S") + " " + round(abs(lng), 1) + "°" + (choose "E" if lng >= 0 else "W").
}

function F9DRel {
    parameter t.
    return positionat(ship, t) - body:position.
}

function F9DVr {
    parameter t.
    return vdot(velocityat(ship, t):orbit, F9DRel(t):normalized).
}

function F9DGeo {
    parameter p, t.
    local g is body:geopositionof(body:position + p).
    return list(g:lat, F9DLng(g:lng - (t - time:seconds) * 360 / body:rotationperiod)).
}

function F9DOcean {
    parameter lat, lng.
    local d is 25000 / body:radius * constant:radtodeg.
    local dl is d / max(0.2, cos(lat)).
    for o in list(list(0, 0), list(d, 0), list(-d, 0), list(0, dl), list(0, -dl)) {
        if body:geopositionlatlng(lat + o[0], F9DLng(lng + o[1])):terrainheight >= 0 return false.
    }
    return true.
}

function F9DSunEl {
    parameter lat, lng, t.
    local s is F9DGeo(sun:position - body:position, t).
    local c is sin(lat) * sin(s[0]) + cos(lat) * cos(s[0]) * cos(lng - s[1]).
    return 90 - arccos(max(-1, min(1, c))).
}

function F9DSiteOk {
    parameter lat, lng, t.
    if F9DWantOcean and not F9DOcean(lat, lng) return false.
    if F9DWantDay and F9DSunEl(lat, lng, t) < F9DSunMin return false.
    return true.
}

function F9DBisect {
    parameter lo, hi, fn.
    from { local i is 0. } until i >= 12 step { set i to i + 1. } do {
        local md is (lo + hi) / 2.
        if fn:call(md) set lo to md.
        else set hi to md.
    }
    return (lo + hi) / 2.
}

function F9DNode {
    parameter t, peT.
    local rt is F9DRel(t):mag.
    local vt is velocityat(ship, t):orbit:mag.
    local dv is max(0, vt - sqrt(body:mu * max(0, 2 / rt - 2 / (rt + body:radius + peT)))).
    local nd is node(t, 0, 0, -dv).
    add nd.
    return nd.
}

function F9DScreen {
    parameter t, peT.
    local nd is F9DNode(t, peT).
    local tPe is F9DBisect(t + 5, t + 0.6 * nd:orbit:period, { parameter x. return F9DVr(x) < 0. }).
    local tEI is F9DBisect(t, tPe, { parameter x. return F9DRel(x):mag - body:radius > body:atm:height. }).
    local tE is tEI + F9DRangeK * (tPe - tEI).
    local g is F9DGeo(F9DRel(tE), tE).
    local res is lexicon("t", t, "lat", g[0], "lng", g[1], "ti", tE, "tr", false).
    remove nd.
    return res.
}

function F9DTrOk {
    if not addons:available("tr") return false.
    return addons:tr:available.
}

function F9DTrImpact {
    local tw is time:seconds.
    local last is "".
    wait 0.5.
    until time:seconds - tw > 8 {
        if addons:tr:hasimpact {
            local g is addons:tr:impactpos.
            if not last:istype("String") and (g:position - last:position):mag < 2000 {
                return list(g:lat, g:lng, time:seconds + addons:tr:timetillimpact).
            }
            set last to g.
        }
        wait 0.5.
    }
    return list().
}

function F9DPlan {
    parameter peT.
    set F9DPhase to "search".
    local tr is F9DTrOk().
    if tr and addons:tr:isverttwotwo set addons:tr:retrograde to true.
    if not tr F9DLog("  Trajectories unavailable - point from vacuum estimate").
    if ship:orbit:eccentricity > F9DEccOk {
        F9DLog("  ORBIT NOT CIRCULAR, ecc " + round(ship:orbit:eccentricity, 4) +
               " - retrograde node, point is approximate").
    }
    local st is ship:orbit:period / F9DSteps.
    local t0 is time:seconds + F9DLead.
    local t is t0.
    local n is 0.
    until t > t0 + F9DSearchH * 3600 or F9DAbort or n >= F9DTrTries {
        set F9DPlanTxt to "SEARCHING · +" + round((t - time:seconds) / 3600, 1) + " h · CHECKS " + n.
        local s is F9DScreen(t, peT).
        if F9DSiteOk(s["lat"], s["lng"], s["ti"]) {
            local nd is F9DNode(t, peT).
            if not tr return s.
            set n to n + 1.
            local im is F9DTrImpact().
            if im:length > 0 {
                F9DLog("  +" + round((t - time:seconds) / 60) + " min: vacuum " + F9DGeoTxt(s["lat"], s["lng"]) + " / Trajectories " + F9DGeoTxt(im[0], im[1])).
                if F9DSiteOk(im[0], im[1], im[2]) {
                    set s["lat"] to im[0].
                    set s["lng"] to im[1].
                    set s["ti"] to im[2].
                    set s["tr"] to true.
                    return s.
                }
            } else F9DLog("  +" + round((t - time:seconds) / 60) + " min: Trajectories gave no impact point").
            remove nd.
        }
        set t to t + st.
    }
    return lexicon().
}

function F9DWarpTo {
    parameter t.
    if t - time:seconds > 30 kuniverse:timewarp:warpto(t).
    until time:seconds >= t or F9DAbort { wait 0.5. }
    if F9DAbort kuniverse:timewarp:cancelwarp().
    wait until kuniverse:timewarp:issettled.
}

function F9DAligned {
    return vang(ship:facing:forevector, F9DSgn * retrograde:vector) < 3.
}

function F9DAlign {
    lock steering to F9DSgn * retrograde:vector.
    local tw is time:seconds.
    wait until F9DAligned() or time:seconds - tw > 90 or F9DAbort.
    wait 2.
}

function F9DEnergy {
    return ship:velocity:orbit:sqrmagnitude / 2 - body:mu / body:position:mag.
}

function F9DPulse {
    local e0 is F9DEnergy().
    local t0 is time:seconds.
    set ship:control:fore to F9DSgn.
    wait 2.
    set ship:control:fore to 0.
    local dt is max(0.1, time:seconds - t0).
    return (e0 - F9DEnergy()) / dt / ship:velocity:orbit:mag.
}

function F9DExec {
    parameter peT.
    local nd is nextnode.
    local dv is nd:deltav:mag.
    set F9DBurnT to nd:time - dv / (2 * F9DAccEst).
    set F9DPhase to "wait".
    F9DWarpTo(F9DBurnT - F9DPrep).
    if F9DAbort return.
    F9DLog("preparing: nose, attitude, test pulse").
    sas off.
    rcs on.
    F9DNose(true).
    local tw is time:seconds.
    wait until F9DNoseOpen() or time:seconds - tw > 15.
    wait 3.
    F9DAlign().
    local a is F9DPulse().
    if a < 0.02 and not F9DAbort {
        F9DLog("  fore " + F9DSgn + " does not brake (" + round(a, 3) + " m/s²) - flipping").
        set F9DSgn to -F9DSgn.
        F9DAlign().
        set a to F9DPulse().
    }
    if a < 0.02 or F9DAbort {
        F9DLog("  RCS does not brake (" + round(a, 3) + " m/s²) - aborting").
        return.
    }
    set F9DAccEst to a.
    set dv to nd:deltav:mag.
    set F9DBurnT to nd:time - dv / (2 * a).
    F9DLog("  RCS " + round(a, 3) + " m/s² · fore " + F9DSgn + " · ΔV " + round(dv, 1) + " m/s · burn ~" + round(dv / a) + " s").
    wait until time:seconds >= F9DBurnT or F9DAbort.
    if F9DAbort return.
    set F9DPhase to "burn".
    set tw to time:seconds.
    set ship:control:fore to F9DSgn.
    until ship:periapsis <= peT or F9DAbort or time:seconds - tw > 3 * dv / a + 60 or F9DResFrac("MonoPropellant") <= 0.001 {
        wait 0.1.
    }
    set ship:control:fore to 0.
    F9DLog("  burn end: periapsis " + round(ship:periapsis / 1000, 1) + " km · " + round(time:seconds - tw) + " s · mono " + round(100 * F9DResFrac("MonoPropellant")) + "%").
}

function F9DDeorbitEnd {
    set ship:control:fore to 0.
    set ship:control:neutralize to true.
    unlock steering.
    until not hasnode { remove nextnode. wait 0. }
    F9DNose(false).
    rcs off.
    sas on.
    set F9DPhase to "".
    set F9DPlanTxt to "".
    set F9DBurning to false.
}

function F9DDeorbit {
    parameter peT.
    set F9DAbort to false.
    set F9DBurning to true.
    until not hasnode { remove nextnode. wait 0. }
    F9DLog("deorbit: periapsis " + round(peT / 1000, 1) + " km · ocean " + F9DWantOcean + " · day " + F9DWantDay).
    if F9DWantOcean or F9DWantDay {
        local s is F9DPlan(peT).
        if s:length = 0 {
            F9DLog(choose "  search cancelled" if F9DAbort else "  no suitable point within " + F9DSearchH + " h").
            F9DDeorbitEnd().
            return.
        }
        local el is round(F9DSunEl(s["lat"], s["lng"], s["ti"])).
        set F9DPlanTxt to "SITE " + F9DGeoTxt(s["lat"], s["lng"]) + " · SUN " + el + "°" + (choose "" if s["tr"] else " · VACUUM EST").
        F9DLog("  point " + F9DGeoTxt(s["lat"], s["lng"]) + " · sun " + el + "° · " + (choose "Trajectories" if s["tr"] else "vacuum") + " · node in " + F9DHms(s["t"] - time:seconds)).
    } else {
        F9DNode(time:seconds + F9DPrep + 60 + F9DDeorbitDv(peT) / (2 * F9DAccEst), peT).
        set F9DPlanTxt to "DEORBIT NOW".
    }
    F9DExec(peT).
    F9DDeorbitEnd().
}

function F9DRelease {
    if not F9DHold return.
    set F9DHold to false.
    unlock steering.
    rcs off.
    F9DLog("heat shield hold released").
}

function F9DAutoStep {
    local atm is body:atm:height.
    local dr is F9DChuteSt("DROGUES").
    local mn is F9DChuteSt("MAINS").
    local fall is not F9DDown() and not F9DBurning and ship:periapsis < atm and ship:verticalspeed < -1.
    local want is fall and ship:altitude < atm * F9DTrunkK and (dr = "stowed" or dr = "none") and mn = "stowed".
    if want and not F9DHold {
        set F9DHold to true.
        F9DNose(false).
        F9DJettison().
        sas off.
        rcs on.
        lock steering to srfretrograde.
        F9DLog("before entry: heat shield forward · h " + round(ship:altitude / 1000, 1) + " km").
    }
    if not want F9DRelease().
    if not fall return.
    local h is alt:radar.
    if dr = "stowed" and h < F9DDrogueH and (ship:airspeed < F9DDrogueV or h < F9DDrogueH * 0.8) F9DArm("DROGUES").
    if mn = "stowed" and dr <> "stowed" and dr <> "armed" and h < F9DMainH and (ship:airspeed < F9DMainV or h < F9DMainH * 0.75) F9DArm("MAINS").
}

function F9DChuteLamp {
    parameter st.
    if st = "open" return "green".
    if st = "armed" return "yellow".
    return "off".
}

function F9DTick {
    local atm is body:atm:height.
    local dr is F9DChuteSt("DROGUES").
    local mn is F9DChuteSt("MAINS").
    local st is "IN ORBIT".
    if ship:status = "SPLASHED" set st to "SPLASHDOWN".
    else if ship:status = "LANDED" set st to "LANDED".
    else if F9DPhase = "search" set st to "SITE SEARCH".
    else if F9DPhase = "wait" set st to "BURN IN " + F9DHms(F9DBurnT - time:seconds).
    else if F9DPhase = "burn" set st to "DEORBIT BURN".
    else if F9DPhase = "rnwait" set st to "BURN IN " + F9DHms(F9DBurnT - time:seconds).
    else if F9DPhase = "rnburn" set st to "RCS BURN".
    else if F9DPhase = "approach" set st to "APPROACH".
    else if F9DPhase = "dock" set st to "DOCKING".
    else if mn = "open" or mn = "armed" set st to "MAINS".
    else if dr = "open" or dr = "armed" set st to "DROGUES".
    else if ship:periapsis < atm set st to choose "ENTRY" if ship:altitude < atm else "ENTRY COURSE".
    F9DText(F9DClock, "T+" + F9DHms(missiontime)).
    F9DText(F9DState, st).
    F9DText(F9DCurAp, F9DKm(ship:apoapsis)).
    F9DText(F9DCurPe, F9DKm(ship:periapsis)).

    local mf is F9DResFrac("MonoPropellant").
    F9DBarPct(F9DBMono, mf, choose "blue" if mf > 0.25 else "yellow").
    local af is F9DResFrac("Ablator").
    F9DBarPct(F9DBAbl, af, choose "green" if af > 0.25 else "yellow").

    local trOn is not F9DTrunk():istype("String").
    local nose is F9DNoseOpen().
    local sts is list(choose "green" if trOn else "off",
                      choose "green" if nose else "yellow",
                      choose "green" if rcs else "off",
                      F9DChuteLamp(dr),
                      F9DChuteLamp(mn)).
    from { local i is 0. } until i >= 5 step { set i to i + 1. } do {
        F9DBg("dl" + i, F9DLampL[i], "lamp_" + sts[i]).
    }
    if F9DRcsB:pressed <> rcs set F9DRcsB:pressed to rcs.
    F9DText(F9DNoseB, choose "CLOSE NOSE" if nose else "OPEN NOSE").

    local busy is F9DBurning or F9DDown().
    local inSpace is ship:altitude > atm.
    if F9DBurning {
        F9DText(F9DWarn, F9DPlanTxt).
        set F9DWarn:style:textcolor to F9DAcc.
    } else F9DValidate().
    F9DText(F9DDeorbB, choose "CANCEL" if F9DBurning else "DEORBIT").
    F9DEnable("deorb", F9DDeorbB, "red", F9DBurning or (F9DOk and not F9DDown() and inSpace)).
    F9DEnable("trunk", F9DTrunkB, "btn", trOn and not busy).
    F9DEnable("nose", F9DNoseB, "btn", inSpace and not busy).
    F9DEnable("ocean", F9DOceanB, "btn", not busy).
    F9DEnable("day", F9DDayB, "btn", not busy).
    F9DEnable("chutes", F9DChuteB, "blue", (dr = "stowed" or mn = "stowed") and not F9DDown()).
    local tg is F9DTgtOk() and inSpace.
    local docked is false.
    for dp in ship:dockingports { if dp:state:contains("Docked") set docked to true. }
    F9DEnable("plane", F9DPlaneB, "btn", tg and not busy).
    F9DEnable("rndz", F9DRndzB, "blue", tg and not busy).
    F9DEnable("app", F9DAppB, "btn", tg and not busy).
    F9DEnable("dock", F9DDockB, "blue", tg and not busy).
    F9DEnable("undock", F9DUndockB, "red", docked and not F9DBurning).
    if F9DTgtOk() {
        local tv is F9DTgtV().
        local dd is tv:distance.
        local dtx is round(dd / 1000, 1) + " km".
        if dd < 10000 set dtx to round(dd) + " m".
        local ptx is " · PORT".
        if F9DMyPort():istype("String") set ptx to " · NO PORT".
        F9DText(F9DTgtVal, dtx + " · pl " + round(F9DRelInc(), 2) + "° · ph " + round(F9DPhaseAng()) + "°" + ptx).
        F9DBg("tgl", F9DTgtLamp, choose "lamp_green" if dd < 2000 else "lamp_yellow").
    } else {
        F9DText(F9DTgtVal, "—").
        F9DBg("tgl", F9DTgtLamp, "lamp_off").
    }

    if not F9DDown() and not F9DBurning and ship:periapsis < atm and time:seconds > F9DLogNext {
        set F9DLogNext to time:seconds + 5.
        F9DLog("h " + round(ship:altitude) + " v " + round(ship:airspeed) + " vs " + round(ship:verticalspeed) + " pe " + round(ship:periapsis / 1000, 1) + " trunk " + trOn + " nose " + nose + " drogue " + dr + " main " + mn).
    }
    if F9DDown() and not F9DDownLogged {
        set F9DDownLogged to true.
        F9DLog(ship:status + " " + F9DGeoTxt(ship:latitude, ship:longitude) + " · v " + round(ship:airspeed, 1) + " m/s · ablator " + round(100 * af) + "%").
    }
}

function F9DLim1 {
    parameter x.
    if x > 1 return 1.
    if x < -1 return -1.
    return x.
}

function F9DTgtOk {
    if not hastarget return false.
    if target:istype("DockingPort") return target:ship:body = ship:body.
    if not target:istype("Vessel") return false.
    return target:body = ship:body.
}

function F9DTgtV {
    if target:istype("DockingPort") return target:ship.
    return target.
}

function F9DNorm {
    parameter pos, vel.
    return vcrs(pos, vel):normalized.
}

function F9DTgtNorm {
    local tv is F9DTgtV().
    return F9DNorm(tv:position - body:position, tv:velocity:orbit).
}

function F9DRelInc {
    if not F9DTgtOk() return 0.
    return vang(F9DNorm(-body:position, ship:velocity:orbit), F9DTgtNorm()).
}

function F9DPhaseAng {
    if not F9DTgtOk() return 0.
    local hn is F9DNorm(-body:position, ship:velocity:orbit).
    local aa is vxcl(hn, -body:position).
    local bb is vxcl(hn, F9DTgtV():position - body:position).
    local ang is vang(aa, bb).
    if vdot(vcrs(aa, bb), hn) < 0 return 360 - ang.
    return ang.
}

function F9DNodeTime {
    local ln0 is vcrs(F9DNorm(-body:position, ship:velocity:orbit), F9DTgtNorm()):normalized.
    local per is ship:orbit:period.
    local best is 0.
    local bv is 999.
    local stp is per / 180.
    local tt is 0.
    until tt > per {
        local pp is F9DRel(time:seconds + tt).
        local aa is min(vang(pp, ln0), vang(pp, -ln0)).
        if aa < bv {
            set bv to aa.
            set best to tt.
        }
        set tt to tt + stp.
    }
    local half is stp.
    until half < 0.5 {
        set half to half / 2.
        for sg in list(-1, 1) {
            local t2 is best + sg * half.
            if t2 > 0 {
                local pp is F9DRel(time:seconds + t2).
                local aa is min(vang(pp, ln0), vang(pp, -ln0)).
                if aa < bv {
                    set bv to aa.
                    set best to t2.
                }
            }
        }
    }
    return time:seconds + best.
}

function F9DOrbNode {
    parameter t, rOther.
    local rr is F9DRel(t):mag.
    local rLo is body:radius + ship:periapsis - 1000.
    local rHi is body:radius + ship:apoapsis + 1000.
    if rr < rLo or rr > rHi {
        F9DLog("  NODE NOT PLACED: r " + round(rr / 1000, 1) + " km outside orbit " + round(rLo / 1000, 1) + "..." + round(rHi / 1000, 1)).
        local n0 is node(t, 0, 0, 0).
        add n0.
        return n0.
    }
    local vNow is velocityat(ship, t):orbit:mag.
    local vWant is sqrt(body:mu * max(0, 2 / rr - 2 / (rr + rOther))).
    local nd is node(t, 0, 0, vWant - vNow).
    add nd.
    F9DLog("  node: r " + round(rr / 1000, 1) + " km, have " + round(vNow, 1) + ", need " + round(vWant, 1) + ", dv " + round(vWant - vNow, 1)).
    return nd.
}

// Пробный импульс по факту: сколько м/с² даёт fore вдоль F9DPushDir.
// Гравитацию за время пробы вычитаем, иначе на радиальной компоненте она
// за две секунды наберёт больше, чем Draco.
function F9DProbe1 {
    local v0 is ship:velocity:orbit.
    local t0 is time:seconds.
    set ship:control:fore to F9DSgn.
    wait 2.
    set ship:control:fore to 0.
    local dt is max(0.1, time:seconds - t0).
    local gv is body:position:normalized * body:mu / body:position:sqrmagnitude.
    return vdot(ship:velocity:orbit - v0 - gv * dt, F9DPushDir:normalized) / dt.
}

function F9DPoint {
    local tw is time:seconds.
    wait until vang(ship:facing:forevector, F9DSgn * F9DPushDir) < 3 or time:seconds - tw > 90 or F9DAbort.
    wait 1.
}

function F9DProbe {
    F9DPoint().
    local a is F9DProbe1().
    if a < 0.02 and not F9DAbort {
        F9DLog("  fore " + F9DSgn + " does not push (" + round(a, 3) + " m/s²) - flipping").
        set F9DSgn to -F9DSgn.
        F9DPoint().
        set a to F9DProbe1().
    }
    return a.
}

// Любой узел на RCS: та же схема, что у схода (нос, ориентация, проба
// знака fore), но стоп по остатку узла, а не по перигею.
function F9DExecNode {
    parameter nd.
    local dv is nd:deltav:mag.
    if dv < 0.1 {
        remove nd.
        return true.
    }
    local av is F9DDvAvail().
    if dv > av {
        F9DLog("BURN EXCEEDS RESERVE: need " + round(dv, 1) + " m/s, monoprop for " + round(av, 1) + " - node removed").
        remove nd.
        return false.
    }
    set F9DPhase to "rnwait".
    set F9DBurnT to nd:time - dv / (2 * F9DAccEst).
    F9DWarpTo(F9DBurnT - F9DPrep).
    if F9DAbort {
        remove nd.
        return false.
    }
    sas off.
    rcs on.
    F9DNose(true).
    local tw is time:seconds.
    wait until F9DNoseOpen() or time:seconds - tw > 15.
    set F9DPushDir to nd:deltav.
    lock steering to F9DSgn * F9DPushDir.
    local a is F9DProbe().
    if a < 0.02 or F9DAbort {
        F9DLog("  RCS does not push (" + round(a, 3) + " m/s²) - aborting").
        remove nd.
        return false.
    }
    set F9DAccEst to a.
    set dv to nd:deltav:mag.
    set F9DBurnT to nd:time - dv / (2 * a).
    F9DLog("  RCS " + round(a, 3) + " m/s² · fore " + F9DSgn + " · ΔV " + round(dv, 1) + " m/s · burn ~" + round(dv / a) + " s").
    set F9DPushDir to nd:deltav.
    wait until time:seconds >= F9DBurnT or F9DAbort.
    if F9DAbort {
        remove nd.
        return false.
    }
    set F9DPhase to "rnburn".
    local d0 is nd:deltav:normalized.
    set tw to time:seconds.
    until nd:deltav:mag < 0.1 or vdot(d0, nd:deltav) < 0 or F9DAbort
          or time:seconds - tw > 3 * dv / a + 60 or F9DResFrac("MonoPropellant") <= 0.001 {
        if nd:deltav:mag > 1 set F9DPushDir to nd:deltav.
        set ship:control:fore to F9DSgn * min(1, max(0.1, nd:deltav:mag / a)).
        wait 0.1.
    }
    set ship:control:fore to 0.
    F9DLog("  burn end: remaining " + round(nd:deltav:mag, 2) + " m/s · ap " + round(ship:apoapsis / 1000, 1) + " pe " + round(ship:periapsis / 1000, 1) + " km · mono " + round(100 * F9DResFrac("MonoPropellant")) + "%").
    remove nd.
    return not F9DAbort.
}

function F9DOpEnd {
    set ship:control:fore to 0.
    set ship:control:neutralize to true.
    unlock steering.
    until not hasnode { remove nextnode. wait 0. }
    core:part:controlfrom().
    rcs off.
    sas on.
    set F9DPhase to "".
    set F9DPlanTxt to "".
    set F9DBurning to false.
}

function F9DMatchPlane {
    if not F9DTgtOk() return.
    local di is F9DRelInc().
    if di < F9DRnIncOk {
        F9DLog("planes already match: " + round(di, 3) + "°").
        return.
    }
    set F9DAbort to false.
    set F9DBurning to true.
    until not hasnode { remove nextnode. wait 0. }
    local tn is F9DNodeTime().
    local vv is velocityat(ship, tn):orbit:mag.
    local dv0 is 2 * vv * sin(di / 2).
    local nd is node(tn, 0, dv0, 0).
    add nd.
    local nT is F9DTgtNorm().
    local nWant is -vdot(velocityat(ship, tn):orbit, nT) * nT.
    if vdot(nd:deltav, nWant) < 0 set nd:normal to -dv0.
    set F9DPlanTxt to "PLANE " + round(di, 2) + "° · " + round(dv0, 1) + " m/s".
    F9DLog("plane change to " + F9DTgtV():name + ": " + round(di, 2) + "° · " + round(dv0, 1) + " m/s · in " + F9DHms(tn - time:seconds)).
    F9DExecNode(nd).
    F9DLog("  remaining " + round(F9DRelInc(), 3) + "°").
    F9DOpEnd().
}

function F9DRndz {
    if not F9DTgtOk() return.
    local tv is F9DTgtV().
    if F9DRelInc() > F9DRnIncWarn {
        F9DLog("MATCH PLANE first: " + round(F9DRelInc(), 2) + "°").
        return.
    }
    if ship:orbit:eccentricity > F9DRnEccOk or tv:orbit:eccentricity > F9DRnEccOk {
        F9DLog("phasing assumes circular orbits: ecc " + round(ship:orbit:eccentricity, 4) + " / target " + round(tv:orbit:eccentricity, 4)).
        return.
    }
    local r2 is tv:orbit:semimajoraxis.
    local r1 is ship:orbit:semimajoraxis.
    local tH is constant:pi * sqrt(((r1 + r2) / 2) ^ 3 / body:mu).
    local w2 is 360 / tv:orbit:period.
    local w1 is 360 / ship:orbit:period.
    local need is mod(180 - w2 * tH + 720, 360).
    local dw is w2 - w1.
    if abs(dw) < 0.000001 {
        F9DLog("phase does not change: orbits have the same period").
        return.
    }
    local wait0 is mod(need - F9DPhaseAng() + 720, 360) / dw.
    if dw < 0 set wait0 to mod(F9DPhaseAng() - need + 720, 360) / (-dw).
    set F9DAbort to false.
    set F9DBurning to true.
    until not hasnode { remove nextnode. wait 0. }
    set F9DPlanTxt to "RENDEZVOUS · WAIT " + F9DHms(wait0) + " · TRANSFER " + F9DHms(tH).
    F9DLog("rendezvous with " + tv:name + ": wait " + F9DHms(wait0) + ", transfer " + F9DHms(tH) + ", phase " + round(F9DPhaseAng(), 1) + " / needed " + round(need, 1)).
    if F9DExecNode(F9DOrbNode(time:seconds + wait0, r2)) {
        wait 1.
        local nd2 is "".
        if r2 > r1 set nd2 to F9DOrbNode(time:seconds + eta:apoapsis, body:radius + ship:apoapsis).
        else set nd2 to F9DOrbNode(time:seconds + eta:periapsis, body:radius + ship:periapsis).
        F9DExecNode(nd2).
        F9DLog("  to target " + round(tv:distance / 1000, 2) + " km").
    }
    F9DOpEnd().
}

// Подход на RCS до F9DAppStop: гасим ОШИБКУ скорости, а не скорость.
function F9DApproach {
    if not F9DTgtOk() return.
    local tv is F9DTgtV().
    if tv:distance > F9DAppFar {
        F9DLog("approach: to target " + round(tv:distance / 1000, 1) + " km - RENDEZVOUS first").
        return.
    }
    set F9DAbort to false.
    set F9DBurning to true.
    set F9DPhase to "approach".
    F9DLog("approach to " + tv:name + ": " + round(tv:distance) + " m, " + round((ship:velocity:orbit - tv:velocity:orbit):mag, 1) + " m/s").
    sas off.
    rcs on.
    F9DNose(true).
    set F9DPushDir to tv:position.
    lock steering to F9DPushDir.
    local t0 is time:seconds.
    local tp is 0.
    until F9DAbort {
        local d is tv:distance.
        local rel is ship:velocity:orbit - tv:velocity:orbit.
        set F9DPushDir to tv:position.
        if d < F9DAppStop and rel:mag < 0.5 break.
        if time:seconds - t0 > F9DAppTmax {
            F9DLog("  approach: timeout").
            break.
        }
        if F9DResFrac("MonoPropellant") <= 0.001 {
            F9DLog("  approach: out of monopropellant").
            break.
        }
        local vA is min(F9DAppVmax, max(0.3, d * F9DAppK)).
        if d < F9DAppStop set vA to 0.
        local err is tv:position:normalized * vA - rel.
        set ship:control:fore to F9DLim1(vdot(err, ship:facing:forevector) * F9DAppGain).
        set ship:control:starboard to F9DLim1(vdot(err, ship:facing:starvector) * F9DAppGain).
        set ship:control:top to F9DLim1(vdot(err, ship:facing:topvector) * F9DAppGain).
        set F9DPlanTxt to "APPROACH " + round(d) + " m · " + round(rel:mag, 1) + " m/s".
        if time:seconds - tp > 5 {
            set tp to time:seconds.
            F9DLog("  " + round(d) + " m, " + round(rel:mag, 1) + " m/s, need " + round(vA, 1)).
        }
        wait 0.1.
    }
    F9DLog("approach: " + round(tv:distance) + " m, " + round((ship:velocity:orbit - tv:velocity:orbit):mag, 2) + " m/s" + (choose " - ABORTED" if F9DAbort else "")).
    F9DOpEnd().
}

function F9DMyPort {
    for dp in ship:dockingports {
        if dp:state = "Ready" return dp.
    }
    return "".
}

function F9DTgtPort {
    if target:istype("DockingPort") return target.
    local best is "".
    local bd is 999999999.
    for dp in target:dockingports {
        if dp:state = "Ready" and dp:distance < bd {
            set best to dp.
            set bd to dp:distance.
        }
    }
    return best.
}

// Стыковка. Управляем от СВОЕГО порта: тогда facing - ось порта, и
// трансляция идёт в его осях. Сначала встаём на ось порта цели на
// F9DDockHold метров, потом идём по оси, закрывая боковую ошибку.
function F9DDock {
    if not F9DTgtOk() return.
    local mp is F9DMyPort().
    if mp:istype("String") {
        F9DLog("DOCKING: Dragon has no free docking port - put a port on the nose (node_top)").
        return.
    }
    local tp is F9DTgtPort().
    if tp:istype("String") {
        F9DLog("DOCKING: target has no free port").
        return.
    }
    if (tp:nodeposition - mp:nodeposition):mag > F9DDockNear {
        F9DLog("DOCKING: to port " + round((tp:nodeposition - mp:nodeposition):mag) + " m - APPROACH first").
        return.
    }
    set F9DAbort to false.
    set F9DBurning to true.
    set F9DPhase to "dock".
    F9DNose(true).
    local tw is time:seconds.
    wait until F9DNoseOpen() or time:seconds - tw > 15.
    mp:controlfrom().
    sas off.
    rcs on.
    set F9DDockDir to lookdirup(-tp:portfacing:vector, -tp:portfacing:upvector).
    lock steering to F9DDockDir.
    F9DLog("docking: " + mp:name + " -> " + tp:name + " at " + tp:ship:name).
    local t0 is time:seconds.
    local tp0 is 0.
    local done is false.
    until F9DAbort {
        if mp:state:contains("Docked") or mp:state:contains("Acquire") {
            set done to true.
            break.
        }
        if time:seconds - t0 > F9DDockTmax {
            F9DLog("  docking: timeout").
            break.
        }
        if F9DResFrac("MonoPropellant") <= 0.001 {
            F9DLog("  docking: out of monopropellant").
            break.
        }
        local ax is tp:portfacing:vector.
        set F9DDockDir to lookdirup(-ax, -tp:portfacing:upvector).
        local ofs is mp:nodeposition - tp:nodeposition.
        local al is vdot(ofs, ax).
        local lat is vxcl(ax, ofs).
        local ok is vang(mp:portfacing:vector, -ax) < 5.
        local vw is V(0, 0, 0).
        if al < F9DDockHold * 0.5 and lat:mag > 1 {
            set vw to ax * min(0.5, (F9DDockHold - al) * 0.1) - lat * 0.1.
        } else if lat:mag > max(F9DDockLat, al * 0.05) or not ok {
            set vw to ax * max(-0.5, min(0.5, (F9DDockHold - al) * 0.05)) - lat * 0.1.
        } else {
            set vw to -ax * min(F9DDockVmax, max(F9DDockVmin, al * 0.04)) - lat * 0.2.
        }
        if vw:mag > F9DDockVmax set vw to vw:normalized * F9DDockVmax.
        local rel is ship:velocity:orbit - tp:ship:velocity:orbit.
        local err is vw - rel.
        set ship:control:fore to F9DLim1(vdot(err, ship:facing:forevector) * F9DDockGain).
        set ship:control:starboard to F9DLim1(vdot(err, ship:facing:starvector) * F9DDockGain).
        set ship:control:top to F9DLim1(vdot(err, ship:facing:topvector) * F9DDockGain).
        set F9DPlanTxt to "DOCK · AXIS " + round(al, 1) + " m · OFF " + round(lat:mag, 2) + " m · " + round(rel:mag, 2) + " m/s".
        if time:seconds - tp0 > 5 {
            set tp0 to time:seconds.
            F9DLog("  axis " + round(al, 1) + " m, side " + round(lat:mag, 2) + " m, " + round(rel:mag, 2) + " m/s, aligned " + ok).
        }
        wait 0.1.
    }
    if done F9DLog("DOCKING: capture").
    else if F9DAbort F9DLog("docking stopped - ABORT").
    else F9DLog("docking stopped").
    F9DOpEnd().
}

function F9DUndock {
    for dp in ship:dockingports {
        if dp:state:contains("Docked") {
            dp:undock().
            F9DLog("undocking: " + dp:name).
            wait 1.
            set ship:control:fore to -1.
            wait 3.
            set ship:control:fore to 0.
            set ship:control:neutralize to true.
            return.
        }
    }
    F9DLog("undocking: no docked ports").
}

// Загрузчик после первой сборки ставит bootfilename на f9dragon.ksm и
// дальше борт с архивом не сверяет - правки молча не доходят до капсулы.
if homeconnection:isconnected and exists("0:/f9dragon.ks") and exists("1:/boot/f9dragon.ks") {
    local sa is open("0:/f9dragon.ks"):readall:string:replace(char(65279), ""):replace(char(13), "").
    local sb is open("1:/boot/f9dragon.ks"):readall:string:replace(char(65279), ""):replace(char(13), "").
    if sa <> sb {
        print "!!! OLD BUILD ON BOARD - f9dragon in the Archive is newer.".
        print "!!! length: archive " + sa:length + ", on board " + sb:length + ".".
        print "!!! to update: runpath(" + char(34) + "0:/boot/f9dragon.ks" + char(34) + ").".
        hudtext("DRAGON: OLD BUILD ON BOARD", 15, 2, 24, red, false).
    }
}

if F9DAttached() {
    print "Dragon is on the rocket - waiting for separation.".
    until not F9DAttached() { wait 1. }
}
F9DLog("=== Dragon free: " + ship:name + " · ap " + round(ship:apoapsis / 1000, 1) + " pe " + round(ship:periapsis / 1000, 1) + " km").
set F9DShroud to F9DShroudMod().
if F9DShroud:istype("String") F9DLog("  nose cone not found: " + F9DEvents(core:part)).

set F9DWin to gui(440).
set F9DWin:x to 500.
set F9DWin:y to 120.
set F9DWin:style:bg to F9DImg + "panel_bg".
set F9DWin:style:on:bg to F9DImg + "panel_bg".
set F9DWin:style:border:h to 12.
set F9DWin:style:border:v to 12.
set F9DWin:style:padding:h to 18.
set F9DWin:style:padding:top to 14.
set F9DWin:style:padding:bottom to 16.

set F9DHd to F9DWin:addhlayout().
set F9DLogo to F9DHd:addlabel("").
set F9DLogo:style:bg to F9DImg + "logo".
F9DNoBorder(F9DLogo).
set F9DLogo:style:width to 24.
set F9DLogo:style:height to 24.
set F9DLogo:style:margin:top to 6.
set F9DHdT to F9DHd:addvlayout().
F9DLabel(F9DHdT, "DRAGON", 12, white).
F9DLabel(F9DHdT, "kOS CAPSULE CTRL", 9, F9DGray).
F9DHd:addspacing(-1).
set F9DHdR to F9DHd:addvlayout().
set F9DClock to F9DLabel(F9DHdR, "", 19, F9DAcc, true, "right").
set F9DState to F9DLabel(F9DHdR, "", 9, F9DGray, true, "right").
// 24.09: управление капсулой сырое - в релизе помечено, что доделается позже.
set F9DBeta to F9DLabel(F9DWin, "EXPERIMENTAL - full Dragon control will be in the next version", 10, F9DYel, true, "center").
set F9DBeta:style:wordwrap to true.
F9DDivider(F9DWin).

set F9DCurRow to F9DWin:addhlayout().
set F9DCurAp to F9DBig(F9DCurRow, "APOAPSIS").
set F9DCurPe to F9DBig(F9DCurRow, "PERIAPSIS").
set F9DFPe to F9DField(F9DWin, "Entry periapsis", round(body:atm:height * 0.3 / 1000), "km").
set F9DWarn to F9DLabel(F9DWin, "", 10, F9DGray).
set F9DWarn:style:wordwrap to true.
set F9DRow3 to F9DWin:addhlayout().
set F9DOceanB to F9DButton(F9DRow3, "OCEAN", "btn", 34, 10).
set F9DOceanB:toggle to true.
set F9DDayB to F9DButton(F9DRow3, "DAYLIGHT", "btn", 34, 10).
set F9DDayB:toggle to true.
set F9DDeorbB to F9DButton(F9DWin, "DEORBIT", "red", 42, 12).
set F9DRow1 to F9DWin:addhlayout().
set F9DTrunkB to F9DButton(F9DRow1, "JETTISON TRUNK", "btn", 34, 10).
set F9DNoseB to F9DButton(F9DRow1, "OPEN NOSE", "btn", 34, 10).
set F9DRow2 to F9DWin:addhlayout().
set F9DRcsB to F9DButton(F9DRow2, "RCS", "btn", 34, 10).
set F9DRcsB:toggle to true.
set F9DAutoB to F9DButton(F9DRow2, "AUTO ENTRY", "btn", 34, 10).
set F9DAutoB:toggle to true.
set F9DChuteB to F9DButton(F9DWin, "ARM CHUTES", "blue", 36, 12).
F9DDivider(F9DWin).
set F9DTgtRow to F9DWin:addhlayout().
set F9DTgtLamp to F9DLamp(F9DTgtRow).
F9DLabel(F9DTgtRow, "TARGET", 11, F9DGray).
F9DTgtRow:addspacing(-1).
set F9DTgtVal to F9DLabel(F9DTgtRow, "—", 12, white, true, "right").
set F9DRow4 to F9DWin:addhlayout().
set F9DPlaneB to F9DButton(F9DRow4, "MATCH PLANE", "btn", 34, 10).
set F9DRndzB to F9DButton(F9DRow4, "RENDEZVOUS", "blue", 34, 10).
set F9DRow5 to F9DWin:addhlayout().
set F9DAppB to F9DButton(F9DRow5, "APPROACH", "btn", 34, 10).
set F9DDockB to F9DButton(F9DRow5, "DOCK", "blue", 34, 10).
set F9DUndockB to F9DButton(F9DWin, "UNDOCK", "red", 30, 10).
F9DDivider(F9DWin).
set F9DBMono to F9DBarRow(F9DWin, "MONO").
set F9DBAbl to F9DBarRow(F9DWin, "ABLATOR").
set F9DLampL to F9DLamps(F9DWin, list("TRUNK", "NOSE", "RCS", "DROGUE", "MAIN")).

set F9DAutoB:pressed to true.
set F9DOceanB:pressed to F9DWantOcean.
set F9DDayB:pressed to F9DWantDay.
set F9DRcsB:pressed to rcs.
set F9DRcsB:ontoggle to { parameter pr. set rcs to pr. }.
set F9DAutoB:ontoggle to { parameter pr. set F9DAuto to pr. }.
set F9DOceanB:ontoggle to { parameter pr. set F9DWantOcean to pr. }.
set F9DDayB:ontoggle to { parameter pr. set F9DWantDay to pr. }.
set F9DFPe:onchange to { parameter s. if not F9DBurning F9DValidate(). }.
set F9DDeorbB:onclick to {
    if F9DBurning set F9DAbort to true.
    else if F9DOk set F9DCmd to lexicon("cmd", "deorbit", "pe", F9DNum(F9DFPe, 0) * 1000).
}.
set F9DTrunkB:onclick to { set F9DCmd to lexicon("cmd", "trunk"). }.
set F9DNoseB:onclick to { set F9DCmd to lexicon("cmd", "nose"). }.
set F9DChuteB:onclick to { set F9DCmd to lexicon("cmd", "chutes"). }.
set F9DPlaneB:onclick to { set F9DCmd to lexicon("cmd", "plane"). }.
set F9DRndzB:onclick to { set F9DCmd to lexicon("cmd", "rndz"). }.
set F9DAppB:onclick to { set F9DCmd to lexicon("cmd", "approach"). }.
set F9DDockB:onclick to { set F9DCmd to lexicon("cmd", "dock"). }.
set F9DUndockB:onclick to { set F9DCmd to lexicon("cmd", "undock"). }.

F9DWin:show().
set F9DNext to 0.
when time:seconds > F9DNext then {
    set F9DNext to time:seconds + 0.5.
    F9DTick().
    return true.
}

until false {
    if F9DCmd:istype("Lexicon") {
        local c is F9DCmd.
        set F9DCmd to "".
        if c["cmd"] = "deorbit" F9DDeorbit(c["pe"]).
        else if c["cmd"] = "trunk" F9DJettison().
        else if c["cmd"] = "nose" F9DNose(not F9DNoseOpen()).
        else if c["cmd"] = "plane" F9DMatchPlane().
        else if c["cmd"] = "rndz" F9DRndz().
        else if c["cmd"] = "approach" F9DApproach().
        else if c["cmd"] = "dock" F9DDock().
        else if c["cmd"] = "undock" F9DUndock().
        else if c["cmd"] = "chutes" {
            if F9DChuteSt("DROGUES") = "stowed" F9DArm("DROGUES").
            else F9DArm("MAINS").
        }
    }
    if F9DAuto F9DAutoStep().
    else F9DRelease().
    wait 0.2.
}
