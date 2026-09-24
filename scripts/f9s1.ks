
run once f9lib.

set F9Azimuth to 90.

set F9Atm to body:atm:height.
set F9ClearAlt to 200 * F9Scale.
set F9TurnStart to F9Atm * 0.03.
set F9TurnEnd to F9Atm * 0.50.
set F9TurnFinal to 25.
set F9TurnPow to 1.10.

set F9Roll to 0.
set steeringmanager:rollcontrolanglerange to 5.

set steeringmanager:pitchts to 4.
set steeringmanager:yawts to 4.
set steeringmanager:rollts to 5.
set steeringmanager:maxstoppingtime to 4.



set F9MecoAlt to 40000.

set F9SepWait to 3.
set F9HoldDown to 2.
set F9Countdown to 20.
set F9Mission to "Falcon 9 Launch Test".
set F9TelEvery to 0.1.
set F9TelEveryLand to 0.25.

set F9SepCoast to 10.
set F9SepCoastRtls to 3.

set F9S2LoadDist to 1650000.
set F9S2DistEvery to 5.
set F9S2Name to "".
set F9S2Ves to 0.
set F9NextS2Dist to 0.

set F9EntryAlt to F9Atm * 0.50.
set F9SimIgnH to 0.
set F9AtmR to 8.314462.
set F9EtaQT to 0.
set F9EtaQVs to 0.
set F9EtaQVv to 0.
set F9EtaQA to 0.
set F9EtaQAv to 0.
set F9S2SecoEta to -1.
set F9TelEtaStr to "".
set F9TelEtaT to 0.
set F9TelM2 to 0.
set F9S2ThrKn to 580.
set F9S2IspV to 348.
set F9S2DvNeed to 3400.
set F9S2BurnK to 1.8.
set F9S2IgnDelay to 5.
set F9TelFlipEst to 22.
set F9TelThrAvg to 0.85.

set F9CoastFlipErr to 5.
set F9RcsOnErr to 8.
set F9RcsOffErr to 2.
set F9RcsOffRate to 0.5.
set F9RcsGate to false.
set F9LastVesselChange to 0.
set F9S2Orbit to false.

set F9Mode to "rtls".

set F9MecoDv to F9MecoDvSplash.
if F9Mode = "rtls" set F9MecoDv to F9MecoDvRtls.

set F9MecoAltRtls to F9MecoAlt.
set F9Expend to false.
function F9S1ApplyCfg {
    parameter c.
    set F9Azimuth to c["az"].
    set F9Mode to c["mode"].
    set F9Expend to F9Mode = "exp".
    set F9MecoAlt to F9MecoAltRtls.
    set F9MecoDv to F9MecoDvRtls.
    if F9Mode = "splashdown" {
        set F9MecoDv to F9MecoDvSplash.
        set F9MecoAlt to F9Atm * 0.8.
    }
    if F9Mode = "asds" {
        set F9MecoDv to F9MecoDvAsds.
        set F9MecoAlt to F9Atm * 0.8.
    }
    if F9Expend {
        set F9Mode to "splashdown".
        set F9MecoDv to F9MecoDvExp.
        set F9MecoAlt to F9Atm * 2.
    }
}
F9S1ApplyCfg(F9CfgRead()).

function F9Guided {
    return F9Mode = "rtls" or F9Mode = "asds".
}

function F9PadAbort {
    lock throttle to 0.
    set ship:control:pilotmainthrottle to 0.
    unlock steering.
    unlock throttle.
    print "LAUNCH ABORTED - restarting".
    hudtext("F9: LAUNCH ABORTED", 5, 2, 24, yellow, false).
    wait 1.
    reboot.
}


set F9QOn to 0.10.
set F9MaxQ to 0.12.
set F9QThrottle to 0.72.

set F9MaxG to 3.2.

function F9GLocal0 {
    return body:mu / (body:radius + ship:altitude) ^ 2.
}

clearscreen.
F9Report().

print "PID: pitch/yaw TS " + steeringmanager:pitchts +
      "/" + steeringmanager:yawts + ", roll TS " + steeringmanager:rollts +
      ", roll window " + steeringmanager:rollcontrolanglerange.

if addons:tr:available {
    print "impact prediction: Trajectories".
} else {
    print "impact prediction: built-in ballistics (no Trajectories)".
}
print " ".

if not core:part:name:contains("Interstage") {
    print "THIS IS NOT THE FIRST STAGE COMPUTER (" + core:part:name + ").".
    print "f9s2 should run here.".
    wait until false.
}

if not F9Ok {
    print "HARDWARE NOT FULLY IDENTIFIED - launch aborted.".
    print "See the notes above, fix detection in f9lib.".
    wait until false.
}

set F9OnPad to (ship:status = "PRELAUNCH").

if F9OnPad {
    if not F9SetEngineMode(9) {
        print "COULD NOT SET All Engines - launch aborted.".
        wait until false.
    }
}
print "engine mode: " + F9ModeName().

set F9PadOffAlong to 20.
set F9PadOffSide to 0.
set F9PadOffLand to F9PadOffAlong.

set F9PadLat to 28.300833.
set F9PadLng to -80.344167.

set F9AsdsOffAlong to 220.

set F9AsdsDeck to 0.

set F9AsdsDeckFix to 2.1.

set F9AsdsStale to 120.
set F9AsdsDefDown to 193000 * F9Scale.
set F9AsdsAzTol to 2.
set F9AsdsKmT to 7.0.
set F9AsdsMdvOld to 1150.
set F9AsdsKmDv to 70.

set F9AsdsRefLat to 28.53336.
set F9AsdsRefLng to -72.36060.
set F9AsdsRefAz to 88.1525.
set F9AsdsRefMp to 1074.38.
set F9AsdsRefDv to 1300.
set F9AsdsGlideMargin to 1500.

function F9AsdsPredict {
    local a is F9AsdsRead().
    local pad is ship:geoposition.
    local mp is ship:mass.
    if abs(F9Azimuth - F9AsdsRefAz) < F9AsdsAzTol {
        local rf is latlng(F9AsdsRefLat, F9AsdsRefLng).
        local rb is F9GeoBrg(pad, rf) - F9AsdsRefAz.
        if rb > 180 set rb to rb - 360.
        if rb < -180 set rb to rb + 360.
        local rn is F9GeoArc(pad, rf).
        local dm is F9AsdsKmT * 1000 * (F9AsdsRefMp - mp).
        local dv is -F9AsdsKmDv * (F9MecoDv - F9AsdsRefDv).
        print "barge point from reference: " + round(rn / 1000, 1) + " km, mass " + round(mp, 2) +
              " t (" + round(dm / 1000, 1) + " km), MECO reserve " + round(F9MecoDv) + " (" +
              round(dv / 1000, 1) + " km), glide +" + round(F9AsdsGlideMargin / 1000, 1) + " km.".
        return F9GeoAlong(pad, F9Azimuth + rb, rn + dm + dv + F9AsdsGlideMargin).
    }
    local recs is list().
    local nNat is 0.
    if a:haskey("flights") {
        for f in a["flights"] {
            if f:haskey("mode") and f["mode"] = F9Mode and f:haskey("lat") and f:haskey("lng") and f:haskey("az") {
                recs:add(f).
                if f:haskey("nlat") set nNat to nNat + 1.
            }
        }
    }
    local pr is lexicon().
    if a:haskey("pred") {
        local p is a["pred"].
        if p:haskey("mode") and p["mode"] = F9Mode and p:haskey("lat") and p:haskey("az") set pr to p.
    }
    if recs:length = 0 and pr:length > 0 {
        print "no landings yet, using last flight's Trajectories prediction.".
        recs:add(pr).
    }
    if recs:length = 0 {
        print "no history, using " + round(F9AsdsDefDown / 1000) + " km downrange.".
        return F9GeoAlong(pad, F9Azimuth, F9AsdsDefDown).
    }

    local bestAz is 999.
    local dBrg is 0.
    local bestD is 0.
    local bestM is 0.
    local bestT is -1.
    local bestDv is 0.
    for f in recs {
        local useIt is nNat = 0 or f:haskey("nlat").
        if useIt {
            local td is latlng(f["lat"], f["lng"]).
            if f:haskey("nlat") set td to latlng(f["nlat"], f["nlng"]).
            local db is F9GeoBrg(pad, td) - f["az"].
            if db > 180 set db to db - 360.
            if db < -180 set db to db + 360.
            local daz is abs(f["az"] - F9Azimuth).
            local ft is 0.
            if f:haskey("t") set ft to f["t"].
            if daz < bestAz - 0.5 or (daz <= bestAz + 0.5 and ft > bestT) {
                set bestAz to daz.
                set bestT to ft.
                set dBrg to db.
                set bestD to F9GeoArc(pad, td).
                set bestM to 0.
                if f:haskey("mp") set bestM to f["mp"].
                set bestDv to F9AsdsMdvOld.
                if f:haskey("mdv") set bestDv to f["mdv"].
            }
        }
    }
    local src is "touchdown points".
    if nNat > 0 set src to "natural point after entry".

    if nNat = 0 and pr:length > 0 and abs(pr["az"] - F9Azimuth) < F9AsdsAzTol {
        local pb is F9GeoBrg(pad, latlng(pr["lat"], pr["lng"])) - pr["az"].
        if pb > 180 set pb to pb - 360.
        if pb < -180 set pb to pb + 360.
        print "drift from landings " + round(dBrg, 2) + " deg - they followed the barge, ignoring.".
        set dBrg to pb.
        set src to "range from touchdowns, drift from Trajectories".
    }

    local dn is bestD.
    if abs(bestDv - F9MecoDv) > 5 {
        set dn to dn - F9AsdsKmDv * (F9MecoDv - bestDv).
        print "MECO reserve " + round(F9MecoDv) + " vs " + round(bestDv) + " in record: range " +
              round(-F9AsdsKmDv * (F9MecoDv - bestDv) / 1000, 1) + " km.".
    }
    if bestM > 0 and abs(bestM - mp) > 0.2 {
        set dn to dn + F9AsdsKmT * 1000 * (bestM - mp).
        print "pad mass " + round(mp, 2) + " t vs " + round(bestM, 2) + " t.".
    }
    print "barge point: " + src + ", range " + round(dn / 1000, 1) + " km, drift " +
          round(dBrg, 2) + " deg" +
          (choose " - HEADING FAR OFF, drift may differ" if bestAz > 10 else "") + ".".
    return F9GeoAlong(pad, F9Azimuth + dBrg, dn).
}

function F9AsdsPredPub {
    if F9Mode <> "asds" or not addons:tr:available return.
    if not addons:tr:hasimpact return.
    local ip is addons:tr:impactpos.
    local dn is round((ip:position - latlng(F9PadLat, F9PadLng):position):mag).
    F9AsdsWrite(lexicon("pred", lexicon(
        "lat", ip:lat, "lng", ip:lng, "az", F9Azimuth, "down", dn,
        "m0", round(F9M0, 2), "mdv", F9MecoDv, "mode", F9Mode, "t", round(time:seconds)))).
    local off is (ip:position - F9Pad:position):mag.
    print "  impact prediction " + round(ip:lat, 4) + " / " + round(ip:lng, 4) +
          ", from barge " + round(off / 1000, 1) + " km (recorded)".
    if off > 2000 {
        print "  BARGE TOO FAR - deck landing not possible.".
        print "  the next launch on this heading will use this point.".
    }
}

function F9AsdsStatus {
    local a is F9AsdsRead().
    if not (a:haskey("lat") and a:haskey("lng")) {
        print "BARGE: point not sent - " + F9AsdsFile + " is empty.".
        return false.
    }
    if not (a:haskey("blat") and a:haskey("blng")) {
        print "BARGE: point sent, barge silent - run f9asog.".
        return false.
    }
    local tgt is latlng(a["lat"], a["lng"]).
    local pos is latlng(a["blat"], a["blng"]).
    local off is (tgt:position - pos:position):mag.
    local age is 9999.
    if a:haskey("bt") set age to time:seconds - a["bt"].
    local rd is F9AsdsOnSt(a, off).
    local bv is "".
    if a:haskey("bv") and not rd set bv to ", speed " + round(a["bv"], 1) + " m/s".
    print "BARGE: " + (choose "ON STATION, from point " if rd else "NOT ON STATION, to point ") +
          round(off) + " m" + bv + ", deck " + round(F9AsdsDeck, 1) +
          " m, data age " + round(age) + " s.".
    if age < -5 print "  report written before a revert - barge position may differ.".
    else if age > F9AsdsStale print "  DATA STALE - barge not responding, is f9asog running?".
    if not rd print "  BARGE NOT ON STATION YET - too early to launch.".
    return rd and age <= F9AsdsStale.
}

