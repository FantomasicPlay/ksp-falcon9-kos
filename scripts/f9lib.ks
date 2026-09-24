
function F9Find {
    parameter pat.
    return ship:partsnamedpattern(pat).
}

function F9ByModule {
    parameter modname.
    local out is list().
    for p in ship:parts {
        if p:hasmodule(modname) out:add(p).
    }
    return out.
}

set F9Ok to true.
set F9Notes to list().

function F9Note {
    parameter txt.
    F9Notes:add(txt).
}

set F9IsS1 to false.
for p in ship:parts {
    if p:hasmodule("ModuleTundraEngineSwitch") set F9IsS1 to true.
}

set F9EngParts to F9ByModule("ModuleTundraEngineSwitch").
if F9EngParts:length = 0 {
    set F9EngParts to F9Find("F9[._]S1[._]Engine").
    if F9EngParts:length > 0 F9Note("octaweb found by name, without ModuleTundraEngineSwitch").
}
if F9EngParts:length = 0 {
    if F9IsS1 set F9Ok to false.
    F9Note("first stage octaweb NOT FOUND").
    set F9Octaweb to "false".
    set F9EngSwitch to "false".
} else {
    set F9Octaweb to F9EngParts[0].
    if F9Octaweb:hasmodule("ModuleTundraEngineSwitch") {
        set F9EngSwitch to F9Octaweb:getmodule("ModuleTundraEngineSwitch").
    } else {
        set F9EngSwitch to "false".
        F9Note("octaweb has no mode switch").
    }
}

set F9ThrAll to 2560.
set F9Thr3 to 1706.
set F9Thr1 to 764.

function F9EngineCount {
    if F9EngSwitch:istype("String") return 0.
    if not F9EngSwitch:hasfield("mode") return 0.
    local m is F9EngSwitch:getfield("mode"):tolower.
    if m:contains("all") return 9.
    if m:contains("three") return 3.
    if m:contains("center") return 1.
    return 0.
}

function F9ModeName {
    if F9EngSwitch:istype("String") return "-".
    if not F9EngSwitch:hasfield("mode") return "?".
    return F9EngSwitch:getfield("mode").
}

function F9ModeThrust {
    parameter n.
    if n = 9 return F9ThrAll.
    if n = 3 return F9Thr3.
    return F9Thr1.
}

function F9SetEngineMode {
    parameter want.
    if F9EngSwitch:istype("String") return false.
    local guard is 0.
    until F9EngineCount() = want or guard >= 3 {
        if not F9EngSwitch:hasevent("next engine mode") return false.
        F9EngSwitch:doevent("next engine mode").
        wait 0.3.
        set guard to guard + 1.
    }
    return F9EngineCount() = want.
}

set F9GridFins to list().
for p in F9ByModule("ModuleControlSurface") {
    if p:hasmodule("ModuleAnimateGeneric") F9GridFins:add(p).
}
if F9GridFins:length = 0 {
    for p in F9Find("Grid[ ._]Fin") { F9GridFins:add(p). }
    if F9GridFins:length > 0 F9Note("grid fins found by name, without ModuleDeployableAero").
}
if F9GridFins:length = 0 {
    if F9IsS1 set F9Ok to false.
    F9Note("grid fins NOT FOUND").
}

function F9DoEventLike {
    parameter pm.
    parameter frag.
    for e in pm:allevents {
        if e:contains(frag) {
            local nm is e.
            if nm:contains(")") set nm to nm:substring(nm:find(")") + 1, nm:length - nm:find(")") - 1).
            if nm:contains(",") set nm to nm:substring(0, nm:find(",")).
            set nm to nm:trim.
            if pm:hasevent(nm) {
                pm:doevent(nm).
                return true.
            }
        }
    }
    return false.
}

function F9PartDoEventLike {
    parameter prt.
    parameter frag.
    for mn in prt:modules {
        local pm is prt:getmodule(mn).
        if F9DoEventLike(pm, frag) return true.
    }
    return false.
}

