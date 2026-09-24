
run once f9lib.

set F9AsogTol to 40.
set F9AsogSlow to 300.
set F9AsogDeck to -1.
set F9AsogThr to 1.
set F9AsogPeriod to 5.

clearscreen.
print "=== ASDS: " + ship:name + " ===".

set F9AsogDrive to ship:availablethrust > 0.
if not F9AsogDrive {
    print "no thrust - report mode: only position and deck are reported.".
}

function F9AsogTop {
    return max(0, ship:body:altitudeof(ship:bounds:furthestcorner(up:vector))).
}

function F9AsogDeckH {
    if F9AsogDeck >= 0 return F9AsogDeck.
    return F9AsogTop().
}

set F9AsogHas to false.

function F9AsogTarget {
    local a is F9AsdsRead().
    if a:haskey("lat") and a:haskey("lng") {
        set F9AsogHas to true.
        return latlng(a["lat"], a["lng"]).
    }
    set F9AsogHas to false.
    return ship:geoposition.
}

function F9AsogDist {
    parameter g.
    return (g:position - ship:position):mag.
}

function F9AsogBrg {
    parameter g.
    local dir is vxcl(up:vector, g:position - ship:position).
    if dir:mag < 0.1 return ship:heading.
    local nv is vxcl(up:vector, ship:north:vector):normalized.
    local ev is vcrs(up:vector, nv):normalized.
    return mod(arctan2(vdot(dir, ev), vdot(dir, nv)) + 360, 360).
}

function F9AsogThrCmd {
    if not F9AsogHas return 0.
    local dist is F9AsogDist(F9AsogTgt).
    if dist < F9AsogTol return 0.
    return min(F9AsogThr, max(0.05, dist / F9AsogSlow)).
}

function F9AsogReport {
    parameter ok.
    local g is ship:geoposition.
    if not F9AsogWrite(lexicon(
        "blat", g:lat, "blng", g:lng,
        "deck", round(F9AsogDeckH(), 2),
        "ready", ok, "bt", round(time:seconds),
        "bv", round(ship:groundspeed, 1))) {
        print "NO ARCHIVE CONNECTION - the stage cannot see me.".
    }
}

set F9AsogOnTr to false.
function F9AsogShow {
    parameter g.
    if addons:tr:available and kuniverse:activevessel = ship {
        addons:tr:settarget(g).
        return true.
    }
    return false.
}

function F9AsogSay {
    if not F9AsogHas {
        print "NO TARGET. Waiting for the booster to publish the point".
        print "  (ASDS mode in the menu, file " + F9AsdsFile + ").".
        return.
    }
    print "TARGET: " + round(F9AsogTgt:lat, 5) + " / " + round(F9AsogTgt:lng, 5).
    print "  from barge " + round(F9AsogDist(F9AsogTgt) / 1000, 2) +
          " km, bearing " + round(F9AsogBrg(F9AsogTgt)) + " deg".
    print "  barge now " + round(ship:geoposition:lat, 5) + " / " +
          round(ship:geoposition:lng, 5).
}

set F9AsogTgt to F9AsogTarget().
F9AsogSay().
if F9AsogHas and not F9AsogShow(F9AsogTgt) {
    print "Trajectories unavailable - target shown in terminal only.".
}
print "deck above water: " + round(F9AsogDeckH(), 2) + " m" +
      (choose " (SET MANUALLY)" if F9AsogDeck >= 0 else " (FROM BOUNDS, CHECK IT!)").
print "  vessel top " + round(F9AsogTop(), 2) + " m, hull " +
      round(ship:altitude, 2) + " m above water".

sas off.
if F9AsogDrive {
    lock steering to heading(F9AsogBrg(F9AsogTgt), 0).
    lock throttle to F9AsogThrCmd().
}

set F9AsogNext to 0.
set F9AsogWas to false.
until false {
    set F9AsogWasHas to F9AsogHas.
    set F9AsogNew to F9AsogTarget().
    if F9AsogHas <> F9AsogWasHas or
       (F9AsogHas and (F9AsogNew:position - F9AsogTgt:position):mag > 10) {
        set F9AsogTgt to F9AsogNew.
        set F9AsogOnTr to false.
        F9AsogSay().
    }
    if kuniverse:activevessel <> ship set F9AsogOnTr to false.
    else if F9AsogHas and not F9AsogOnTr set F9AsogOnTr to F9AsogShow(F9AsogTgt).
    set F9AsogD to F9AsogDist(F9AsogTgt).
    local okTol is F9AsdsOkTol.
    if F9AsogWas set okTol to F9AsdsOkTol * 1.5.
    set F9AsogOk to F9AsogHas and F9AsogD < okTol and ship:groundspeed < F9AsdsOkV.

    if F9AsogOk <> F9AsogWas {
        if F9AsogOk print "ON STATION, from point " + round(F9AsogD) + " m - the stage aims at the barge.".
        else if F9AsogHas print "NOT ON STATION, to point " + round(F9AsogD) + " m.".
        set F9AsogWas to F9AsogOk.
    }

    if time:seconds > F9AsogNext {
        F9AsogReport(F9AsogOk).
        set F9AsogNext to time:seconds + F9AsogPeriod.
        if F9AsogHas {
            print "d " + round(F9AsogD, 1) + " m, bearing " +
                  round(F9AsogBrg(F9AsogTgt)) + ", speed " +
                  round(ship:groundspeed, 1) + " m/s, " +
                  (choose "ON STATION" if F9AsogOk else "NOT ON STATION").
        } else {
            print "no target, holding at " + round(ship:geoposition:lat, 5) + " / " +
                  round(ship:geoposition:lng, 5) + ", deck " +
                  round(F9AsogDeckH(), 2) + " m".
        }
    }

    wait 0.5.
}