function F9AsdsRefresh {
    if F9Mode <> "asds" return false.
    local a is F9AsdsRead().
    if not (a:haskey("blat") and a:haskey("blng")) return false.
    set F9Pad to latlng(a["blat"], a["blng"]).
    if F9AsdsDeckFix > 0 { set F9AsdsDeck to F9AsdsDeckFix. }
    else if a:haskey("deck") { set F9AsdsDeck to a["deck"]. }
    return true.
}

function F9AsdsSetup {
    if F9Mode <> "asds" or not F9OnPad return.
    set F9PadOffAlong to 0.
    set F9MPad to ship:mass.
    set F9Pad to F9AsdsPredict().
    if F9AsdsWrite(lexicon("lat", F9Pad:lat, "lng", F9Pad:lng,
                           "az", F9Azimuth, "t", time:seconds)) {
        print "point sent to barge " + round(F9Pad:lat, 4) + " / " +
              round(F9Pad:lng, 4) + " (" +
              round(F9ToPadRaw():mag / 1000, 1) + " km) - run f9asog.".
    } else {
        print "NO ARCHIVE CONNECTION - the barge will not get the point!".
    }
    writejson(F9Pad, "1:/f9pad.json").
}

set F9MPad to 0.
if F9Mode = "asds" {
    if F9OnPad {
        F9AsdsSetup().
    } else {
        local a is F9AsdsRead().
        if a:haskey("lat") and a:haskey("lng") {
            set F9Pad to latlng(a["lat"], a["lng"]).
        } else {
            set F9Mode to "splashdown".
            print "NO BARGE POINT (" + F9AsdsFile + ") - going for splashdown.".
        }
    }
    if F9Mode = "asds" {
        set F9PadOffAlong to 0.
        F9AsdsRefresh().
        F9AsdsStatus().
        if addons:tr:available and kuniverse:activevessel = ship addons:tr:settarget(F9Pad).
    }
}

function F9PadPick {
if F9Mode <> "asds" {
    set F9AsdsDeck to 0.
    set F9PadOffAlong to F9PadOffLand.
}
set F9PadFrom to "".
if F9Mode = "asds" {
    set F9PadFrom to "barge".
} else if F9PadLat <> 0 {
    set F9Pad to latlng(F9PadLat, F9PadLng).
    if F9OnPad writejson(F9Pad, "1:/f9pad.json").
    set F9PadFrom to "LZ from constants".
} else if F9OnPad {
    set F9Pad to ship:geoposition.
    writejson(F9Pad, "1:/f9pad.json").
    set F9PadFrom to "pad position".
} else if exists("1:/f9pad.json") {
    set F9Pad to readjson("1:/f9pad.json").
    set F9PadFrom to "FILE f9pad.json".
} else {
    set F9Pad to ship:geoposition.
    set F9PadFrom to "STRAIGHT DOWN - POINT UNKNOWN".
}
print "return point: " + round(F9Pad:lat, 4) + " / " + round(F9Pad:lng, 4) +
      " (" + round(F9ToPadRaw():mag / 1000, 1) + " km)".
print "  mode " + F9Mode + ", point source: " + F9PadFrom.
if F9Mode <> "asds" and F9PadLat <> 0 {
    local dlz is latlng(F9PadLat, F9PadLng):position:mag.
    if dlz > 1000 print "  WARNING: distance to LZ from here " +
        round(dlz / 1000, 1) + " km".
}
if F9PadOffAlong <> 0 or F9PadOffSide <> 0 {
    print "  landing point offset: along " + F9PadOffAlong +
          " m, side " + F9PadOffSide + " m".
}
if F9Guided() and addons:tr:available and kuniverse:activevessel = ship addons:tr:settarget(F9Pad).
}
F9PadPick().

set F9EvFile to "1:/f9ev.json".
set F9M0 to ship:mass.
set F9NatGeo to 0.
set F9Ev to lexicon("t0", -1, "maxq", -1, "meco", -1, "sep", -1,
                    "bb", -1, "entry", -1, "lburn", -1, "land", -1, "seco", -1).
if F9OnPad {
    if exists(F9EvFile) deletepath(F9EvFile).
} else if exists(F9EvFile) {
    set F9EvRead to readjson(F9EvFile).
    for k in F9Ev:keys {
        if F9EvRead:haskey(k) set F9Ev[k] to F9EvRead[k].
    }
}
set F9T0 to F9Ev["t0"].
if not F9OnPad and F9T0 <= 0 set F9T0 to time:seconds - missiontime.
set F9Phase to "pad".
if not F9OnPad set F9Phase to "coast".

function F9EvSave {
    if core:volume:freespace > 1000 writejson(F9Ev, F9EvFile).
}