function F9PartField {
    parameter prt.
    parameter fname.
    for mn in prt:modules {
        local pm is prt:getmodule(mn).
        if pm:hasfield(fname) return pm:getfield(fname).
    }
    return "?".
}

function F9GridFinsDeploy {
    parameter wantOpen is true.
    local n is 0.
    local frag is "retract".
    if wantOpen set frag to "extend".
    for p in F9GridFins {
        if F9PartDoEventLike(p, frag) set n to n + 1.
    }
    return n.
}

function F9GridFinsEvents {
    if F9GridFins:length = 0 return "no grid fins".
    local out is "".
    local prt is F9GridFins[0].
    for mn in prt:modules {
        for e in prt:getmodule(mn):allevents {
            if out:length > 0 set out to out + "; ".
            set out to out + e.
        }
    }
    if out:length = 0 return "no events".
    return out.
}

function F9MovableParts {
    local out is list().
    for p in F9ByModule("ModuleAnimateGeneric") {
        if F9GridFins:contains(p) { }
        else if F9Legs:contains(p) { }
        else out:add(p).
    }
    return out.
}

function F9PartEvents {
    parameter prt.
    local out is "".
    for mn in prt:modules {
        for e in prt:getmodule(mn):allevents {
            if out:length > 0 set out to out + "; ".
            set out to out + e.
        }
    }
    if out:length = 0 return "no events".
    return out.
}

function F9SetVesselLoadDist {
    parameter vsl.
    parameter d.

    if d = "default" {
        set vsl:loaddistance:flying:unload to 22500.
        set vsl:loaddistance:flying:load to 2250.
        wait 0.001.
        set vsl:loaddistance:flying:pack to 25000.
        set vsl:loaddistance:flying:unpack to 2000.
        wait 0.001.
        set vsl:loaddistance:suborbital:unload to 15000.
        set vsl:loaddistance:suborbital:load to 2250.
        wait 0.001.
        set vsl:loaddistance:suborbital:pack to 10000.
        set vsl:loaddistance:suborbital:unpack to 700.
        wait 0.001.
        set vsl:loaddistance:orbit:unload to 2500.
        set vsl:loaddistance:orbit:load to 2250.
        wait 0.001.
        set vsl:loaddistance:orbit:pack to 550.
        set vsl:loaddistance:orbit:unpack to 400.
        wait 0.001.
        return.
    }

    set vsl:loaddistance:flying:unload to d.
    set vsl:loaddistance:flying:load to d - 5000.
    wait 0.001.
    set vsl:loaddistance:flying:pack to d - 2500.
    set vsl:loaddistance:flying:unpack to d - 10000.
    wait 0.001.
    set vsl:loaddistance:suborbital:unload to d.
    set vsl:loaddistance:suborbital:load to d - 5000.
    wait 0.001.
    set vsl:loaddistance:suborbital:pack to d - 2500.
    set vsl:loaddistance:suborbital:unpack to d - 10000.
    wait 0.001.
    set vsl:loaddistance:orbit:unload to d.
    set vsl:loaddistance:orbit:load to d - 5000.
    wait 0.001.
    set vsl:loaddistance:orbit:pack to d - 2500.
    set vsl:loaddistance:orbit:unpack to d - 10000.
    wait 0.001.
    set vsl:loaddistance:prelaunch:unload to d.
    set vsl:loaddistance:prelaunch:load to d - 250.
    wait 0.001.
    set vsl:loaddistance:prelaunch:pack to d - 500.
    set vsl:loaddistance:prelaunch:unpack to d - 750.
    wait 0.001.
}

function F9SootParts {
    return F9ByModule("ModuleTundraSoot").
}

function F9SootOn {
    local n is 0.
    for p in F9SootParts() {
        local pm is p:getmodule("ModuleTundraSoot").
        if pm:hasfield("toggle soot") {
            pm:setfield("toggle soot", true).
            set n to n + 1.
        }
    }
    return n.
}

function F9SootEvents {
    local ps is F9SootParts().
    if ps:length = 0 return "no parts with ModuleTundraSoot".
    local out is "".
    local pm is ps[0]:getmodule("ModuleTundraSoot").
    for e in pm:allevents {
        if out:length > 0 set out to out + "; ".
        set out to out + e.
    }
    for f in pm:allfields {
        if out:length > 0 set out to out + "; ".
        set out to out + "[field] " + f.
    }
    if out:length = 0 return "no events, no fields".
    return out.
}

function F9GridFinsState {
    if F9GridFins:length = 0 return "no grid fins".
    return F9PartField(F9GridFins[0], "status").
}

set F9Legs to F9ByModule("ModuleWheelDeployment").
if F9Legs:length = 0 {
    set F9Legs to F9Find("FalconLeg").
    if F9Legs:length > 0 F9Note("legs found by name, without ModuleWheelDeployment").
}
if F9Legs:length = 0 {
    if F9IsS1 set F9Ok to false.
    F9Note("landing legs NOT FOUND").
}

function F9LegsDeploy {
    parameter wantOpen is true.
    gear on.
    if not wantOpen gear off.
    local n is 0.
    local frag is "retract".
    if wantOpen set frag to "extend".
    for p in F9Legs {
        if F9PartDoEventLike(p, frag) set n to n + 1.
    }
    return n.
}

function F9LegsDeployed {
    for p in F9Legs {
        if p:hasmodule("ModuleWheelDeployment") {
            local m is p:getmodule("ModuleWheelDeployment").
            if m:hasfield("state") {
                if m:getfield("state"):contains("Deployed") return true.
            }
        }
    }
    return false.
}

set F9ColdGas to F9Find("F9[._]CGT").
if F9ColdGas:length = 0 set F9ColdGas to F9Find("CGT").
if F9ColdGas:length = 0 F9Note("cold gas not found - turns will use reaction wheels").

set F9PadRetract to list("retract erector", "retract crew access arm").

set F9Erector to "false".
for p in ship:parts {
    for mn in p:modules {
        local pm is p:getmodule(mn).
        for want in F9PadRetract {
            if pm:hasevent(want) and F9Erector:istype("String") set F9Erector to p.
        }
    }
}
if F9Erector:istype("String") and F9IsS1 F9Note("nothing to retract before launch - no arm or walkway").

function F9HasClamp {
    for p in ship:parts {
        for mn in p:modules {
            if p:getmodule(mn):hasevent("release clamp") return true.
        }
    }
    return false.
}

function F9ReleaseClamp {
    local n is 0.
    for p in ship:parts {
        for mn in p:modules {
            local pm is p:getmodule(mn).
            if pm:hasevent("release clamp") {
                pm:doevent("release clamp").
                set n to n + 1.
            }
        }
    }
    return n.
}

function F9ErectorOpen {
    local n is 0.
    for p in ship:parts {
        for mn in p:modules {
            local pm is p:getmodule(mn).
            for want in F9PadRetract {
                if pm:hasevent(want) {
                    pm:doevent(want).
                    set n to n + 1.
                }
            }
        }
    }
    return n.
}

set F9Tank to "false".
for p in F9Find("F9[._]S1[._]Tank") { set F9Tank to p. break. }
if F9Tank:istype("String") {
    local best is 0.
    for p in ship:parts {
        for r in p:resources {
            if r:name = "LiquidFuel" and r:capacity > best {
                set best to r:capacity.
                set F9Tank to p.
            }
        }
    }
    if not F9Tank:istype("String") F9Note("tank identified by capacity, not by name").
}
if F9Tank:istype("String") {
    set F9Ok to false.
    F9Note("first stage tank NOT FOUND").
}

function F9FuelPct {
    if F9Tank:istype("String") return 0.
    local amt is 0.
    local cap is 0.
    for r in F9Tank:resources {
        if r:name = "LiquidFuel" {
            set amt to r:amount.
            set cap to r:capacity.
        }
    }
    if cap <= 0 return 0.
    return 100 * amt / cap.
}

set F9Interstage to list().
for p in F9Find("Interstage") { F9Interstage:add(p). }