function F9TelEvBuild {
    set F9TelEvStr to ",""evmaxq"":" + F9Ev["maxq"] + ",""evmeco"":" + F9Ev["meco"] +
        ",""evsep"":" + F9Ev["sep"] + ",""evbb"":" + F9Ev["bb"] +
        ",""eventry"":" + F9Ev["entry"] + ",""evlburn"":" + F9Ev["lburn"] +
        ",""evland"":" + F9Ev["land"] + ",""evseco"":" + F9Ev["seco"] +
        ",""mission"":""" + F9Mission + """}".
}

function F9Mark {
    parameter evKey, evAt is -1.
    if F9Ev[evKey] > 0 return 0.
    if evAt < 0 set evAt to time:seconds - F9T0.
    set F9Ev[evKey] to round(max(0.1, evAt), 1).
    F9EvSave().
    F9TelEvBuild().
    return 0.
}

function F9TelFindS2 {
    if F9S2Ves:istype("Vessel") return F9S2Ves.
    local best is 0.
    local bestD is 60000.
    list targets in F9TelList.
    for ves in F9TelList {
        if F9S2Name <> "" {
            if ves:name = F9S2Name return ves.
        } else if ves:distance < bestD {
            set bestD to ves:distance.
            set best to ves.
        }
    }
    return best.
}

function F9TelEta {
    local now is time:seconds.
    local met is -F9Countdown.
    if F9T0 > 0 set met to now - F9T0.
    local m0 is max(0, met).
    local md is F9Mode.
    if F9Expend set md to "exp".
    local eMaxq is F9Ev["maxq"].
    local eMeco is F9Ev["meco"]. local eSep is F9Ev["sep"].
    local eBb is -1. local eEntry is -1. local eLb is -1. local eLand is -1.
    local eSeco is F9Ev["seco"].
    local ve is F9Isp * 9.80665.
    local vv is ship:verticalspeed.
    local gg is body:mu / (body:radius + ship:altitude) ^ 2.

    if eMaxq < 0 and F9Phase = "ascent" {
        local vsNow is ship:velocity:surface:mag.
        local dtq is now - F9EtaQT.
        if F9EtaQT > 0 and dtq > 0.5 and dtq < 3 {
            set F9EtaQA to F9EtaQA + ((vsNow - F9EtaQVs) / dtq - F9EtaQA) * 0.5.
            set F9EtaQAv to F9EtaQAv + ((vv - F9EtaQVv) / dtq - F9EtaQAv) * 0.5.
        }
        set F9EtaQT to now.
        set F9EtaQVs to vsNow.
        set F9EtaQVv to vv.
        if vsNow > 20 and F9EtaQA > 0 {
            local hq is ship:altitude.
            local vq is vsNow.
            local wq is vv.
            local qBest is ship:q.
            local tBest is 0.
            local tq is 0.
            until tq >= 150 {
                set tq to tq + 2.
                set vq to vq + 2 * F9EtaQA.
                set wq to min(vq, wq + 2 * F9EtaQAv).
                set hq to hq + 2 * wq.
                local qq is 0.5 * F9AtmRho(hq) * vq * vq / 101325.
                if qq > qBest { set qBest to qq. set tBest to tq. }
                else if tq > tBest + 6 break.
            }
            set eMaxq to m0 + tBest.
        }
    }

    if eMeco < 0 {
        local thr is 0.
        local pos is 0.
        for eng in ship:engines {
            if not eng:name:contains("S2") {
                set thr to thr + eng:thrust.
                set pos to pos + eng:possiblethrust.
            }
        }
        if thr < 1 set thr to pos * F9TelThrAvg.
        if thr > 1 {
            local mM is F9Stage1Dry() * constant:e ^ (F9MecoDv / ve).
            local tM is max(0, F9Stage1Mass() - mM) * ve / thr.
            if vv > 50 set tM to min(tM, max(0, F9MecoAlt - ship:altitude) / vv).
            set eMeco to m0 + tM.
        }
    }
    if eSep < 0 and eMeco > 0 set eSep to eMeco + F9SepWait.

    if eSeco < 0 {
        if F9S2SecoEta > 0 set eSeco to F9S2SecoEta.
        else if eSep > 0 {
            local m2 is F9TelM2.
            if F9Ev["sep"] < 0 {
                set m2 to ship:mass - F9Stage1Mass().
                set F9TelM2 to m2.
            } else if F9S2Name <> "" and F9S2Ves:istype("Vessel") and F9S2Ves:loaded {
                set m2 to F9S2Ves:mass.
            }
            if m2 > 0 {
                local ve2 is F9S2IspV * 9.80665.
                set eSeco to eSep + F9S2IgnDelay + F9S2BurnK *
                    m2 * ve2 / F9S2ThrKn * (1 - constant:e ^ (-F9S2DvNeed / ve2)).
            }
        }
    }

    if md = "rtls" {
        set eBb to F9Ev["bb"].
        if eBb < 0 and eSep > 0
            set eBb to max(m0 + 1, eSep + 6 + F9SepCoastRtls + F9TelFlipEst).
    }

    if md <> "exp" {
        set eEntry to F9Ev["entry"].
        if eEntry < 0 and F9Ev["sep"] > 0 {
            local dhE is ship:altitude - F9EntryAlt.
            if dhE > 0 set eEntry to met + (vv + sqrt(vv * vv + 2 * gg * dhE)) / gg.
        }
        set eLb to F9Ev["lburn"].
        if eLb < 0 and F9Ev["entry"] > 0 and F9SimIgnH > 0 {
            local hh is F9H().
            if hh > F9SimIgnH set eLb to met + (hh - F9SimIgnH) / max(50, -vv).
        }
        set eLand to F9Ev["land"].
        if eLand < 0 and F9Ev["lburn"] > 0 {
            local hl is max(0, F9H()).
            local dn is max(1, -vv).
            set eLand to met + (choose 2 * hl / dn if dn > 10 else hl / dn).
        }
    }

    set F9TelEtaStr to ",""mode"":""" + md + """" +
        ",""etamaxq"":" + round(eMaxq, 1) +
        ",""etameco"":" + round(eMeco, 1) + ",""etasep"":" + round(eSep, 1) +
        ",""etabb"":" + round(eBb, 1) + ",""etaseco"":" + round(eSeco, 1) +
        ",""etaentry"":" + round(eEntry, 1) + ",""etalburn"":" + round(eLb, 1) +
        ",""etaland"":" + round(eLand, 1).
    return 0.
}

function F9Tel {
    local now is time:seconds.
    if now > F9TelEtaT {
        set F9TelEtaT to now + 1.
        F9TelEta().
    }
    local dt is now - F9TelT.
    if dt > 0.015 {
        if dt < 1 {
            local acc is (ship:velocity:orbit - F9TelV) * (1 / dt) +
                up:vector * (body:mu / (body:radius + ship:altitude) ^ 2).
            local gi is acc:mag / 9.80665.
            if gi < 15 set F9TelG to F9TelG + (gi - F9TelG) * 0.35.
        }
        set F9TelV to ship:velocity:orbit.
        set F9TelT to now.
    }

    if F9Phase = "ascent" and F9Ev["maxq"] < 0 {
        if ship:q > F9TelQPeak {
            set F9TelQPeak to ship:q.
            set F9TelQPeakT to now.
        } else if F9TelQPeak > 0.05 and ship:q < F9TelQPeak * 0.9 {
            F9Mark("maxq", F9TelQPeakT - F9T0).
            print "  Max Q " + round(F9TelQPeak * 101.325, 1) + " kPa (" + round(F9TelQPeak, 3) + " atm)".
        }
    }

    if now > F9TelFuelT {
        set F9TelFuelT to now + 1.
        set F9TelFuel to round(F9FuelPct(), 1).
    }

    local thr is 0.
    for eng in ship:engines { set thr to thr + eng:thrust. }
    local mask is "000000000".
    if thr > 1 {
        local n is F9EngineCount().
        if n >= 9 { set mask to "111111111". }
        else if n = 3 { set mask to "110001000". }
        else if n >= 1 { set mask to "100000000". }
    }

    local s2 is "".
    if F9Ev["sep"] > 0 or not F9OnPad {
        if now > F9TelS2T and not F9S2Orbit {
            set F9TelS2T to now + 2.
            set F9TelS2 to F9TelFindS2().
        }
        local s2spd is -1.
        local s2alt is -1.
        if F9TelS2:istype("Vessel") {
            if not F9TelS2:isdead {
                set s2spd to round(F9TelS2:velocity:surface:mag, 1).
                set s2alt to round(F9TelS2:altitude).
            }
        }
        set s2 to ",""sep"":true,""s2orb"":" + (choose "true" if F9S2Orbit else "false") +
            ",""s2spd"":" + s2spd + ",""s2alt"":" + s2alt.
    }

    local met is -F9Countdown.
    if F9T0 > 0 set met to now - F9T0.
    set F9TelTxt to "{""veh"":""f9"",""t"":" + round(now, 2) +
        ",""met"":" + round(met, 1) + ",""phase"":""" + F9Phase +
        """,""alt"":" + round(ship:altitude) +
        ",""spd"":" + round(ship:velocity:surface:mag, 1) +
        ",""vs"":" + round(ship:verticalspeed, 1) +
        ",""g"":" + round(F9TelG, 2) +
        ",""engmask"":""" + mask + """,""lfpct"":" + F9TelFuel +
        s2 + F9TelEtaStr + F9TelEvStr.
    if homeconnection:isconnected {
        local fh is open("0:/telemetry.json").
        if fh:istype("Boolean") set fh to create("0:/telemetry.json").
        fh:clear().
        fh:write(F9TelTxt).
    }
    return 0.
}

set F9TelOn to true.
set F9TelNext to 0.
set F9TelT to time:seconds.
set F9TelV to ship:velocity:orbit.
set F9TelG to 1.
set F9TelQPeak to 0.
set F9TelQPeakT to 0.
set F9TelFuel to 0.
set F9TelFuelT to 0.
set F9TelS2 to 0.
set F9TelS2T to 0.
F9TelEvBuild().
when time:seconds >= F9TelNext then {
    if F9Phase = "landing" set F9TelNext to time:seconds + F9TelEveryLand.
    else set F9TelNext to time:seconds + F9TelEvery.
    if F9TelOn F9Tel().
    return F9TelOn.
}

if F9OnPad {

    set F9S2Cpu to "".
    list processors in F9Cpus.
    for c in F9Cpus {
        if c:bootfilename:contains("f9s2") set F9S2Cpu to c.
    }

    if F9S2Cpu:istype("String") {
        set F9Panel to gui(240).
        set F9Panel:x to 300.
        F9Panel:addlabel("<b>Falcon 9 - first stage</b>").
        F9Panel:addlabel("engine mode: " + F9ModeName()).
        set F9GoBtn to F9Panel:addbutton("LAUNCH").
        F9Panel:show.

        print " ".
        print "waiting for LAUNCH on the panel...".
        until F9GoBtn:pressed { wait 0.1. }
        F9Panel:hide.
        set F9T0 to time:seconds + max(7, F9Countdown).
    } else {
        print " ".
        print "waiting for LAUNCH from the second stage menu...".
        set F9T0 to 0.
        until F9T0 > 0 {
            if not core:messages:empty {
                local m is core:messages:pop():content.
                if m:istype("Lexicon") and m:haskey("cmd") and m["cmd"] = "go" {
                    F9S1ApplyCfg(m["cfg"]).
                    F9AsdsSetup().
                    F9PadPick().
                    set F9T0 to max(time:seconds + 7, m["t0"]).
                }
                if m:istype("Lexicon") and m:haskey("cmd") and m["cmd"] = "asds" {
                    F9S1ApplyCfg(m["cfg"]).
                    F9AsdsSetup().
                    F9PadPick().
                }
            }
            wait 0.1.
        }
        print "  heading " + round(F9Azimuth, 1) + ", recovery " + F9Mode +
              (choose " (expendable)" if F9Expend else "") +
              ", MECO " + round(F9MecoAlt / 1000) + " km / " + F9MecoDv + " m/s".
    }

    set F9Ev["t0"] to F9T0.
    F9EvSave().
    lock F9Met to time:seconds - F9T0.
    print "T-" + round(-F9Met) + " countdown started".

    set F9Abort to false.
    when not core:messages:empty then {
        local m is core:messages:pop():content.
        if m:istype("Lexicon") and m:haskey("cmd") and m["cmd"] = "abort" set F9Abort to true.
        return F9Met < 0 and not F9Abort.
    }

    F9GridFinsDeploy(false).
    F9LegsDeploy(false).

    print " ".
    sas off.
    rcs off.
    lock steering to heading(F9Azimuth, 90, F9Roll).
    lock throttle to 1.

    wait until F9Met >= -6 or F9Abort.
    if F9Abort F9PadAbort().
    print "T-6  retracting arm and walkway".
    set F9Retracted to F9ErectorOpen().
    if F9Retracted > 0 {
        print "  retracted: " + F9Retracted.
    } else {
        print "  nothing to retract - continuing".
    }
    wait until F9Met >= 0 or F9Abort.
    if F9Abort F9PadAbort().

    set F9Clamped to F9HasClamp().
    if F9Clamped print "T+0  IGNITION (held by clamps)".
    else print "T+0  IGNITION AND RELEASE".
    stage.
    set F9Phase to "ascent".

    wait until ship:availablethrust > 0 or F9Met > 3.
    if ship:availablethrust <= 0 {
        lock throttle to 0.
        print "NO THRUST - engines did not start.".
        wait until false.
    }
    print "  thrust " + round(ship:availablethrust, 0) + " kN, TWR " +
          round(ship:availablethrust / (ship:mass * F9GLocal0()), 2) +
          ", " + F9EngineCount() + " eng.".
    set F9M0 to ship:mass.

    if F9Clamped {
        set F9HoldT0 to time:seconds.
        wait until (ship:availablethrust / (ship:mass * F9GLocal0()) > 1.05
                    and time:seconds - F9HoldT0 > F9HoldDown)
                   or time:seconds - F9HoldT0 > 6.
        set F9Released to F9ReleaseClamp().
        print "T+" + round(F9Met, 1) + " RELEASE (" + F9Released + " clamps), TWR " +
              round(ship:availablethrust / (ship:mass * F9GLocal0()), 2).
    }

    wait until ship:altitude > F9ClearAlt.
    print "T+" + round(F9Met, 1) + " tower cleared, pitching over".

    function F9Pitch {
        local h is ship:altitude.
        if h < F9TurnStart return 90.
        if h > F9TurnEnd return F9TurnFinal.
        local frac is (h - F9TurnStart) / (F9TurnEnd - F9TurnStart).
        return 90 - (90 - F9TurnFinal) * frac ^ F9TurnPow.
    }

    lock steering to heading(F9Azimuth, F9Pitch(), F9Roll).

    function F9AscThrottle {
        local tq is 1.
        if ship:q > F9QOn {
            set tq to 1 - (1 - F9QThrottle) * min(1, (ship:q - F9QOn) / (F9MaxQ - F9QOn)).
        }

        local tg is 1.
        if ship:availablethrust > 0 {
            set tg to F9MaxG * F9GLocal0() * ship:mass / ship:availablethrust.
        }

        return max(0.15, min(1, min(tq, tg))).
    }

    lock throttle to F9AscThrottle().

    set F9NextPrint to 0.
    until ship:altitude >= F9MecoAlt or F9DvLeft() <= F9MecoDv {
        if F9Met > F9NextPrint {
            set F9NextPrint to F9Met + 0.5.
            print "T+" + round(F9Met, 0) +
                  " h" + round(ship:altitude / 1000, 1) +
                  " v" + round(ship:velocity:surface:mag, 0) +
                  " dv" + round(F9DvLeft()) +
                  " q" + round(ship:q, 2) +
                  " t" + round(100 * throttle) +
                  " " + round(ship:availablethrust * throttle /
                              (ship:mass * F9GLocal0()), 1) + "g" +
                  " e" + round(steeringmanager:angleerror, 1) +
                  "/" + round(steeringmanager:rollerror, 0).
        }
        wait 0.02.
    }

    lock throttle to 0.
    print " ".
    print "T+" + round(F9Met, 1) + " MECO".
    F9Mark("meco").
    set F9Phase to "coast".
    local vVert is ship:verticalspeed.
    local vHor is vxcl(up:vector, ship:velocity:surface):mag.
    print "  speed " + round(ship:velocity:surface:mag, 0) + " m/s" +
          "  (vert " + round(vVert, 0) + ", horiz " + round(vHor, 0) + ")".
    print "  angle    " + round(arctan2(vVert, vHor), 1) + " deg above horizon".
    print "  altitude " + round(ship:altitude / 1000, 1) + " km".
    print "  apoapsis " + round(ship:apoapsis / 1000, 1) + " km".
    print "  atmosphere " + round(body:atm:height / 1000) + " km, MECO at " +
          round(100 * ship:altitude / body:atm:height) + "% of its height".
    print "  reserve  " + round(F9DvLeft()) + " m/s, threshold " +
          F9MecoDv + " (" + round(F9FuelPct(), 1) + "% tank)".
    print "  stage    " + round(F9Stage1Mass(), 1) + " t, dry " +
          round(F9Stage1Dry(), 1) + " t".

    wait F9SepWait.
    stage.
    F9Mark("sep").
    print "T+" + round(F9Met, 1) + " SEPARATION at " +
          round(ship:altitude / 1000, 1) + " km, q=" + round(ship:q, 4).

    unlock steering.
    rcs off.
    set ship:name to F9NextBooster().
    print "  stage name: " + ship:name.
    F9SetVesselLoadDist(ship, F9S2LoadDist).
    local tsw is time:seconds.
    local nsw is 0.
    until time:seconds - tsw > 6 {
        if F9SetS1Active() set nsw to nsw + 1.
        wait 0.1.
    }
    print "  active vessel: " + kuniverse:activevessel:name + " (switches " + nsw + ")".
    local sc is F9SepCoast.
    if F9Mode = "rtls" set sc to F9SepCoastRtls.
    print "  separating, " + sc + " s without maneuvers...".
    wait sc.

    set F9S2Name to "".
    list targets in F9Near.
    local best is 1.0e12.
    for v in F9Near {
        if v:distance < best { set best to v:distance. set F9S2Name to v:name. set F9S2Ves to v. }
    }
    if F9S2Name = "" print "  second stage not found nearby".
    else {
        F9SetVesselLoadDist(F9S2Ves, F9S2LoadDist).
        print "  second stage: " + F9S2Name.
        print "  physics range: requested " + round(F9S2LoadDist / 1000) + ", actual " +
              round(F9S2Ves:loaddistance:flying:unload / 1000) + "/" +
              round(F9S2Ves:loaddistance:suborbital:unload / 1000) +
              " km (flying/suborbital)".
    }
    set F9NextS2Dist to time:seconds + F9S2DistEvery.

} else {
    print " ".
    print "--- resumed in flight, prelaunch skipped ---".
    print "  altitude " + round(ship:altitude / 1000, 1) + " km, speed " +
          round(ship:velocity:surface:mag, 0) + " m/s".
}


wait 2.

set F9Ours to false.
for p in ship:parts {
    if p:hasmodule("ModuleTundraEngineSwitch") set F9Ours to true.
}
if not F9Ours {
    unlock steering.
    unlock throttle.
    print " ".
    set F9TelOn to false.
    print "THIS PROCESSOR LEFT WITH THE SECOND STAGE.".
    print "Recovery is impossible from here - run f9 on the".
    print "first stage computer, it sits in the Interstage.".
    wait until false.
}

run once f9lib.

set F9BoostbackErr to 15.
set F9FlipErr to 25.
set F9FinsAlt to F9Atm * 0.70.
set F9EntryEnd to F9Atm * 0.32.
set F9EntryTargetV to 600.
set F9EntryTargetVRtls to 450.
set F9LegsAlt to 500 * F9Scale.

set F9AoAMax to 25.

set F9AoALead to 8.

set F9LatMax to 12.
set F9GlideFactor to 1.15.


set F9LngBias to 0.
if F9Mode = "asds" {
    set F9LngBias to F9AsdsOffAlong.
    print "ballistic aim point shifted by " + F9LngBias + " m past the deck.".
}


set F9AoAOut to 0.
set F9LatOut to 0.

set F9LngPID to pidloop(0.35, 0.3, 0.25, -F9AoAMax, F9AoAMax).
set F9LatPID to pidloop(0.25, 0.2, 0.15, -F9LatMax, F9LatMax).
set F9LngPID:setpoint to 0.
set F9LatPID:setpoint to 0.
set F9AoAqLo to 0.01.
set F9AoAqFull to 0.09.

set F9LandMaxAlt to F9Atm * 0.057.

set F9AoAOffHi to F9LandMaxAlt * 1.6.
set F9AoAOffLo to F9LandMaxAlt * 1.1.

set F9GearHeight to 30 * F9Scale.

set F9GearRadar to 31 * F9Scale.

set F9NoHoverV to 1.5.
set F9HoverGrace to 8.
set F9MinDesc to 0.

set F9LandK3 to 0.6.
set F9LandK1 to 0.7.
set F9SwitchAlt to 150 * F9Scale.
set F9FlareAlt to 20 * F9Scale.
set F9FlareV to 12.
set F9TouchV to 1.
set F9IgnLead to 0.2.

function F9DeckNow {
    if F9AsdsDeck <= 0 return 0.
    local d is F9ToPadRaw():mag.
    if d < 50 return F9AsdsDeck.
    if d > 200 return 0.
    return F9AsdsDeck * (200 - d) / 150.
}

function F9H {
    return max(0, alt:radar - F9GearRadar - F9DeckNow()).
}

function F9LandAcc {
    parameter n.
    if ship:mass <= 0 return 1.
    local k is F9LandK1.
    if n = 3 set k to F9LandK3.
    return max(0.5, F9ModeThrust(n) / ship:mass * k - F9GLocal()).
}

function F9SwitchV {
    return sqrt(F9FlareV ^ 2 + 2 * F9LandAcc(1) * max(0, F9SwitchAlt - F9FlareAlt)).
}

function F9ProfV {
    parameter h.
    if h <= 0 return F9TouchV.
    if h < F9FlareAlt return F9TouchV + (F9FlareV - F9TouchV) * h / F9FlareAlt.
    if h < F9SwitchAlt {
        return sqrt(F9FlareV ^ 2 + 2 * F9LandAcc(1) * (h - F9FlareAlt)).
    }
    return sqrt(F9SwitchV() ^ 2 + 2 * F9LandAcc(3) * (h - F9SwitchAlt)).
}

function F9ProfAccAt {
    parameter h.
    if h < F9FlareAlt {
        return (F9FlareV - F9TouchV) / F9FlareAlt * abs(ship:verticalspeed).
    }
    if h < F9SwitchAlt return F9LandAcc(1).
    return F9LandAcc(3).
}

function F9IgnAlt {
    return F9IgnAltV(ship:velocity:surface:mag).
}

function F9IgnAltV {
    parameter spd.
    if spd <= F9FlareV {
        return F9FlareAlt * max(0, spd - F9TouchV) / max(0.1, F9FlareV - F9TouchV).
    }
    local vs is F9SwitchV().
    if spd <= vs {
        return F9FlareAlt + (spd ^ 2 - F9FlareV ^ 2) / (2 * F9LandAcc(1)).
    }
    return F9SwitchAlt + (spd ^ 2 - vs ^ 2) / (2 * F9LandAcc(3)).
}

function F9GLocal {
    return body:mu / (body:radius + ship:altitude) ^ 2.
}

function F9SetS1Active {
    if kuniverse:activevessel = ship return false.
    if time:seconds < F9LastVesselChange + 2 return false.
    F9SetVesselLoadDist(ship, F9S2LoadDist).
    hudtext("Setting focus to Booster..", 3, 2, 20, yellow, false).
    kuniverse:forceactive(ship).
    set F9LastVesselChange to time:seconds.
    return true.
}
function F9KeepS2 {
    F9SetS1Active().
    if F9S2Name = "" return false.
    if time:seconds < F9NextS2Dist return false.
    set F9NextS2Dist to time:seconds + F9S2DistEvery.
    local s2 is F9S2Ves.
    if not s2:istype("Vessel") or s2:isdead {
        set F9S2Name to "".
        return false.
    }
    if not s2:loaded or not s2:unpacked {
        if s2:orbit:periapsis > body:atm:height {
            set F9S2Orbit to true.
            F9Mark("seco").
            print "  S2 IN ORBIT " + round(s2:orbit:apoapsis / 1000, 1) + " x " +
                  round(s2:orbit:periapsis / 1000, 1) + " km".
        } else print "  S2 released: off physics".
        set F9S2Name to "".
        return false.
    }
    local lf is 0. local ox is 0. local es is "".
    local s2thr is 0. local s2isp is F9S2IspV.
    for p in s2:parts {
        if p:name:contains("S2.Tank") {
            for rs in p:resources {
                if rs:name = "LiquidFuel" set lf to lf + rs:amount.
                if rs:name = "Oxidizer" set ox to ox + rs:amount.
            }
        }
        if p:name:contains("S2.Engine") and p:istype("Engine") {
            set es to " ign " + p:ignition + " fo " + p:flameout + " thrust " + round(p:thrust, 1).
            set s2thr to p:thrust.
            if p:isp > 0 set s2isp to p:isp.
        }
    }
    if s2:orbit:periapsis > body:atm:height and s2thr < 1 {
        set F9S2Orbit to true.
        F9Mark("seco").
        print "  S2 IN ORBIT " + round(s2:orbit:apoapsis / 1000, 1) + " x " +
              round(s2:orbit:periapsis / 1000, 1) + " km".
        set F9S2Name to "".
        return false.
    }
    if s2thr > 1 {
        local rr is body:radius + s2:altitude.
        local vh2 is vxcl(s2:up:vector, s2:velocity:orbit):mag.
        local dvn is max(0, sqrt(body:mu / rr) - vh2).
        local ve2 is s2isp * 9.80665.
        set F9S2SecoEta to time:seconds - F9T0 +
            s2:mass * ve2 / s2thr * (1 - constant:e ^ (-dvn / ve2)).
    }
    F9SetVesselLoadDist(s2, F9S2LoadDist).
    F9SetVesselLoadDist(ship, F9S2LoadDist).
    log "S1: T+" + round(time:seconds - F9T0) + " h " + round(s2:altitude) +
        " v " + round(s2:velocity:orbit:mag) + " loaded " + s2:loaded +
        " unp " + s2:unpacked + " LF " + round(lf) + " Ox " + round(ox) + es
        to "0:/f9s2fuel.log".
    return true.
}

function F9PitchOnly {
    parameter want.
    local st is ship:facing:starvector.
    local f is vxcl(st, want).
    if f:mag < 0.001 return ship:facing.
    local t is vcrs(st, f).
    local d is lookdirup(f, t).
    if vdot(d:starvector, st) < 0 set d to lookdirup(f, -t).
    return d.
}

function F9RcsAxes {
    parameter yawOn, rollOn.
    local n is 0.
    for p in ship:partsnamedpattern("F9\.CGT") {
        local m is p:getmodule("ModuleRCSFX").
        for ev in m:alleventnames {
            if ev:contains("show") and ev:contains("toggle") m:doevent(ev).
        }
        for fn in m:allfieldnames {
            if fn = "pitch" m:setfield(fn, true).
            else if fn = "yaw" {
                m:setfield(fn, yawOn).
                set n to n + 1.
            } else if fn = "roll" or fn:contains("/") {
                m:setfield(fn, rollOn).
                set n to n + 1.
            }
        }
    }
    return n.
}

set F9FlipRateMax to 10.
set F9FlipAlpha0 to 2.
set F9FlipBrakeK to 1.15.
set F9FlipSgn to 1.
function F9PitchFlip {
    parameter errMax, tMax, tgtFn.
    set F9RcsGate to false.
    local cg is ship:partsnamedpattern("F9\.CGT").
    if F9RcsAxes(false, false) = 0 and cg:length > 0 {
        print "  RCS: axes not disabled, fields: " + cg[0]:getmodule("ModuleRCSFX"):allfieldnames:join(", ").
    }
    unlock steering.
    sas off.
    rcs on.
    local t0 is time:seconds.
    local thT is min(errMax * 0.5, 3).
    local alp is F9FlipAlpha0.
    local st is "acc".
    local tPrev is t0.
    local thPrev is -1.
    local wr is 0.
    local tAcc is t0.
    local thAcc is -1.
    local sgnChecked is false.
    local tBrake is 0.
    local dAcc is 0.
    local nPulse is 1.
    local cmd is 0.
    local th is 180.
    until time:seconds - t0 > tMax {
        local fw is ship:facing:forevector.
        local tv is vxcl(ship:facing:starvector, tgtFn()).
        if tv:mag < 0.001 set tv to fw.
        set th to vAng(fw, tv).
        local dirUp is 1.
        if vdot(tv, ship:facing:topvector) < 0 set dirUp to -1.
        local now is time:seconds.
        local dt is now - tPrev.
        if thPrev >= 0 and dt > 0.05 {
            set wr to wr + ((thPrev - th) / dt - wr) * 0.5.
            set tPrev to now.
            set thPrev to th.
        } else if thPrev < 0 {
            set tPrev to now.
            set thPrev to th.
        }
        if thAcc < 0 set thAcc to th.

        if st = "acc" {
            if not sgnChecked and now - tAcc > 1 {
                set sgnChecked to true.
                if th - thAcc > 1 {
                    set F9FlipSgn to -F9FlipSgn.
                    set sgnChecked to false.
                    set tAcc to now.
                    set thAcc to th.
                    print "  flip: pitch sign inverted".
                }
            }
            local wMax is min(F9FlipRateMax, sqrt(max(0, alp * (th - thT)))).
            set cmd to 1.
            if sgnChecked and wr >= wMax {
                set dAcc to now - tAcc.
                if dAcc > 0.3 and wr > 0.5 set alp to max(0.3, min(20, wr / dAcc)).
                set st to "coast".
            }
        }
        if st = "coast" {
            set cmd to 0.
            if th - thT <= F9FlipBrakeK * wr * wr / (2 * alp) {
                set st to "brake".
                set tBrake to now.
                set nPulse to nPulse + 1.
            } else if wr < 0.2 and th > errMax + 5 {
                set st to "acc".
                set tAcc to now.
                set thAcc to th.
                set nPulse to nPulse + 1.
            }
        }
        if st = "brake" {
            set cmd to -1.
            if wr <= 0.3 or now - tBrake > max(1, dAcc * 1.5) set st to "done".
        }
        if st = "done" or (th < errMax and abs(wr) < 1) break.
        set ship:control:pitch to cmd * dirUp * F9FlipSgn.
        F9KeepS2().
        wait 0.05.
    }
    set ship:control:pitch to 0.
    set ship:control:neutralize to true.
    F9RcsAxes(true, false).
    local msg is "flip: " + round(time:seconds - t0, 1) + " s, remaining " + round(th, 1) +
          " deg, pulses " + nPulse + ", spin-up " + round(dAcc, 1) + " s, accel " +
          round(alp, 2) + " deg/s2".
    print "  " + msg.
    F9LandLog(msg).
    return time:seconds - t0.
}

set F9RollGate to false.
when F9RcsGate then {
    local ae is abs(steeringmanager:angleerror).
    if F9RollGate set ae to max(ae, abs(steeringmanager:rollerror)).
    local w is vxcl(ship:facing:forevector, ship:angularvel):mag * constant:radtodeg.
    if ae > F9RcsOnErr rcs on.
    else if ae < F9RcsOffErr and w < F9RcsOffRate rcs off.
    return true.
}

function F9CoastAtt {
    local rtv is -ship:velocity:surface:normalized.
    local av is vAng(rtv, up:vector).
    if av < 5 or av > 175 return F9PitchOnly(rtv).
    return lookdirup(rtv, up:vector).
}

function F9AltAbovePad {
    return ship:altitude - F9Pad:terrainheight.
}

function F9ToPad {
    local raw is vxcl(up:vector, F9Pad:position).
    if F9PadOffAlong = 0 and F9PadOffSide = 0 return raw.
    if raw:mag < 1 return raw.
    local fwd is raw:normalized.
    return raw + fwd * F9PadOffAlong + vcrs(up:vector, fwd) * F9PadOffSide.
}

function F9ToPadRaw {
    return vxcl(up:vector, F9Pad:position).
}

function F9FallTime {
    local h is max(1, F9AltAbovePad()).
    local vv is ship:verticalspeed.
    local gg is F9GLocal().
    return (vv + sqrt(vv * vv + 2 * gg * h)) / gg.
}

function F9BoostbackDV {
    local toPad is F9ToPad().
    local tf is max(1, F9FallTime()).
    local want is toPad:normalized * (toPad:mag / tf).
    local now is vxcl(up:vector, ship:velocity:surface).
    return want - now.
}

set F9ThreeAt to 1.15.

set F9ThreeDownHold to 0.2.
set F9ThreeDownT0 to 0.

function F9BurnEngines {
    if ship:mass <= 0 return 1.
    if F9H() > F9SwitchAlt return 3.
    local spd is ship:velocity:surface:mag.
    if spd > F9SwitchV() * F9ThreeAt return 3.
    return 1.
}

if (F9OnPad or ship:altitude > F9EntryAlt) and F9Mode = "rtls" {

    print " ".
    print "--- waiting for thinner air before turning ---".
    set F9FlipQ to 0.0015.
    set F9WaitT0 to time:seconds.
    until ship:q < F9FlipQ or ship:verticalspeed < 0 or time:seconds - F9WaitT0 > 90 {
        F9KeepS2().
        wait 0.5.
    }
    print "  h=" + round(ship:altitude / 1000, 1) + "km  q=" + round(ship:q, 4) +
          "  waited " + round(time:seconds - F9WaitT0, 0) + " s".
    if ship:q >= F9FlipQ print "  WARNING: high dynamic pressure, the turn will be hard.".

    print " ".
    print "--- turning for boostback ---".
    F9SetEngineMode(3).
    lock throttle to 0.
    lock F9BBDir to F9BoostbackDV():normalized.
    lock steering to F9PitchOnly(F9BBDir).

    set F9FlipDt to F9PitchFlip(F9FlipErr, 40, { return F9BBDir. }).
    print "  aligned in " + round(F9FlipDt, 1) + " s, error " +
          round(vAng(ship:facing:forevector, F9BBDir), 1) + " deg".
    rcs off.
    lock steering to lookdirup(F9BBDir, ship:facing:topvector).

    print "--- boostback ---".
    lock throttle to 1.
    F9Mark("bb").
    set F9Phase to "boostback".
    set F9NextPrint to 0.
    until F9BoostbackDV():mag < F9BoostbackErr or F9FuelPct() < 8 {
        F9KeepS2().
        if time:seconds > F9NextPrint {
            set F9NextPrint to time:seconds + 1.
            print "  dv=" + round(F9BoostbackDV():mag, 0) +
                  "  to target " + round(F9ToPad():mag / 1000, 1) + "km" +
                  "  fuel=" + round(F9FuelPct(), 1) + "%".
        }
        wait 0.02.
    }
    lock throttle to 0.
    print "  boostback done, reserve " + round(F9DvLeft()) + " m/s".
    if F9FuelPct() < 8 print "  WARNING: stopped on fuel, not on target".

    print "--- coast ---".
    set F9Phase to "coast".
    lock steering to F9PitchOnly(-ship:velocity:surface).
    set F9FinsTook to F9GridFinsDeploy(true).
    print "  grid fins that took the command: " + F9FinsTook +
          " of " + F9GridFins:length + ", state [" + F9GridFinsState() + "]".
    if F9FinsTook = 0 print "  grid fin events: " + F9GridFinsEvents().
    set F9FlipDt to F9PitchFlip(F9CoastFlipErr, 60, { return -ship:velocity:surface. }).
    print "  engines-first in " + round(F9FlipDt, 1) + " s".
    F9RcsAxes(true, true).
    set F9RollGate to true.
    lock steering to F9CoastAtt().
    set F9RcsGate to true.
    print "  apoapsis " + round(ship:apoapsis / 1000) + " km".
    F9AsdsPredPub().

} else {
    print " ".
    if F9Mode = "asds" {
        print "--- asds mode: no boostback, the barge is downrange ---".
    } else if F9Mode = "splashdown" {
        print "--- splashdown mode: landing wherever we fall ---".
    } else {
        print "--- resumed below entry point, boostback skipped ---".
    }

    lock steering to F9PitchOnly(-ship:velocity:surface).
    set F9FinsTook to F9GridFinsDeploy(true).
    F9PitchFlip(F9CoastFlipErr, 60, { return -ship:velocity:surface. }).
    lock steering to F9PitchOnly(-ship:velocity:surface).
    set F9RcsGate to true.
    F9AsdsPredPub().
    print "  engines-first, apoapsis " + round(ship:apoapsis / 1000) + " km".
    print "  grid fins that took the command: " + F9FinsTook +
          " of " + F9GridFins:length + ", state [" + F9GridFinsState() + "]".
    if F9FinsTook = 0 {
        print "  grid fin events: " + F9GridFinsEvents().
    }
}



wait until ship:altitude < F9EntryAlt.

set F9SootTook to F9SootOn().
print " ".
print "  soot: " + F9SootTook + " of " + F9SootParts():length + " parts".
if F9SootTook = 0 print "  soot events: " + F9SootEvents().

print "  attitude error at ignition " +
      round(vAng(ship:facing:forevector, -ship:velocity:surface:normalized), 1) +
      " deg".
if F9AsdsRefresh() {
    print "  barge: " + round(F9Pad:lat, 4) + " / " + round(F9Pad:lng, 4) +
          ", deck " + round(F9AsdsDeck, 1) + " m".
}

set F9EntryTiltMax to 20.
set F9EntryTiltPerKm to 8.
set F9EntryMissDead to 50.

set F9EntryThOut to 0.
function F9EntryDir {
    local retro is -ship:velocity:surface:normalized.
    if not F9Guided() return retro.
    local hb is -vxcl(up:vector, ship:velocity:surface).
    if hb:mag < 1 return retro.
    set hb to hb:normalized.
    local thr is vAng(up:vector, retro).
    local lng is F9MissLong() - F9LngBias.
    local lat is F9MissLat().
    local th is thr.
    if abs(lng) > F9EntryMissDead {
        local dth is max(-F9EntryTiltMax, min(F9EntryTiltMax, lng / 1000 * F9EntryTiltPerKm)).
        set th to max(0, min(90, thr + dth)).
    }
    set F9EntryThOut to th - thr.
    local dir is up:vector * cos(th) + hb * sin(th).
    if abs(lat) > F9EntryMissDead {
        local side is vcrs(up:vector, -hb):normalized.
        local la is min(F9EntryTiltMax, abs(lat) / 1000 * F9EntryTiltPerKm).
        local sg is -1.
        if lat < 0 set sg to 1.
        set dir to dir:normalized + side * (sg * tan(la)).
    }
    return dir:normalized.
}

if F9RollGate {
    set F9RollGate to false.
    F9RcsAxes(true, false).
    print "  roll at entry " + round(steeringmanager:rollerror, 1) + " deg from zero".
}
if F9Mode = "rtls" set F9EntryTargetV to F9EntryTargetVRtls.
print "--- entry burn ---".
F9SetEngineMode(3).
lock steering to lookdirup(F9EntryDir(), ship:facing:topvector).
lock throttle to 1.
F9Mark("entry").
set F9Phase to "entry".
set F9NextPrint to 0.
until ship:velocity:surface:mag < F9EntryTargetV
      or ship:altitude < F9EntryEnd
      or F9DvLeft() < 450 {
    F9KeepS2().
    if time:seconds > F9NextPrint {
        set F9NextPrint to time:seconds + 0.5.
        print "  h=" + round(ship:altitude / 1000, 1) + "km  v=" +
              round(ship:velocity:surface:mag, 0) + "  target " + F9EntryTargetV +
              "  reserve " + round(F9DvLeft()) +
              "  miss " + round((F9MissLong() - F9LngBias) / 1000, 1) +
              "km  turn " +
              round(vAng(F9EntryDir(), -ship:velocity:surface:normalized), 1) +
              " (" + round(F9EntryThOut, 1) + " to vertical/horizontal)".
    }
    wait 0.02.
}
lock throttle to 0.


print "  entry done at " + round(ship:altitude / 1000, 1) + " km, v=" +
      round(ship:velocity:surface:mag, 0) + " m/s, reserve " + round(F9DvLeft()) + " m/s".
if ship:velocity:surface:mag > F9EntryTargetV * 1.3 {
    print "  WARNING: speed not fully killed, burn ended before target.".
}

print "--- aero descent ---".
if addons:tr:available and addons:tr:hasimpact {
    set F9NatGeo to addons:tr:impactpos.
    print "  natural point after entry: " + round(F9NatGeo:lat, 4) + " / " +
          round(F9NatGeo:lng, 4) + ", from target " +
          round((F9NatGeo:position - F9Pad:position):mag / 1000, 1) + " km".
    F9LandLog("NAT " + round(F9NatGeo:lat, 5) + " " + round(F9NatGeo:lng, 5) +
              " from tgt " + round((F9NatGeo:position - F9Pad:position):mag)).
}
set F9Phase to "glide".

set F9RcsGate to false.
rcs off.

function F9LandLog {
    parameter s.
    log "T+" + round(time:seconds - F9T0) + " " + F9Phase + " " + s +
        " m" + round(ship:mass, 2) + " dv" + round(F9DvLeft()) +
        " fuel" + round(F9FuelPct(), 1) + " thrust" + round(ship:availablethrust)
        to "0:/f9s1land.log".
}

F9SetEngineMode(1).
print "  landing mode: " + F9EngineCount() + " eng. [" + F9ModeName() + "]".

function F9AoA {
    local qq is ship:q.
    if qq <= F9AoAqLo return 0.

    local kin is min(1, (qq - F9AoAqLo) / (F9AoAqFull - F9AoAqLo)).

    local h is F9AltAbovePad().
    local kout is min(1, max(0, (h - F9AoAOffLo) / (F9AoAOffHi - F9AoAOffLo))).

    local want is F9AoAMax * min(kin, kout).

    local act is vAng(ship:facing:forevector, -ship:velocity:surface:normalized).
    return min(want, max(6, act + F9AoALead)).
}

function F9ApproachVec {
    local a is vxcl(up:vector, F9Pad:position).
    if a:mag < 1 return vxcl(up:vector, ship:velocity:surface):normalized.
    return a:normalized.
}

function F9ErrorVec {
    if addons:tr:available and addons:tr:hasimpact {
        return vxcl(up:vector, addons:tr:impactpos:position - F9Pad:position).
    }
    local tf is max(1, F9FallTime()).
    return vxcl(up:vector, ship:velocity:surface) * tf - F9ToPad().
}

function F9MissLong {
    return vdot(F9ApproachVec(), F9ErrorVec()).
}

function F9MissLat {
    return vdot(vcrs(up:vector, F9ApproachVec()), F9ErrorVec()).
}

function F9AeroSide {
    parameter nose.
    local u is -ship:velocity:surface.
    return u - vdot(u, nose) * nose.
}

function F9GlideDir {
    local retro is -ship:velocity:surface:normalized.
    local cap is F9AoA().

    local ang is cap.
    local lat is 0.
    if F9Guided() {
        local eLng is F9MissLong() - F9LngBias.
        local eLat is F9MissLat().

        set F9LngPID:maxoutput to min(cap, max(abs(eLng) / 100, 5)).
        set F9LngPID:minoutput to -F9LngPID:maxoutput.
        set F9LatPID:maxoutput to min(F9LatMax, max(abs(eLat) / 50, 2.5)).
        set F9LatPID:minoutput to -F9LatPID:maxoutput.

        set F9AoAOut to F9LngPID:update(time:seconds, eLng) * F9GlideFactor.
        set F9LatOut to F9LatPID:update(time:seconds, eLat).

        set ang to min(cap, abs(F9AoAOut)).
        set lat to abs(F9LatOut).
    }
    else set F9AoAOut to cap.

    if ang < 0.5 return retro.

    local tilt is vAng(retro, up:vector).
    if tilt < 5 or tilt > 175 return retro.

    local star is lookdirup(retro, up:vector):starvector.
    local a is retro * angleaxis(ang, star).
    local b is retro * angleaxis(-ang, star).
    local wantUp is 1.
    if F9AoAOut < 0 set wantUp to -1.
    local nose is a.
    if wantUp * vdot(F9AeroSide(b), up:vector) >
       wantUp * vdot(F9AeroSide(a), up:vector) set nose to b.

    if lat > 0.2 {
        local want is (-F9ErrorVec()):normalized.
        local c is nose * angleaxis(lat, up:vector).
        local d is nose * angleaxis(-lat, up:vector).
        set nose to c.
        if vdot(F9AeroSide(d), want) > vdot(F9AeroSide(c), want) set nose to d.
    }
    return nose.
}

set F9TopLatch to V(0, 0, 0).
function F9TopRef {
    if F9Guided() {
        local tp is F9ToPad().
        if tp:mag > 100 {
            set F9TopLatch to tp:normalized.
            return F9TopLatch.
        }
        local tl is vxcl(up:vector, F9TopLatch).
        if tl:mag > 0.3 return tl:normalized.
    }
    local hv is vxcl(up:vector, ship:velocity:surface).
    if hv:mag > 1 return hv:normalized.
    return up:vector.
}

F9AsdsRefresh().
if F9Guided() and addons:tr:available and kuniverse:activevessel = ship addons:tr:settarget(F9Pad).


lock F9AeroDir to F9GlideDir().
lock steering to lookdirup(F9AeroDir, F9TopRef()).

set F9FastAlt to 3000 * F9Scale.

set F9LeadOn to F9Guided().

set F9TravelRatio to 0.705.
set F9TravelKMin to 3.
set F9TravelKMax to 12.

function F9TravelK {
    parameter hi, vv.
    return max(F9TravelKMin, min(F9TravelKMax, F9TravelRatio * hi / vv)).
}
set F9LeadGain to 1.
set F9LeadMax to 1500.
set F9LeadRate to 150.
set F9LeadAdd to 40.
set F9LeadT to time:seconds.

set F9LeadHiRate to 150.
set F9LeadHiPrev to -1.

function F9AimLead {
    local spd is ship:velocity:surface:mag.
    local vv is max(20, -ship:verticalspeed).
    local hi is F9IgnAlt() + spd * F9IgnLead.
    local gh is vxcl(up:vector, ship:velocity:surface):mag.
    return max(0, min(F9LeadMax, F9LeadGain * gh * (hi / vv - F9TravelK(hi, vv)))).
}

set F9DragFile to "0:/f9drag.json".
set F9DragBin to 0.1.
set F9DragNB to 40.
set F9DrPeriod to 0.5.
set F9SimPeriod to 1.
set F9SimDt to 0.5.
set F9SimGuard to 4.

set F9DragTab to list().
set F9DragSum to list().
set F9DragCnt to list().
from { local i is 0. } until i >= F9DragNB step { set i to i + 1. } do {
    F9DragTab:add(0).
    F9DragSum:add(0).
    F9DragCnt:add(0).
}
if homeconnection:isconnected and exists(F9DragFile) {
    local dj is readjson(F9DragFile).
    if dj:haskey("c") {
        local src is dj["c"].
        from { local i is 0. } until i >= min(F9DragNB, src:length) step { set i to i + 1. } do {
            set F9DragTab[i] to src[i].
        }
    }
}
set F9DragSubN to 0.
from { local i is 0. } until i >= 12 step { set i to i + 1. } do {
    if F9DragTab[i] > 0 set F9DragSubN to F9DragSubN + 1.
}
set F9DragOk to F9DragSubN >= 3.
if F9DragOk print "  drag: table present, lead by simulation".
else print "  drag: subsonic cells " + F9DragSubN + ", this flight builds the table".

function F9AtmRho {
    parameter a.
    local t is max(1, body:atm:alttemp(a)).
    return body:atm:altitudepressure(a) * 101325 * body:atm:molarmass / (F9AtmR * t).
}

function F9AtmSnd {
    parameter a.
    local t is max(1, body:atm:alttemp(a)).
    return sqrt(body:atm:adbidx * F9AtmR * t / body:atm:molarmass).
}

function F9DragBinV {
    parameter i.
    if F9DragCnt[i] > 0 return F9DragSum[i] / F9DragCnt[i].
    return F9DragTab[i].
}

function F9DragTabC {
    parameter mach.
    local i is max(0, min(F9DragNB - 1, floor(mach / F9DragBin))).
    local k is 0.
    until k >= F9DragNB {
        if i - k >= 0 and F9DragTab[i - k] > 0 return F9DragTab[i - k].
        if i + k < F9DragNB and F9DragTab[i + k] > 0 return F9DragTab[i + k].
        set k to k + 1.
    }
    return 0.
}

set F9DragK to 1.
set F9DragKA to 0.3.

function F9DragC {
    parameter mach.
    local i is max(0, min(F9DragNB - 1, floor(mach / F9DragBin))).
    local k is 0.
    until k >= F9DragNB {
        if i - k >= 0 and F9DragBinV(i - k) > 0 return F9DragBinV(i - k).
        if i + k < F9DragNB and F9DragBinV(i + k) > 0 return F9DragBinV(i + k).
        set k to k + 1.
    }
    return F9DragNow.
}

set F9DrT to 0.
set F9DrVh to 0.
set F9DrVz to 0.
set F9DrA to 0.
set F9DragNow to 0.
set F9MachNow to 0.
function F9DragMeas {
    local t is time:seconds.
    if F9DrT > 0 and t - F9DrT < F9DrPeriod return.
    local vh is vxcl(up:vector, ship:velocity:surface):mag.
    local vz is ship:verticalspeed.
    if F9DrT > 0 {
        local dt is t - F9DrT.
        local ah is (vh - F9DrVh) / dt.
        local az is (vz - F9DrVz) / dt + F9GLocal().
        local mh is (vh + F9DrVh) / 2.
        local mz is (vz + F9DrVz) / 2.
        local sv is sqrt(mh ^ 2 + mz ^ 2).
        local dd is -(ah * mh + az * mz) / max(1, sv).
        local am is (ship:altitude + F9DrA) / 2.
        local rho is F9AtmRho(am).
        if sv > 30 and rho > 0.0001 and dd > 0 {
            set F9DragNow to dd * ship:mass / (rho * sv * sv).
            set F9MachNow to sv / F9AtmSnd(am).
            local i is min(F9DragNB - 1, floor(F9MachNow / F9DragBin)).
            set F9DragSum[i] to F9DragSum[i] + F9DragNow.
            set F9DragCnt[i] to F9DragCnt[i] + 1.
            local ct is F9DragTabC(F9MachNow).
            if ct > 0 {
                local kr is max(0.3, min(3, F9DragNow / ct)).
                set F9DragK to F9DragK + F9DragKA * (kr - F9DragK).
            }
        }
    }
    set F9DrT to t.
    set F9DrVh to vh.
    set F9DrVz to vz.
    set F9DrA to ship:altitude.
}

set F9BsDt to 0.25.
set F9BsTilt to 25.
set F9BsTiltPerM to 0.3.
set F9BsTiltMin to 4.
set F9BsIsp to 282.
set F9BsTau to 2.

function F9BsLandAcc {
    parameter n, m.
    local k is F9LandK1.
    if n = 3 set k to F9LandK3.
    return max(0.5, F9ModeThrust(n) / m * k - F9GLocal()).
}

function F9BsProfV {
    parameter h, m.
    if h <= 0 return F9TouchV.
    if h < F9FlareAlt return F9TouchV + (F9FlareV - F9TouchV) * h / F9FlareAlt.
    local a1 is F9BsLandAcc(1, m).
    if h < F9SwitchAlt return sqrt(F9FlareV ^ 2 + 2 * a1 * (h - F9FlareAlt)).
    local vs is sqrt(F9FlareV ^ 2 + 2 * a1 * max(0, F9SwitchAlt - F9FlareAlt)).
    return sqrt(vs ^ 2 + 2 * F9BsLandAcc(3, m) * (h - F9SwitchAlt)).
}

function F9BjInit {
    parameter h, vz, vh, m, off, dt.
    set F9BjH to h. set F9BjVz to vz. set F9BjVh to vh. set F9BjM to m.
    set F9BjOff to off. set F9BjDt to dt.
    set F9BjX to 0. set F9BjT to 0. set F9BjN to 3.
}

function F9BjStep {
    if F9BjH <= 0.5 or F9BjT > 90 return true.
    local gg is F9GLocal().
    local h is F9BjH. local vz is F9BjVz. local vh is F9BjVh. local m is F9BjM.
    if F9BjN = 3 and h < F9SwitchAlt set F9BjN to 1.
    local tq is F9ModeThrust(F9BjN).
    local sv is max(1, sqrt(vh ^ 2 + vz ^ 2)).
    local ang is 0.
    if vz < 0 set ang to arctan2(vh, -vz).
    local tilt is min(ang, min(F9BsTilt, max(F9BsTiltMin, h * F9BsTiltPerM))).
    local tgo is h / max(0.5, -vz).
    local tau is max(1, min(F9BsTau, tgo * 0.4)).
    local pd is F9BsLandAcc(1, m).
    if h >= F9SwitchAlt set pd to F9BsLandAcc(3, m).
    if h < F9FlareAlt set pd to (F9FlareV - F9TouchV) / F9FlareAlt * abs(vz).
    local aup is (-F9BsProfV(h, m) - vz) / tau + gg + pd.
    local thr is max(0, min(1, aup / cos(tilt) * m / tq)).
    local ta is tq * thr / m.
    local a is h + F9BjOff.
    local dd is F9DragTabC(sv / F9AtmSnd(a)) * F9DragK * F9AtmRho(a) * sv * sv / m.
    local dt is F9BjDt.
    set F9BjVh to max(0, vh - (ta * sin(tilt) + dd * vh / sv) * dt).
    set F9BjVz to vz + (ta * cos(tilt) - gg - dd * vz / sv) * dt.
    set F9BjH to h + F9BjVz * dt.
    set F9BjX to F9BjX + F9BjVh * dt.
    set F9BjM to m - tq * thr / (F9BsIsp * 9.80665) * dt.
    set F9BjT to F9BjT + dt.
    return false.
}

function F9BurnSim {
    parameter h, vz, vh, m, off.
    F9BjInit(h, vz, vh, m, off, F9BsDt).
    until F9BjStep() { }
    return F9BjX.
}
F9BjInit(0, 0, 0, 1, 0, F9BsDt).

set F9BjSteps to 5.
set F9BjOn to false.
set F9BjOk to false.
set F9BjK to 0.
set F9BjHv to V(0, 0, 0).
set F9BjD to V(0, 0, 0).
set F9BjHv0 to V(0, 0, 0).
set F9BjD0 to V(0, 0, 0).
function F9BjRun {
    local h is F9H().
    if not F9BjOn {
        local hv is vxcl(up:vector, ship:velocity:surface).
        local dt is 0.5.
        if h < 400 set dt to 0.25.
        F9BjInit(h, ship:verticalspeed, hv:mag, ship:mass, ship:altitude - h, dt).
        set F9BjHv0 to hv.
        set F9BjD0 to F9ToPad().
        set F9BjOn to true.
    }
    local i is 0.
    until i >= F9BjSteps {
        if F9BjStep() {
            if F9BjHv0:mag > 0.5 set F9BjK to F9BjX / F9BjHv0:mag.
            set F9BjHv to F9BjHv0.
            set F9BjD to F9BjD0.
            set F9BjOk to F9BjK > 0.
            set F9BjOn to false.
            return.
        }
        set i to i + 1.
    }
}

set F9SimIgnH to 0.
set F9SimIgnGh to 0.
set F9SimIgnVz to 0.
set F9SimIgnM to 0.
set F9SimLeadV to -1.
set F9SimNext to 0.
function F9SimLead {
    local h is F9H().
    local off is ship:altitude - h.
    local vh is vxcl(up:vector, ship:velocity:surface):mag.
    local vz is ship:verticalspeed.
    local m is ship:mass.
    local gg is F9GLocal().
    local x is 0.
    local n is 0.
    local ign is false.
    until ign or h <= 0 or n > 300 {
        local sv is max(1, sqrt(vh ^ 2 + vz ^ 2)).
        if h < F9IgnAltV(sv) + sv * F9IgnLead and (F9Mode <> "rtls" or h + off < F9LandMaxAlt) {
            set ign to true.
        } else {
            local a is h + off.
            local dd is F9DragTabC(sv / F9AtmSnd(a)) * F9DragK * F9AtmRho(a) * sv * sv / m.
            local dt is F9SimDt.
            if h > 3000 set dt to 1.
            set vh to max(0, vh - dd * vh / sv * dt).
            set vz to vz - (gg + dd * vz / sv) * dt.
            set h to h + vz * dt.
            set x to x + vh * dt.
            set n to n + 1.
        }
    }
    if not ign return -1.
    set F9SimIgnH to h.
    set F9SimIgnGh to vh.
    set F9SimIgnVz to vz.
    set F9SimIgnM to m.
    local xb is F9BurnSim(h, vz, vh, m, off).
    local x0 is x.
    until h <= 0 or n > 400 {
        local sv is max(1, sqrt(vh ^ 2 + vz ^ 2)).
        local a is h + off.
        local dd is F9DragTabC(sv / F9AtmSnd(a)) * F9DragK * F9AtmRho(a) * sv * sv / m.
        set vh to max(0, vh - dd * vh / sv * F9SimDt).
        set vz to vz - (gg + dd * vz / sv) * F9SimDt.
        set h to h + vz * F9SimDt.
        set x to x + vh * F9SimDt.
        set n to n + 1.
    }
    return max(0, min(F9LeadMax, (x - x0) - xb + F9LeadAdd)).
}

function F9DragSave {
    if not homeconnection:isconnected return.
    local out is list().
    local nn is 0.
    from { local i is 0. } until i >= F9DragNB step { set i to i + 1. } do {
        local cv is F9DragTab[i].
        if F9DragCnt[i] > 0 {
            local cur is F9DragSum[i] / F9DragCnt[i].
            if cv > 0 set cv to (cv + cur) / 2.
            else set cv to cur.
            set nn to nn + 1.
        }
        out:add(cv).
    }
    if nn = 0 return.
    writejson(lexicon("c", out, "bin", F9DragBin), F9DragFile).
    print "  drag table: cells updated " + nn.
}

function F9LeadStep {
    local dt is time:seconds - F9LeadT.
    set F9LeadT to time:seconds.
    if not F9LeadOn return.
    F9DragMeas().
    local want is -1.
    if F9DragOk {
        if time:seconds > F9SimNext {
            set F9SimNext to time:seconds + F9SimPeriod.
            local hleft is F9H() - F9SimIgnH.
            if F9SimLeadV < 0 or hleft > F9SimGuard * max(20, -ship:verticalspeed) set F9SimLeadV to F9SimLead().
        }
        set want to F9SimLeadV.
    } else {
        local hi is F9IgnAlt() + ship:velocity:surface:mag * F9IgnLead.
        local rate is 9999.
        if F9LeadHiPrev >= 0 and dt > 0.01 set rate to abs(hi - F9LeadHiPrev) / dt.
        set F9LeadHiPrev to hi.
        if rate <= F9LeadHiRate set want to F9AimLead().
    }
    if want < 0 return.
    local stp is F9LeadRate * max(0, min(1, dt)).
    set F9LngBias to F9LngBias + max(-stp, min(stp, want - F9LngBias)).
}

set F9NextPrint to 0.
until F9H() < F9IgnAlt() + ship:velocity:surface:mag * F9IgnLead
      and ship:altitude < F9LandMaxAlt {
    if F9H() > F9FastAlt F9KeepS2().
    F9LeadStep().

    if time:seconds > F9NextPrint and F9H() > F9FastAlt {
        set F9NextPrint to time:seconds + 1.
        print "h" + round(F9AltAbovePad(), 0) +
              " v" + round(ship:velocity:surface:mag, 0) +
              " q" + round(ship:q, 3) +
              " aoa" + round(F9AoAOut, 0) +
              " lat" + round(F9LatOut, 1) +
              "/" + round(vAng(ship:facing:forevector,
                               -ship:velocity:surface:normalized), 0) +
              " e" + round(steeringmanager:angleerror, 1) +
              "/" + round(steeringmanager:rollerror, 0) +
              " s2" + (choose round(F9S2Ves:distance / 1000)
                       if F9S2Name <> "" else 0) +
              (choose "" if F9S2Name = "" or F9S2Ves:loaded else "!") +
              " miss" + round((F9MissLong() - F9LngBias) / 1000, 1) +
              "/" + round(F9MissLat() / 1000, 1) +
              " dv" + round(F9DvLeft()).
        F9LandLog("h" + round(F9AltAbovePad()) +
                  " v" + round(ship:velocity:surface:mag) +
                  " vv" + round(ship:verticalspeed) +
                  " hv" + round(vxcl(up:vector, ship:velocity:surface):mag) +
                  " q" + round(ship:q, 3) +
                  " aoa" + round(F9AoAOut) +
                  " miss" + round(F9MissLong() - F9LngBias) +
                  "/" + round(F9MissLat()) +
                  " ign" + round(F9IgnAlt()) +
                  " aim" + round(F9LngBias) +
                  " want" + round(choose F9SimLeadV if F9DragOk else F9AimLead()) +
                  " M" + round(F9MachNow, 2) +
                  " c" + round(F9DragNow, 4) +
                  " k" + round(F9DragK, 2) +
                  " simign" + round(F9SimIgnH) + "/" + round(F9SimIgnGh)).
    }
    wait 0.02.
}


set F9LandKappa to 1.
set F9KappaMin to 0.75.
set F9KappaMax to 1.35.

set F9BurnMode to F9BurnEngines().
F9SetEngineMode(F9BurnMode).
print "--- landing burn (" + F9BurnMode + " eng.) ---".
F9Mark("lburn").
set F9Phase to "landing".

if F9Guided() {
    local gh is vxcl(up:vector, ship:velocity:surface):mag.
    if gh > 1 {
        local tk is F9TravelK(F9H(), max(20, -ship:verticalspeed)).
        set F9LandKappa to max(F9KappaMin, min(F9KappaMax,
            (F9ToPadRaw():mag / gh) / tk)).
        print "  profile scale " + round(F9LandKappa, 3) +
              " (need " + round(F9ToPadRaw():mag / gh, 2) +
              ", profile gives " + round(tk, 2) + ")".
    }
}

set F9LoopT to time:seconds.
set F9LoopMax to 0.
F9LandLog("START simign" + round(F9SimIgnH) + " h" + round(F9H()) +
          " v" + round(ship:velocity:surface:mag) +
          " vv" + round(ship:verticalspeed) +
          " hv" + round(vxcl(up:vector, ship:velocity:surface):mag, 1) +
          " tgt" + round(F9ToPad():mag) +
          " aim" + round(F9LngBias) +
          " scale" + round(F9LandKappa, 3) +
          " eng" + F9BurnMode).



set F9Tau to 2.

set F9LandVMax to 40.

set F9LandVPerM to 0.15.

set F9MaxTilt to 25.
set F9MinThrottle to 0.4.

set F9DivertAlt to 150 * F9Scale.
set F9DivertMin to 12 * F9Scale.
set F9DivertMiss to 40.
set F9DivertUp to 3.
set F9DivertKeep to 140.
set F9DivertMax to 12.
set F9DivertT0 to 0.

set F9DivertUse to false.
set F9DivertOn to false.

function F9Diverting {
    if not F9DivertUse return false.
    if not F9Guided() return false.
    local h is F9H().
    if h > F9DivertAlt or h < F9DivertMin return false.
    if F9ToPad():mag < F9DivertMiss return false.
    if F9DvLeft() < F9DivertKeep return false.
    if F9DivertT0 > 0 and time:seconds - F9DivertT0 > F9DivertMax return false.
    return true.
}

function F9WantVV {
    if F9DivertOn return F9DivertUp.
    if F9TransOn return -F9TransVV.
    return -max(F9ProfV(F9H()), F9MinDesc).
}

function F9ProfDot {
    if F9DivertOn return 0.
    if F9TransOn return 0.
    return F9ProfAccAt(F9H()).
}

function F9TGo {
    return max(0.5, min(F9TGoH(F9H()), F9H() / max(0.5, abs(ship:verticalspeed)))).
}

function F9TGoH {
    parameter h.
    local t is 0.
    if h > F9SwitchAlt {
        set t to (F9ProfV(h) - F9SwitchV()) / F9LandAcc(3).
        set h to F9SwitchAlt.
    }
    if h > F9FlareAlt {
        set t to t + (F9ProfV(h) - F9FlareV) / F9LandAcc(1).
        set h to F9FlareAlt.
    }
    set t to t + h / max(1, (F9FlareV + F9TouchV) / 2).
    return t.
}

set F9LatAcc to 2.3.

set F9LatAccMax to 2.3.

set F9LandVMin to 2.
set F9AimDead to 15.

set F9AimFreeze to 60 * F9Scale.

function F9LatAccNow {
    return max(0.3, min(F9LatAcc, F9GLocal() * tan(F9TiltCap()))).
}

function F9LatAccCmd {
    return max(0.3, min(F9LatAccMax, F9GLocal() * tan(F9TiltCap()))).
}

set F9HLaw to "tgo".

function F9TArr {
    return max(1, F9TGo() - F9TGoH(F9AimFreeze)).
}

set F9TransH to 15 * F9Scale.
set F9TransMinH to 8.
set F9TransTol to 8.
set F9TransKeep to 45.
set F9TransMax to 8.
set F9TransTilt to 6.
set F9TransW to 0.5.
set F9TransVV to 0.5.
set F9TransOn to false.
set F9TransDone to false.
set F9TransT0 to 0.
set F9AccHV to V(0, 0, 0).
set F9LatAccHi to 8.
set F9TransMaxD to 40.
set F9TransVMax to 2.

set F9ZemEndH to F9SwitchAlt + 40 * F9Scale.
set F9HoldMaxD to 80.
set F9HoldVMax to 4.
set F9HoldW to 0.3.
set F9HoldLead to 1.
set F9TransH to -1.

function F9TZem {
    return max(1, F9TGoH(F9H()) - F9TGoH(F9ZemEndH)).
}

function F9AccH {
    parameter vh.
    local ah is V(0, 0, 0).
    if F9Guided() {
        local d is F9ToPad().
        if F9H() < F9ZemEndH {
            if ship:mass > 0 {
                set vh to vh + vxcl(up:vector, ship:facing:forevector) *
                    (ship:availablethrust * F9ThrV / ship:mass * F9HoldLead).
            }
            if d:mag > F9HoldMaxD {
                set ah to -vh * (2 * F9TransW).
            } else {
                local vd is d * F9HoldW.
                local vmx is max(1, min(F9HoldVMax, F9H() * 0.05)).
                if vd:mag > vmx set vd to vd:normalized * vmx.
                set ah to (vd - vh) * (2 * F9TransW).
            }
        } else {
            local t is F9TZem().
            set ah to d * (6 / t ^ 2) - vh * (4 / t).
        }
    } else {
        set ah to -vh / F9TauNow().
    }
    local lim is F9LatAccCmd().
    if F9H() > F9SwitchAlt set lim to max(lim, F9LatAccHi).
    if ah:mag > lim set ah to ah:normalized * lim.
    return ah.
}

function F9TransStep {
    if F9TransDone or not F9Guided() return.
    local h is F9H().
    if h > F9TransH return.
    local d is F9ToPad():mag.
    local vh is vxcl(up:vector, ship:velocity:surface):mag.
    if not F9TransOn {
        if h > F9TransMinH and d > F9TransTol and d < F9TransMaxD and F9DvLeft() > F9TransKeep + 20 {
            set F9TransOn to true.
            set F9TransT0 to time:seconds.
            print "  HOVER TRIM: to point " + round(d, 1) + " m".
            F9LandLog("TRANS start h" + round(h, 1) + " tgt" + round(d, 1) +
                      " hv" + round(vh, 1) + " dv" + round(F9DvLeft())).
        } else set F9TransDone to true.
        return.
    }
    local why is "".
    if d < F9TransTol and vh < 0.5 set why to "on point".
    else if time:seconds - F9TransT0 > F9TransMax set why to "timeout".
    else if h < F9TransMinH set why to "too low".
    else if F9DvLeft() < F9TransKeep set why to "reserve".
    if why <> "" {
        set F9TransOn to false.
        set F9TransDone to true.
        print "  trim done (" + why + "), to point " + round(d, 1) + " m".
        F9LandLog("TRANS end " + why + " h" + round(h, 1) + " tgt" + round(d, 1) +
                  " hv" + round(vh, 1) + " dv" + round(F9DvLeft())).
    }
}

function F9WantVel {
    local hv is V(0, 0, 0).
    if F9Guided() {
        local d is F9ToPad().
        if d:mag > 1 {
            if F9HLaw = "tgo" {
                local cap is max(F9LandVMin, F9H() * F9LandVPerM).
                set hv to d:normalized * min(cap, 2 * d:mag / F9TArr()).
            } else {
                local cap is min(F9LandVMax, max(F9LandVMin, F9H() * F9LandVPerM)).
                set hv to d:normalized *
                          min(cap, F9LandKappa * sqrt(2 * F9LatAccNow() * d:mag)).
            }
            if F9H() < F9AimFreeze or d:mag < F9AimDead set hv to V(0, 0, 0).
        }
    }
    return up:vector * F9WantVV() + hv.
}

function F9TauNow {
    return max(1, min(F9Tau, F9TGo() * 0.4)).
}

function F9ACmd {
    local vh is vxcl(up:vector, ship:velocity:surface).
    set F9AccHV to F9AccH(vh).
    local ev is up:vector * (F9WantVV() - ship:verticalspeed).
    return F9AccHV + ev / F9TauNow() + up:vector * (F9GLocal() + F9ProfDot()).
}

set F9TiltPerM to 0.3.
set F9TiltMin to 4.

function F9TiltCap {
    if F9TransOn return F9TransTilt.
    return max(F9TiltMin, min(F9MaxTilt, F9H() * F9TiltPerM)).
}

set F9BurnRetroVV to 1.

set F9DivV to 150.
set F9DivMinH to 30.
set F9DivTau to 3.
set F9DivAng to 4.
set F9DivMiss to 0.
set F9TermK to 0.5.
set F9TermLead to 1.5.
set F9TermW to 0.3.
set F9TermVMax to 1.

function F9SteerDir {
    parameter a.
    if ship:verticalspeed < -F9BurnRetroVV {
        local vs is ship:velocity:surface.
        set a to -vs.
        local h is F9H().
        if F9Guided() and F9BjOk and vs:mag < F9DivV and h > F9DivMinH and ship:mass > 0 {
            local miss is F9BjHv * F9BjK - F9BjD.
            if F9BjD:mag > 1 set F9DivMiss to vdot(miss, F9BjD:normalized).
            local al is -miss / (F9BjK * F9DivTau).
            local ta is max(1, ship:availablethrust * max(0.3, F9ThrV) / ship:mass).
            local lim is ta * tan(F9DivAng).
            if al:mag > lim set al to al:normalized * lim.
            set a to -vs:normalized * ta + al.
        }
        if h <= F9DivMinH and ship:mass > 0 {
            local ta is max(1, ship:availablethrust * max(0.3, F9ThrV) / ship:mass).
            local hvl is vxcl(up:vector, vs) +
                vxcl(up:vector, ship:facing:forevector) * (ta * F9TermLead).
            local vd is V(0, 0, 0).
            if F9Guided() {
                set vd to F9ToPad() * F9TermW.
                if vd:mag > F9TermVMax set vd to vd:normalized * F9TermVMax.
            }
            set a to up:vector * ta - (hvl - vd) * F9TermK.
        }
    }
    if a:mag < 0.01 return up:vector.
    local cap is F9TiltCap().
    if vAng(a, up:vector) <= cap return a:normalized.
    local ax is vcrs(up:vector, a).
    if ax:mag < 0.001 return up:vector.
    return up:vector * angleaxis(cap, ax:normalized).
}

set F9ThrCosMin to 0.35.

set F9ThrHSinMin to 0.1.
set F9ThrHVvK to 0.5.

function F9NeedThrust {
    parameter a.
    local cosUp is vdot(ship:facing:forevector, up:vector).
    if cosUp < F9ThrCosMin return 0.
    local needUp is vdot(a, up:vector).
    if needUp <= 0 return 0.
    local need is needUp / cosUp * ship:mass.
    if F9Mode = "rtls" and F9H() > F9SwitchAlt and ship:verticalspeed < F9ThrHVvK * F9WantVV() {
        local ahv is vxcl(up:vector, a).
        if ahv:mag > 0.1 {
            local sinH is vdot(ship:facing:forevector, ahv:normalized).
            if sinH > F9ThrHSinMin set need to max(need, ahv:mag / sinH * ship:mass).
        }
    }
    return need.
}

function F9SuicideNow {
    if ship:mass <= 0 or ship:availablethrust <= 0 return false.
    local aa is ship:availablethrust / ship:mass - F9GLocal().
    if aa <= 0.5 return true.
    local vv is abs(min(0, ship:verticalspeed)).
    return vv * vv / (2 * aa) > F9H() * 0.9.
}

function F9ThrCmd {
    parameter a.
    if ship:availablethrust <= 0 return 0.
    if F9SuicideNow() return 1.
    return max(0, min(1, F9NeedThrust(a) / ship:availablethrust)).
}

set F9ACmdV to up:vector * F9GLocal().
set F9SteerV to up:vector.
set F9ThrV to 0.

lock throttle to F9ThrV.
lock steering to lookdirup(F9SteerV, F9TopRef()).

set F9GearDone to false.
set F9HoverT0 to 0.
set F9NextPrint to 0.
until ship:status = "LANDED" or ship:status = "SPLASHED"
      or F9H() < 0.5 or F9AltAbovePad() < 1 {
    set F9LoopMax to max(F9LoopMax, time:seconds - F9LoopT).
    set F9LoopT to time:seconds.
    set F9DivertOn to F9Diverting().
    F9TransStep().
    set F9ACmdV to F9ACmd().
    if F9Guided() and F9H() > F9DivMinH and ship:velocity:surface:mag < F9DivV * 1.3 F9BjRun().
    set F9SteerV to F9SteerDir(F9ACmdV).
    set F9ThrV to F9ThrCmd(F9ACmdV).

    if time:seconds > F9NextPrint {
        set F9NextPrint to time:seconds + 0.5.
        print "  h=" + round(F9H(), 0) +
              "  vv=" + round(ship:verticalspeed, 1) +
              "/" + round(F9WantVV(), 1) +
              "  hv=" + round(vxcl(up:vector, ship:velocity:surface):mag, 1) +
              "  to target " + round(F9ToPad():mag, 0) +
              "  tilt=" + round(vAng(F9SteerV, up:vector), 0) +
              "/" + round(vAng(ship:facing:forevector, up:vector), 0) +
              "  thr=" + round(100 * throttle).
        F9LandLog("h" + round(F9H(), 1) +
                  " vv" + round(ship:verticalspeed, 1) +
                  "/" + round(F9WantVV(), 1) +
                  " hv" + round(vxcl(up:vector, ship:velocity:surface):mag, 1) +
                  " ah" + round(F9AccHV:mag, 2) +
                  " tgt" + round(F9ToPad():mag) +
                  " pred" + round(F9DivMiss, 1) +
                  " tick" + round(F9LoopMax, 2) +
                  " tilt" + round(vAng(F9SteerV, up:vector)) + "/" + round(vAng(ship:facing:forevector, up:vector)) +
                  " aoa" + round(vAng(ship:facing:forevector, -ship:velocity:surface:normalized)) +
                  " thr" + round(throttle, 2) +
                  " eng" + F9BurnMode +
                  (choose " TRIM" if F9DivertOn else "") +
                  (choose " TRANS" if F9TransOn else "")).
        set F9LoopMax to 0.
    }

    if F9BurnMode = 3 and ship:mass > 0 {
        if F9BurnEngines() = 1 {
            if F9ThreeDownT0 = 0 set F9ThreeDownT0 to time:seconds.
        }
        else set F9ThreeDownT0 to 0.

        if F9ThreeDownT0 > 0 and time:seconds - F9ThreeDownT0 > F9ThreeDownHold {
            F9SetEngineMode(1).
            set F9BurnMode to 1.
            set steeringmanager:maxstoppingtime to 1.
            print "  switching to 1 engine, h=" +
                  round(F9H(), 0) + " v=" +
                  round(ship:velocity:surface:mag, 0).
            F9LandLog("TO 1 ENG h" + round(F9H()) +
                      " v" + round(ship:velocity:surface:mag) +
                      " profile" + round(F9SwitchV())).
        }
    }

    if F9TransOn set F9HoverT0 to 0.
    else if F9DivertOn {
        if F9DivertT0 = 0 {
            set F9DivertT0 to time:seconds.
            print "  TRIM: miss " + round(F9ToPad():mag) +
                  " m, climbing.".
            F9LandLog("TRIM h" + round(F9H(), 1) +
                      " tgt" + round(F9ToPad():mag) +
                      " dv" + round(F9DvLeft())).
        }
        set F9HoverT0 to 0.
    }
    else if ship:verticalspeed > -2 {
        if F9HoverT0 = 0 set F9HoverT0 to time:seconds.
        if time:seconds - F9HoverT0 > F9HoverGrace and F9MinDesc = 0 {
            set F9MinDesc to F9NoHoverV.
            print "  HOVERING - forced descent " + F9NoHoverV + " m/s".
        }
        if time:seconds - F9HoverT0 > F9HoverGrace * 2 and F9H() < 5 {
            print "  HOVERING AT GROUND - counting as touchdown.".
            F9LandLog("HOVER h" + round(F9H(), 1) +
                      " vv" + round(ship:verticalspeed, 1) +
                      " dv" + round(F9DvLeft())).
            break.
        }
    }
    else set F9HoverT0 to 0.

    if not F9GearDone and F9H() < F9LegsAlt {
        F9LegsDeploy(true).
        set F9GearDone to true.
        print "  legs deployed at " + round(F9H(), 0) + " m".
        F9LandLog("LEGS h" + round(F9H(), 1)).
    }
    wait 0.02.
}

lock throttle to 0.
F9Mark("land").
set F9Phase to "landed".
local tdAl is 0.
local tdSd is 0.
local tdLt is vxcl(up:vector, F9TopLatch).
if F9Guided() and tdLt:mag > 0.3 {
    set tdLt to tdLt:normalized.
    set tdAl to vdot(F9ToPad(), tdLt).
    set tdSd to vdot(F9ToPad(), vcrs(up:vector, tdLt)).
}
F9LandLog("TOUCHDOWN vv" + round(ship:verticalspeed, 1) +
          " hv" + round(vxcl(up:vector, ship:velocity:surface):mag, 1) +
          " tilt" + round(vAng(ship:facing:forevector, up:vector)) +
          " short" + round(tdAl, 1) + " side" + round(tdSd, 1)).
wait 0.1.
set ship:control:pilotmainthrottle to 0.
unlock steering.
unlock throttle.
for e in ship:engines {
    if e:ignition e:shutdown.
}
set F9RcsGate to false.
rcs off.
sas on.

if F9Mode = "asds" {
    local t0 is time:seconds.
    wait until abs(ship:verticalspeed) < 0.2 or time:seconds - t0 > 6.
    F9LandLog("DECK radar" + round(alt:radar, 2) +
              " deck" + round(alt:radar - F9GearRadar, 2) +
              " sent" + round(F9AsdsDeck, 2)).
    print "  deck measured: surface " + round(alt:radar - F9GearRadar, 2) +
          " m, barge sent " + round(F9AsdsDeck, 2) + " m".
}

print " ".
print "=== LANDING ===".
if F9Guided() {
    local fwd is vxcl(up:vector,
                      F9GeoAlong(F9Pad, F9Azimuth, 100):position -
                      F9Pad:position):normalized.
    local landErr is -F9ToPadRaw().
    local along is vdot(fwd, landErr).
    print "  miss " + round(F9ToPadRaw():mag, 1) + " m from pad  (along " +
          round(along, 1) + ", side " +
          round(vdot(vcrs(up:vector, fwd), landErr), 1) + ")".
    print "  to aim point " + round(F9ToPad():mag, 1) + " m".
    print "  aim point was " + round(F9LngBias) + " m past the pad".
}
else print "  miss " + round(F9ToPad():mag, 1) + " m".
F9DragSave().
print "  touchdown: above pad " + round(F9AltAbovePad(), 1) +
      ", radar " + round(alt:radar, 1) +
      " (F9GearRadar " + round(F9GearRadar, 1) + ")".
print "  vertical " + round(ship:verticalspeed, 2) + " m/s".
print "  remaining " + round(F9DvLeft()) + " m/s (" + round(F9FuelPct(), 1) + "% tank)".

set F9TdGeo to ship:geoposition.
set F9TdRec to lexicon(
    "lat", F9TdGeo:lat, "lng", F9TdGeo:lng,
    "az", F9Azimuth, "mode", F9Mode,
    "plat", F9Pad:lat, "plng", F9Pad:lng, "off", F9PadOffAlong,
    "down", round(latlng(F9PadLat, F9PadLng):position:mag),
    "meco", F9Ev["meco"], "vv", round(ship:verticalspeed, 2),
    "m0", round(F9M0, 2), "mdv", F9MecoDv,
    "t", round(time:seconds)).
if F9MPad > 0 F9TdRec:add("mp", round(F9MPad, 2)).
if F9NatGeo:istype("GeoCoordinates") {
    F9TdRec:add("nlat", F9NatGeo:lat).
    F9TdRec:add("nlng", F9NatGeo:lng).
}
set F9TdHist to list().
set F9TdOld to F9AsdsRead().
if F9TdOld:haskey("flights") set F9TdHist to F9TdOld["flights"].
F9TdHist:add(F9TdRec).
until F9TdHist:length <= 10 { F9TdHist:remove(0). }
if F9AsdsWrite(lexicon("flights", F9TdHist, "last", F9TdRec)) {
    print "  touchdown point saved: " + round(F9TdGeo:lat, 4) + " / " +
          round(F9TdGeo:lng, 4) + ", " +
          round(F9TdRec["down"] / 1000, 1) + " km from launch pad".
} else {
    print "  no Archive connection - touchdown point not saved.".
}

wait 20.