set F9Isp to 300.
set F9MecoDvRtls to 1850.
set F9MecoDvSplash to 1000.
set F9MecoDvExp to 150.

set F9MecoDvAsds to 1300.

set F9AsdsFile to "0:/f9asds.json".

function F9GeoAlong {
    parameter g, az, d.
    local dd is d / ship:body:radius * constant:radtodeg.
    local gla is arcsin(sin(g:lat) * cos(dd) + cos(g:lat) * sin(dd) * cos(az)).
    local glo is g:lng + arctan2(sin(az) * sin(dd) * cos(g:lat),
                                 cos(dd) - sin(g:lat) * sin(gla)).
    return latlng(gla, glo).
}

function F9GeoArc {
    parameter g1, g2.
    local a is sin((g2:lat - g1:lat) / 2) ^ 2 +
               cos(g1:lat) * cos(g2:lat) * sin((g2:lng - g1:lng) / 2) ^ 2.
    return 2 * arcsin(sqrt(min(1, a))) * constant:degtorad * ship:body:radius.
}

function F9GeoBrg {
    parameter g1, g2.
    local dl is g2:lng - g1:lng.
    return mod(arctan2(sin(dl) * cos(g2:lat),
                       cos(g1:lat) * sin(g2:lat) - sin(g1:lat) * cos(g2:lat) * cos(dl)) + 360, 360).
}

set F9AsogFile to "0:/f9asog.json".

function F9AsdsRaw {
    if homeconnection:isconnected and exists(F9AsdsFile) return readjson(F9AsdsFile).
    return lexicon().
}

function F9AsdsRead {
    local a is F9AsdsRaw().
    for k in list("blat", "blng", "deck", "ready", "bt", "bv") {
        if a:haskey(k) a:remove(k).
    }
    if homeconnection:isconnected and exists(F9AsogFile) {
        local b is readjson(F9AsogFile).
        for k in b:keys { set a[k] to b[k]. }
    }
    return a.
}

set F9AsdsOkTol to 150.
set F9AsdsOkV to 2.
function F9AsdsOnSt {
    parameter a, off.
    if a:haskey("bv") and a["bv"] >= F9AsdsOkV return false.
    return off < F9AsdsOkTol.
}

function F9AsdsWrite {
    parameter keys.
    if not homeconnection:isconnected return false.
    local a is F9AsdsRaw().
    for k in keys:keys { set a[k] to keys[k]. }
    writejson(a, F9AsdsFile).
    return true.
}

function F9AsogWrite {
    parameter keys.
    if not homeconnection:isconnected return false.
    writejson(keys, F9AsogFile).
    return true.
}

function F9Stage1Parts {
    local out is list().
    if not F9Tank:istype("String") out:add(F9Tank).
    if not F9Octaweb:istype("String") out:add(F9Octaweb).
    for p in F9GridFins { out:add(p). }
    for p in F9Legs { out:add(p). }
    for p in F9ColdGas { out:add(p). }
    for p in F9Interstage { out:add(p). }
    return out.
}

function F9Stage1Mass {
    local mm is 0.
    for p in F9Stage1Parts() { set mm to mm + p:mass. }
    return mm.
}

function F9Stage1Dry {
    local mm is 0.
    for p in F9Stage1Parts() { set mm to mm + p:drymass. }
    return mm.
}

function F9DvLeft {
    local m0 is F9Stage1Mass().
    local m1 is F9Stage1Dry().
    if m1 <= 0 return 0.
    if m0 <= m1 return 0.
    return F9Isp * 9.80665 * ln(m0 / m1).
}

set F9Body to ship:body:name.
set F9BoosterName to "F9 B".
set F9SerialFile to "0:/f9serial.json".

function F9NextBooster {
    if not homeconnection:isconnected return F9BoosterName + "x" + round(time:seconds).
    local n is 1001.
    if exists(F9SerialFile) {
        local s is readjson(F9SerialFile).
        if s:haskey("next") set n to s["next"].
    }
    writejson(lexicon("next", n + 1), F9SerialFile).
    return F9BoosterName + n.
}
set F9Radius to ship:body:radius.
if F9Radius > 1600000 {
    set F9Scale to 1.6.
    set F9World to "RSS".
} else if F9Radius > 900000 {
    set F9Scale to 1.0.
    set F9World to "KSRSS".
} else {
    set F9Scale to 0.55.
    set F9World to "Stock".
}

set F9CfgFile to "0:/f9cfg.json".

function F9CfgDefault {
    return lexicon("ap", 125, "pe", 125, "incl", round(abs(ship:latitude), 1),
                   "az", 90, "mode", "rtls", "t0", 0, "count", 20, "lan", -1).
}

function F9CfgRead {
    local c is F9CfgDefault().
    if homeconnection:isconnected and exists(F9CfgFile) {
        local f is readjson(F9CfgFile).
        for k in f:keys { set c[k] to f[k]. }
    }
    return c.
}

function F9CfgWrite {
    parameter c.
    if homeconnection:isconnected writejson(c, F9CfgFile).
}

function F9LaunchSinAz {
    parameter incl.
    return max(-1, min(1, cos(incl) / cos(ship:latitude))).
}

function F9PlaneDelta {
    parameter incl.
    local ii is abs(incl).
    if ii < 0.01 or ii > 179.99 return -999.
    local ss is tan(ship:latitude) / tan(ii).
    if abs(ss) > 1 return -999.
    return arcsin(ss).
}

function F9SiteRa {
    return mod(body:rotationangle + ship:longitude + 720, 360).
}

function F9WindowSec {
    parameter incl, lan, asc.
    local dd is F9PlaneDelta(incl).
    if dd < -900 return -1.
    local th is lan + dd.
    if not asc set th to lan + 180 - dd.
    return mod(th - F9SiteRa() + 720, 360) / 360 * body:rotationperiod.
}

function F9WindowAz {
    parameter incl, insAlt, asc.
    local az is F9LaunchAz(incl, insAlt).
    if asc return az.
    return mod(180 - az + 720, 360).
}

function F9LaunchAz {
    parameter incl, insAlt.
    local azI is arcsin(F9LaunchSinAz(incl)).
    local vo is sqrt(body:mu / (body:radius + insAlt)).
    local vr is 2 * constant:pi * body:radius / body:rotationperiod * cos(ship:latitude).
    local az is arctan2(vo * sin(azI) - vr, vo * cos(azI)).
    if az < 0 set az to az + 360.
    return az.
}

function F9Report {
    clearscreen.
    print "=== Falcon 9 - hardware check ===".
    print " ".
    print "World:      " + F9World + "  (radius " + round(F9Radius/1000) + " km, Scale " + F9Scale + ")".
    print "Octaweb:    " + (choose F9Octaweb:name if not F9Octaweb:istype("String") else "NONE").
    print "  modes:    " + (choose "yes" if not F9EngSwitch:istype("String") else "NO SWITCH").
    print "  mode:     " + F9EngineCount() + " eng. [" + F9ModeName() + "]".
    print "  thrust:   rated " + F9ModeThrust(F9EngineCount()) +
          " kN, live " + round(ship:maxthrust, 1) + " kN".
    print "Grid fins:  " + F9GridFins:length + " pcs".
    print "Legs:       " + F9Legs:length + " pcs" + (choose "  (DEPLOYED)" if F9LegsDeployed() else "").
    print "Cold gas:   " + F9ColdGas:length + " pcs".
    print "Soot:       " + F9SootParts():length + " parts".
    print "Tank:       " + (choose F9Tank:name if not F9Tank:istype("String") else "NONE") +
          "   fuel " + round(F9FuelPct(), 1) + "%".
    print "Mass:       " + round(ship:mass, 2) + " t".
    print " ".
    if F9Notes:length > 0 {
        print "Notes:".
        for n in F9Notes { print "  - " + n. }
        print " ".
    }
    if F9Ok print "HARDWARE FULLY IDENTIFIED".
    else print "IDENTIFICATION INCOMPLETE - see notes above".
}
