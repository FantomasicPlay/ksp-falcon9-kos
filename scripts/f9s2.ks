// =====================================================================
// f9s2.ks - вторая ступень Falcon 9: выход на орбиту.
//
// Запускать с компьютера ВТОРОЙ ступени (он в TE.F9.Fairing.Adapter).
// Скрипт можно запустить ещё на столе - он просто ждёт разделения и
// ничего не трогает, пока первая ступень работает.
//
//   RUN f9s2.        или AG9 через boot-файл
//
// Первой ступенью занимается f9s1.ks - это отдельный компьютер и отдельная
// задача. Файлы разделены намеренно: у ступеней разные цели, разное железо
// и ломаются они по-разному.
//
// ВАЖНО: KSP считает физику только для активного судна и всего, что ближе
// 22 км, а FMRS на Falcon 9 не работает - отыграть вторую ступень задним
// числом не выйдет. Значит после разделения приходится выбирать: та ступень,
// на которой ты не находишься, за 22 км выгрузится и её скрипт замрёт до
// возвращения. Скрипты это переживают - оба умеют подхватываться с середины,
// - но одновременно довести обе ступени до цели нельзя.
// =====================================================================

run once f9lib.

// ---------------------------------------------------------------------
// Настройки выведения. Высоты в метрах, множитель F9Scale приходит из
// f9lib по радиусу планеты - одна и та же ракета летает в стоке, KSRSS и
// RSS, и целевая орбита там отличается в разы.
// ---------------------------------------------------------------------
set F9Azimuth to 90.                 // курс, тот же что у первой ступени
// Цель - круговые 125 км, как просил Егор. Задана числом, а не надбавкой
// к атмосфере: прошлый вариант "граница + 70" давал в Sol quarter 150 x 145
// и зависел от сборки, а круг на 125 нужен конкретный.
//
// Проверка на вменяемость всё же нужна: в стоке атмосфера кончается на 14
// км, там 125 - нормальная орбита, а вот в сборке с атмосферой выше 120
// цель оказалась бы под ней. Тогда поднимаем до границы плюс 20 км.
set F9TargetAp to 125000.                   // целевой апогей
if F9TargetAp < body:atm:height + 20000 {
    set F9TargetAp to body:atm:height + 20000.
}
// Перигей целим на 2 км ниже апогея, а не в него. Ровно в апогей нельзя:
// пока двигатель работает, перигей поднимается, но одновременно растёт и
// апогей, и условие "перигей >= апогея" не наступит никогда - ступень
// сожгла бы всё топливо. Два километра на 125 - это эксцентриситет 0.0001,
// орбита круглая по любому счёту.
set F9TargetPe to F9TargetAp - 2000.
set F9InsAlt to F9TargetAp.
set F9GT0 to 0.
set F9GMode to "rtls".
set F9GIncl to abs(ship:latitude).
// Профиль выведения. До F9DirectMax км апогея - одним участком, как было.
// Выше - как настоящий Falcon: SECO-1 на круговую парковку F9ParkAlt (или
// ниже, если целевой перигей ниже), затем узлами подъём апогея и перигея
// (F9S2Profile после SECO). Сход S2 - по галочке, после отделения груза.
set F9DirectMax to 400.
set F9ParkAlt to 200.
set F9DeoWait to 300.
set F9Prof to "direct".
set F9FinAp to 0.
set F9FinPe to 0.

// Парковка только когда сразу выйти нельзя: перигей выше F9DirectMax
// (125x8946 выводится сразу, SECO в перигее), и только без списка орбит -
// со списком профиль задаёт он.
function F9ParkKm {
    parameter ap, pe.
    if (defined F9Ms) and F9Ms:length > 0 return -1.
    if min(ap, pe) <= F9DirectMax return -1.
    return max(min(min(ap, pe), F9ParkAlt), (body:atm:height + 20000) / 1000).
}

function F9S2ApplyCfg {
    parameter c.
    set F9Azimuth to c["az"].
    set F9TargetAp to max(c["ap"], c["pe"]) * 1000.
    set F9TargetPe to min(min(c["ap"], c["pe"]) * 1000, F9TargetAp - 2000).
    set F9InsAlt to choose F9TargetAp if F9TargetAp - F9TargetPe <= 2000 else F9TargetPe.
    set F9GT0 to c["t0"].
    set F9GMode to c["mode"].
    set F9GIncl to c["incl"].
    set F9FinAp to max(c["ap"], c["pe"]).
    set F9FinPe to min(c["ap"], c["pe"]).
    local pk is F9ParkKm(F9FinAp, F9FinPe).
    set F9Prof to choose "park" if pk > 0 else "direct".
    if F9Prof = "park" {
        set F9TargetAp to pk * 1000.
        set F9TargetPe to F9TargetAp - 2000.
        set F9InsAlt to F9TargetAp.
    }
}
F9S2ApplyCfg(F9CfgRead()).
// Обтекатель сбрасываем по ВЫСОТЕ - от 60 км. Раньше решал напор (0.002
// атм), а высота 40 * F9Scale была лишь нижней границей; порог по напору
// наступал заметно раньше шестидесяти, и створки уходили низко.
//
// Напор оставлен вторым условием, но уже мягким страховочным: если на 60 км
// воздух почему-то ещё плотный, ждём, пока он упадёт.
set F9FairingAlt to 60000.           // м, высота сброса обтекателя
set F9FairingQ to 0.002.             // страховка по напору

// ---------------------------------------------------------------------
// Железо второй ступени. Своё, отдельное от f9lib: там всё про первую.
// ---------------------------------------------------------------------

// Октавеб - признак того, что первая ступень ещё с нами. Проверяем
// динамически, а не один раз: весь смысл скрипта в том, чтобы дождаться
// момента, когда его не станет.
function F9S1Attached {
    for p in ship:parts {
        if p:hasmodule("ModuleTundraEngineSwitch") return true.
    }
    return false.
}

// Обтекатель - две половинки, у каждой ModuleDecouple. Ищем по имени, а
// не по модулю: ModuleDecouple есть и у межступенчатого отсека, и спутать
// их означало бы разделить ступени вместо сброса створок.
set F9Fairings to list().
for p in ship:partsnamedpattern("F9[._](Extended[._])?Fairing") {
    if p:hasmodule("ModuleDecouple") and not p:name:contains("Adapter") and
       p:uid <> core:part:uid F9Fairings:add(p).
}

function F9FairingJettison {
    local n is 0.
    for p in F9Fairings {
        local m is p:getmodule("ModuleDecouple").
        if m:hasevent("decouple") {
            m:doevent("decouple").
            set n to n + 1.
        }
    }
    return n.
}

// Двигатель второй ступени. После разделения он остаётся единственным.
// Двигатель второй ступени.
//
// Правило "первый движок, в имени которого нет S1" работало, пока наверху
// стоял обтекатель. С Crew Dragon оно ЛОМАЕТСЯ: у TE_18_DRAGONV2_POD есть
// свой ModuleEnginesFX - это SuperDraco системы аварийного спасения, 228 кН
// на монотопливе. В имени детали "S1" нет, list engines её возвращает, и
// какая из двух попадётся первой, зависит от порядка обхода дерева. То есть
// activate мог зажечь двигатели САС вместо Merlin Vacuum.
//
// Ищем по имени детали: у всех вариантов второй ступени оно содержит и S2,
// и Engine (TE.19.F9.S2.Engine, TE.19.F910.S2.Engine, TE.F1.S2.Engine).
//
// Запасное правило - на случай нестандартной сборки: движок, который НЕ
// работает на монотопливе. Это отсекает и SuperDraco, и Draco.
function F9S2Engine {
    list engines in es.
    for e in es {
        local nm is e:name:tolower.
        if nm:contains("s2") and nm:contains("engine") return e.
    }
    for e in es {
        local mono is false.
        for r in e:consumedresources:values {
            if r:name:tolower = "monopropellant" set mono to true.
        }
        if not mono and not e:name:contains("S1") return e.
    }
    return "false".
}

// Всё, что видит list engines - для проверки на столе. Если в списке
// окажется несколько кандидатов, выбранный виден отдельной строкой.
function F9EngineList {
    list engines in es.
    local out is "".
    for e in es {
        if out:length > 0 set out to out + "; ".
        set out to out + e:name.
    }
    if out:length = 0 return "no engines".
    return out.
}

// ---------------------------------------------------------------------
// Проверки.
// ---------------------------------------------------------------------
clearscreen.
// ---------------------------------------------------------------------
// Дальность физики.
//
// KSP считает физику только для того, что рядом с активным судном; всё
// дальше "пакуется" и летит по рельсам. А смотреть после разделения надо на
// ПЕРВУЮ ступень - её сажаем. Вторая при этом уходит вперёд и вверх, и на
// штатных 22 км её перестаёт считать физика ровно посреди выведения.
//
// Starship и Superheavy решают это через vessel:loaddistance - каждый
// поднимает СВОИ дистанции, чтобы не выпасть из симуляции, пока игрок
// смотрит на соседа (starship.ks, функция SetLoadDistances). Делаю так же.
//
// Порядок как у них: сначала unload/load, потом pack/unpack, с паузой между
// присвоениями - KSP применяет их не мгновенно.
function F9SetLoadDist {
    parameter d.

    if d = "default" {
        set ship:loaddistance:flying:unload to 22500.
        set ship:loaddistance:flying:load to 2250.
        wait 0.001.
        set ship:loaddistance:flying:pack to 25000.
        set ship:loaddistance:flying:unpack to 2000.
        wait 0.001.
        set ship:loaddistance:suborbital:unload to 15000.
        set ship:loaddistance:suborbital:load to 2250.
        wait 0.001.
        set ship:loaddistance:suborbital:pack to 10000.
        set ship:loaddistance:suborbital:unpack to 700.
        wait 0.001.
        set ship:loaddistance:orbit:unload to 2500.
        set ship:loaddistance:orbit:load to 2250.
        wait 0.001.
        set ship:loaddistance:orbit:pack to 550.
        set ship:loaddistance:orbit:unpack to 400.
        wait 0.001.
        return.
    }

    set ship:loaddistance:flying:unload to d.
    set ship:loaddistance:flying:load to d - 5000.
    wait 0.001.
    set ship:loaddistance:flying:pack to d - 2500.
    set ship:loaddistance:flying:unpack to d - 10000.
    wait 0.001.
    set ship:loaddistance:suborbital:unload to d.
    set ship:loaddistance:suborbital:load to d - 5000.
    wait 0.001.
    set ship:loaddistance:suborbital:pack to d - 2500.
    set ship:loaddistance:suborbital:unpack to d - 10000.
    wait 0.001.
    set ship:loaddistance:orbit:unload to d.
    set ship:loaddistance:orbit:load to d - 5000.
    wait 0.001.
    set ship:loaddistance:orbit:pack to d - 2500.
    set ship:loaddistance:orbit:unpack to d - 10000.
    wait 0.001.
    // Четвёртый диапазон - PRELAUNCH, с другими отступами (250/500/750).
    // Ровно как в starship.ks: SetLoadDistances выставляет четыре диапазона,
    // а не три. У нас его не было - это и было единственное расхождение.
    set ship:loaddistance:prelaunch:unload to d.
    set ship:loaddistance:prelaunch:load to d - 250.
    wait 0.001.
    set ship:loaddistance:prelaunch:pack to d - 500.
    set ship:loaddistance:prelaunch:unpack to d - 750.
    wait 0.001.
}

// 500 км. Хватает на всё выведение до круговых 125: дальше этого вторая
// ступень от места старта за время работы двигателя не уходит. Больше
// ставить незачем - каждый лишний километр это физика, которую машина
// считает впустую.
set F9RnEccOk to 0.01.
set F9RnIncOk to 0.15.
set F9RnIncWarn to 1.
set F9RnDir to V(0, 0, 1).
// Финальный подход на RCS: дальше F9RnAppFar вести нечем - там нужен перелёт,
// а не трансляция. Целевая скорость подхода = доля дистанции (F9RnAppK), то есть
// на 10 км летим 30 м/с (потолок), на 500 м - 25, на 100 м останавливаемся.
set F9RnAppFar to 50000.
set F9RnAppStop to 100.
set F9RnAppK to 0.05.
set F9RnAppVmax to 30.
set F9RnAppGain to 0.5.
set F9RnAppTmax to 1800.
set F9RnAppDir to V(0, 0, 1).
set F9GAbort to false.

set F9LoadDist to 1650000.

print "=== Falcon 9, second stage ===".
// Загрузчик после первой сборки ставит bootfilename на f9s2.ksm и дальше не
// сверяет борт с архивом: правки в архиве молча не попадают на летящую
// ступень. 18.09 так весь день летала утренняя сборка.
// Сравниваем без BOM и \r: архив и бортовой диск отдают один и тот же
// файл по-разному, и прямое сравнение кричало на свежей сборке.
if homeconnection:isconnected and exists("0:/f9s2.ks") and exists("1:/boot/f9s2.ks") {
    local sa is open("0:/f9s2.ks"):readall:string:replace(char(65279), ""):replace(char(13), "").
    local sb is open("1:/boot/f9s2.ks"):readall:string:replace(char(65279), ""):replace(char(13), "").
    if sa <> sb {
        print "!!! OLD BUILD ON BOARD - f9s2 in the Archive is newer.".
        print "!!! length: archive " + sa:length + ", on board " + sb:length + ".".
        print "!!! to update: runpath(" + char(34) + "0:/boot/f9s2.ks" + char(34) + ").".
        hudtext("F9 S2: OLD BUILD ON BOARD", 15, 2, 24, red, false).
    }
}
print "World: " + F9World + "  Scale " + F9Scale.
print "target: " + round(F9TargetAp / 1000) + " x " + round(F9TargetPe / 1000) + " km".
print "fairing: " + F9Fairings:length + " halves".
if F9Fairings:length = 0 print "  NO FAIRING HALVES FOUND - nothing to jettison".

// Какой двигатель выбран - печатаем на столе, а не выясняем в полёте.
// Зажигание не той детали на связке с Dragon означало бы запуск САС.
if F9S2Engine():istype("String") {
    print "SECOND STAGE ENGINE NOT FOUND".
} else {
    print "engine: " + F9S2Engine():name +
          "  (" + round(F9S2Engine():possiblethrust, 0) + " kN)".
}
print "  all engines: " + F9EngineList().

// Кто мы - определяем по СВОЕЙ детали, а не по наличию октавеба: на столе
// судно одно, и октавеб видят оба компьютера. Процессор второй ступени
// сидит в Fairing.Adapter, первой - в Interstage.
if core:part:name:contains("Interstage") {
    print " ".
    print "THIS IS THE FIRST STAGE COMPUTER - f9s1 should run here.".
    wait until false.
}

set F9GImg to "f9_img/".
set F9GMono to "Consolas".
set F9GAcc to rgb(0.31, 0.64, 1).
set F9GGray to rgb(0.54, 0.59, 0.64).
set F9GDim to rgb(0.43, 0.47, 0.53).
set F9GTxt to rgb(0.78, 0.82, 0.87).
set F9GYel to rgb(0.96, 0.71, 0).
set F9GRed to rgb(0.9, 0.28, 0.3).
set F9GReserve to 20.
set F9GainK to 0.8.
set F9PerfFile to "0:/f9perf.json".
set F9GCmd to "".
set F9GOk to false.
set F9GManOk to false.
set F9GMargin to 0.
set F9SepMass to 0.
set F9FairM0 to 0.
set F9FairM1 to 0.
set F9SecoMass to 0.
set F9GBurnT to 0.
set F9GBurnDv to 0.
set F9GBurnNode to "".
set F9BurnDir to v(0, 0, 0).
set F9GEnState to lexicon().
set F9GBgState to lexicon().
set F9GLampSets to list().
set F9GEng to F9S2Engine().
set F9GPadNames to list("Interstage", "39A", "39Base", "FSS", "Ghidorah").

set F9GKinds to lexicon(
    "tab", list("tab", "tab_hover", "tab_on", "tab_on", 10),
    "btn", list("btn", "btn_hover", "btn_on", "btn_on", 10),
    "blue", list("btn_on", "btn_hover", "btn_on", "btn_on", 10),
    "go", list("btn_go", "btn_go_hover", "btn_go_active", "btn_go_active", 12),
    "red", list("btn_red", "btn_red_hover", "btn_red_active", "btn_red_active", 12),
    "off", list("btn_off", "btn_off", "btn_off", "btn_off", 10)).

function F9Pad2 {
    parameter n.
    return choose "0" + n if n < 10 else "" + n.
}

function F9Hms {
    parameter s.
    local sec is max(0, floor(s)).
    return F9Pad2(floor(sec / 3600)) + ":" + F9Pad2(floor(mod(sec, 3600) / 60)) + ":" + F9Pad2(mod(sec, 60)).
}

function F9GSkin {
    parameter b, kind.
    local k is F9GKinds[kind].
    set b:style:normal:bg to F9GImg + k[0].
    set b:style:focused:bg to F9GImg + k[0].
    set b:style:hover:bg to F9GImg + k[1].
    set b:style:active:bg to F9GImg + k[2].
    set b:style:on:bg to F9GImg + k[3].
    set b:style:hover_on:bg to F9GImg + k[3].
    set b:style:active_on:bg to F9GImg + k[3].
    set b:style:focused_on:bg to F9GImg + k[3].
    set b:style:border:h to k[4].
    set b:style:border:v to k[4].
    local tc is white.
    if kind = "off" set tc to F9GDim.
    if kind = "tab" set tc to F9GGray.
    set b:style:normal:textcolor to tc.
    set b:style:focused:textcolor to tc.
    set b:style:hover:textcolor to choose tc if kind = "off" else white.
    set b:style:active:textcolor to white.
    set b:style:on:textcolor to white.
    set b:style:hover_on:textcolor to white.
    set b:style:active_on:textcolor to white.
    set b:style:focused_on:textcolor to white.
}

function F9GButton {
    parameter parent, txt, kind, h, fs.
    local b is parent:addbutton(txt).
    F9GSkin(b, kind).
    set b:style:height to h.
    set b:style:font to F9GMono.
    set b:style:fontsize to fs.
    set b:style:hstretch to true.
    set b:style:align to "center".
    return b.
}

function F9GEnable {
    parameter id, b, kind, en.
    if F9GEnState:haskey(id) and F9GEnState[id] = en return.
    set F9GEnState[id] to en.
    set b:enabled to en.
    F9GSkin(b, choose kind if en else "off").
}

function F9GLabel {
    parameter parent, txt, fs, col, mono is true, al is "left".
    local l is parent:addlabel(txt).
    set l:style:fontsize to fs.
    set l:style:textcolor to col.
    if mono set l:style:font to F9GMono.
    set l:style:align to al.
    return l.
}

function F9GBg {
    parameter id, w, img.
    if F9GBgState:haskey(id) and F9GBgState[id] = img return.
    set F9GBgState[id] to img.
    set w:style:bg to F9GImg + img.
}

function F9GNoBorder {
    parameter w.
    set w:style:border:h to 0.
    set w:style:border:v to 0.
    set w:style:padding:h to 0.
    set w:style:padding:v to 0.
}

function F9GLamp {
    parameter parent.
    local l is parent:addlabel("").
    set l:style:bg to F9GImg + "lamp_off".
    F9GNoBorder(l).
    set l:style:width to 12.
    set l:style:height to 12.
    set l:style:margin:top to 3.
    return l.
}

function F9GLamps {
    parameter parent.
    local rw is parent:addhlayout().
    local out is list().
    for nm in list("S1", "S2", "DRAGON", "COMMS") {
        if out:length > 0 rw:addspacing(-1).
        out:add(F9GLamp(rw)).
        F9GLabel(rw, nm, 10, F9GGray).
    }
    F9GLampSets:add(out).
}

function F9GDivider {
    parameter parent.
    local d is parent:addlabel("").
    set d:style:bg to F9GImg + "divider".
    F9GNoBorder(d).
    set d:style:height to 1.
    set d:style:hstretch to true.
    set d:style:margin:top to 6.
    set d:style:margin:bottom to 6.
}

function F9GBox {
    parameter parent, horiz.
    local b is choose parent:addhbox() if horiz else parent:addvbox().
    set b:style:bg to F9GImg + "box".
    set b:style:border:h to 12.
    set b:style:border:v to 12.
    set b:style:padding:h to 12.
    set b:style:padding:v to 10.
    set b:style:margin:bottom to 6.
    set b:style:hstretch to true.
    return b.
}

function F9GBar {
    parameter parent, w.
    local bb is parent:addhbox().
    set bb:style:bg to F9GImg + "bar_bg".
    F9GNoBorder(bb).
    set bb:style:border:h to 3.
    set bb:style:width to w.
    set bb:style:height to 6.
    set bb:style:margin:top to 6.
    local fl is bb:addlabel("").
    set fl:style:bg to F9GImg + "bar_blue".
    F9GNoBorder(fl).
    set fl:style:border:h to 3.
    set fl:style:height to 6.
    set fl:style:width to 1.
    set fl:style:margin:h to 0.
    set fl:style:margin:v to 0.
    return lexicon("fill", fl, "w", w, "col", "blue", "px", -1).
}

function F9GBarSet {
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
        set b["fill"]:style:bg to F9GImg + "bar_" + img.
    }
}

function F9GBarRow {
    parameter parent, nm.
    local rw is parent:addhlayout().
    local l is F9GLabel(rw, nm, 10, F9GGray).
    set l:style:width to 56.
    local b is F9GBar(rw, 290).
    local pc is F9GLabel(rw, "", 10, F9GTxt, true, "right").
    set pc:style:width to 40.
    set b["pct"] to pc.
    return b.
}

function F9GBarPct {
    parameter b, frac, col.
    F9GBarSet(b, frac, col).
    set b["pct"]:text to round(100 * max(0, min(1, frac))) + "%".
}

function F9GField {
    parameter parent, nm, val, unit.
    local rw is parent:addhlayout().
    local l is F9GLabel(rw, nm, 13, F9GTxt, false).
    set l:style:hstretch to true.
    local f is rw:addtextfield("" + val).
    set f:style:width to 118.
    set f:style:height to 30.
    set f:style:font to F9GMono.
    set f:style:fontsize to 13.
    set f:style:align to "right".
    set f:style:padding:h to 10.
    set f:style:border:h to 6.
    set f:style:border:v to 6.
    set f:style:normal:bg to F9GImg + "field".
    set f:style:hover:bg to F9GImg + "field".
    set f:style:focused:bg to F9GImg + "field_focus".
    set f:style:normal:textcolor to white.
    set f:style:focused:textcolor to white.
    local u is F9GLabel(rw, unit, 11, F9GGray).
    set u:style:width to 22.
    set u:style:margin:top to 9.
    return f.
}

function F9GFieldErr {
    parameter f, err.
    local img is choose "field_error" if err else "field".
    set f:style:normal:bg to F9GImg + img.
    set f:style:hover:bg to F9GImg + img.
    set f:style:normal:textcolor to choose F9GYel if err else white.
}

function F9GNum {
    parameter f, dflt.
    return f:text:replace(",", "."):trim:tonumber(dflt).
}

function F9GBig {
    parameter parent, cap.
    local b is F9GBox(parent, false).
    F9GLabel(b, cap, 9, F9GGray).
    local vl is F9GLabel(b, "—", 19, white).
    set vl:style:richtext to true.
    return vl.
}

function F9GStack {
    local out is list().
    local qu is list(core:part).
    until qu:length = 0 {
        local p is qu[0].
        qu:remove(0).
        local skip is out:contains(p).
        for nm in F9GPadNames {
            if p:name:contains(nm) set skip to true.
        }
        if not skip {
            out:add(p).
            if p:hasparent qu:add(p:parent).
            for ch in p:children { qu:add(ch). }
        }
    }
    return out.
}

function F9S2Fuel {
    local m is 0.
    local cap is 0.
    for t in ship:partsnamedpattern("F9[._]S2[._]Tank") {
        for rs in t:resources {
            if rs:name = "LiquidFuel" or rs:name = "Oxidizer" {
                set m to m + rs:amount * rs:density.
                set cap to cap + rs:capacity * rs:density.
            }
        }
    }
    return list(m, cap).
}

function F9GVe {
    if F9GEng:istype("String") return 3400.
    return max(1, F9GEng:vacuumisp) * constant:g0.
}

function F9GAttached {
    return F9GPhase = "pad" or F9GPhase = "count" or F9GPhase = "s1".
}

function F9GDvNow {
    local fu is F9S2Fuel().
    local m is choose F9GM2 if F9GAttached() else ship:mass.
    if m <= fu[0] return 0.
    return F9GVe() * ln(m / (m - fu[0])).
}

function F9GDragonOn {
    return ship:partsnamedpattern("DRAGONV2[._]POD"):length > 0.
}

function F9GPerfRead {
    local p is lexicon("fuel", 25.72, "sma", body:radius + 124200, "sI", 1, "mode", "rtls").
    if homeconnection:isconnected and exists(F9PerfFile) {
        local f is readjson(F9PerfFile).
        for k in f:keys { set p[k] to f[k]. }
    }
    return p.
}

function F9GRefDv {
    if F9GPerf:haskey("dv") return F9GPerf["dv"].
    if F9GM2 <= F9GPerf["fuel"] return 0.
    return F9GVe() * ln(F9GM2 / (F9GM2 - F9GPerf["fuel"])).
}

function F9S1Gain {
    parameter md.
    local ve1 is F9Isp * constant:g0.
    local rsv is F9MecoDvRtls.
    if md = "asds" set rsv to F9MecoDvAsds.
    if md = "splashdown" set rsv to F9MecoDvSplash.
    if md = "exp" set rsv to F9MecoDvExp.
    local mR is F9GM2 + F9GS1Dry * constant:e ^ (F9MecoDvRtls / ve1).
    local mM is F9GM2 + F9GS1Dry * constant:e ^ (rsv / ve1).
    return F9GainK * ve1 * ln(mR / mM).
}

function F9S2Need {
    parameter ap, pe, inc, md.
    local mu is body:mu.
    local aT is body:radius + (ap + pe) * 500.
    local aR is F9GPerf["sma"].
    local dvE is mu / 2 * (1 / aR - 1 / aT) / sqrt(mu / aR).
    local vRot is 2 * constant:pi * body:radius / body:rotationperiod * cos(ship:latitude).
    local dvRot is vRot * (F9GPerf["sI"] - F9LaunchSinAz(inc)).
    return F9GRefDv() + F9S1Gain(F9GPerf["mode"]) - F9S1Gain(md) + dvE + dvRot.
}

// ---------------------------------------------------------------------
// Страница PERF: сколько ракета выводит. Модель та же, что в F9S2Need
// (ракетное уравнение S2 + доля F9PfK выигрыша S1), но опорный расход не
// из заглушки 25.72 т, а подогнан по 26 выведениям из f9s2fuel.log:
// dv2 + 0.8*dv1 = 5100 м/с до круговой 125 км при наклонении 53.28.
// Точность около 0.4 т. Выше 125 км и за LEO - по Хоману, без полётов.
// За LEO считается так: парковка F9PfPark км, отлёт той же S2.
// ---------------------------------------------------------------------
// 5150, а не 5100: подгонка по журналу шла по грузовым полётам, где на 60 км
// сбрасываются створки (0.4 т). Без явного учёта сброса их выигрыш сидел
// внутри F9PfD и доставался Dragon, у которого створок нет. Теперь сброс
// считается в F9PfHave, и опорное число подогнано заново.
set F9PfD to 5150.
set F9PfFairM to 0.4.
// Сколько топлива S2 уходит до сброса створок на F9FairingAlt, т: по
// журналу разделение в rtls на 34 км, в asds на 44 км.
set F9PfFairFuel to lexicon("rtls", 5, "asds", 3, "exp", 2).
set F9PfK to 0.8.
set F9PfIncRef to 53.28.
set F9PfPark to 200.
set F9PfMode to "rtls".
set F9PfDirty to true.
set F9PfRows to list().
set F9GDeorbOn to true.
set F9GBudTxt to "".
set F9PfDeoOn to true.

// Две разные S2. Грузовая: переходник обтекателя 0.8 + створки 2x0.2 +
// 2 RCS. Под Dragon: без обтекателя, декуплер Dragon 0.2 + 4 RCS. Бак и
// MVac одни и те же. На столе всё берётся с живой ракеты, эти числа - когда
// ракеты под рукой нет.
function F9PfMass {
    local s1d is 27.3.
    local s1f is 112.
    local s2d is choose 7.65 if F9GHasDragon else 8.65.
    local s2f is 26.
    if F9GPhase = "pad" and F9GS1Dry > 0 {
        set s1d to F9GS1Dry.
        set s1f to max(0, F9Stage1Mass() - F9GS1Dry).
    }
    // Сухую S2 со стола не выводим: стек минус груз минус топливо дал 1 т
    // вместо 8.65 (часть железа S2 не попадает в стек или числится грузом),
    // и PERF показывал 13 т на LEO. Берём замеры.
    local fu is F9S2Fuel().
    if fu[1] > 0 set s2f to fu[1].
    return list(s1d, s1f, s2d, s2f).
}

function F9PfRes {
    parameter md.
    if md = "asds" return F9MecoDvAsds.
    if md = "splashdown" return F9MecoDvSplash.
    if md = "exp" return F9MecoDvExp.
    return F9MecoDvRtls.
}

// Что ракета даёт: dv S2 в вакууме (F9PfS2Dv) плюс доля F9PfK того, что
// S1 успела набрать.
function F9PfS2Dv {
    parameter m, pl, res.
    local m2 is m[2] + m[3] + pl.
    if F9Fairings:length > 0 and not F9GHasDragon {
        local fj is F9PfFairFuel["asds"].
        if res >= F9MecoDvRtls set fj to F9PfFairFuel["rtls"].
        if res <= F9MecoDvExp set fj to F9PfFairFuel["exp"].
        return F9GVe() * (ln(m2 / (m2 - fj)) + ln((m2 - fj - F9PfFairM) / (m[2] + pl - F9PfFairM))).
    }
    return F9GVe() * ln(m2 / (m[2] + pl)).
}

function F9PfHave {
    parameter m, pl, res.
    local ve1 is F9Isp * constant:g0.
    local m2 is m[2] + m[3] + pl.
    local dv1 is ve1 * ln((m[0] + m[1] + m2) / (m[0] * constant:e ^ (res / ve1) + m2)).
    return F9PfS2Dv(m, pl, res) + F9PfK * dv1.
}

function F9PfOk {
    parameter m, pl, res, need.
    return F9PfHave(m, pl, res) >= need.
}

function F9PfCap {
    parameter m, res, need.
    if not F9PfOk(m, 0, res, need) return 0.
    local a is 0.
    local b is 40.
    from { local i is 0. } until i >= 16 step { set i to i + 1. } do {
        local c is (a + b) / 2.
        if F9PfOk(m, c, res, need) set a to c.
        else set b to c.
    }
    return a.
}

function F9PfHoh {
    parameter r1, r2.
    local mu is body:mu.
    return sqrt(mu / r1) * (sqrt(2 * r2 / (r1 + r2)) - 1) +
           sqrt(mu / r2) * (1 - sqrt(2 * r1 / (r1 + r2))).
}

function F9PfNeedLeo {
    parameter hkm, inc.
    local r0 is body:radius + 125000.
    local rr is body:radius + hkm * 1000.
    local da is choose F9PfHoh(r0, rr) if rr >= r0 else -F9PfHoh(rr, r0).
    local vRot is 2 * constant:pi * body:radius / body:rotationperiod * cos(ship:latitude).
    return F9PfD + da + vRot * (F9LaunchSinAz(F9PfIncRef) - F9LaunchSinAz(inc)) + F9GReserve.
}

// Орбита ap x pe (км): выход на круговую pe плюс подъём апогея в перигее.
// Выведение одним участком, как летает f9s2, - энергия та же.
function F9PfNeedOrb {
    parameter ap, pe, inc.
    local mu is body:mu.
    local rp is body:radius + pe * 1000.
    local ra is body:radius + ap * 1000.
    return F9PfNeedLeo(pe, inc) + sqrt(mu * (2 / rp - 2 / (rp + ra))) - sqrt(mu / rp).
}

// Сход S2: в апогее опустить перигей до 0.4 атмосферы, как F9S2Deorbit.
// Галочка S2 DEORBIT снята - ноль.
function F9PfDeorb {
    parameter ap, pe.
    if not F9GDeorbOn return 0.
    return F9PfDeorbRaw(ap, pe).
}

function F9PfDeorbRaw {
    parameter ap, pe.
    local mu is body:mu.
    local ra is body:radius + ap * 1000.
    local rp is body:radius + pe * 1000.
    local rq is body:radius + body:atm:height * 0.4.
    if rp <= rq return 0.
    return sqrt(mu * (2 / ra - 2 / (ra + rp))) - sqrt(mu * (2 / ra - 2 / (ra + rq))).
}

// Импульсы после парковки: подъём апогея в перигее, подъём перигея в
// апогее. Для прямого профиля - пусто.
function F9PfBurns {
    parameter ap, pe.
    local pk is F9ParkKm(ap, pe).
    if pk < 0 return list().
    local mu is body:mu.
    local r1 is body:radius + pk * 1000.
    local ra is body:radius + max(ap, pe) * 1000.
    local rp is body:radius + min(ap, pe) * 1000.
    local b1 is sqrt(mu * (2 / r1 - 2 / (r1 + ra))) - sqrt(mu / r1).
    local b2 is 0.
    if rp > r1 + 2000 set b2 to sqrt(mu * (2 / ra - 2 / (rp + ra))) - sqrt(mu * (2 / ra - 2 / (r1 + ra))).
    return list(b1, b2).
}

// Полная потребность миссии без схода: выведение (прямо или на парковку)
// плюс импульсы после неё.
function F9PfNeedMission {
    parameter ap, pe, inc.
    local pk is F9ParkKm(ap, pe).
    if pk < 0 return F9PfNeedOrb(max(ap, pe), min(ap, pe), inc).
    local n is F9PfNeedLeo(pk, inc).
    for b in F9PfBurns(ap, pe) { set n to n + b. }
    return n.
}

// Профиль полёта - цепочка орбит. Орбита 1 - выведение (поля LAUNCH:
// Ap, Pe, наклонение). Дальше список F9Ms: каждая следующая орбита
// ap x pe, переход на неё - один узел в апсиде, которую новая орбита
// сохраняет (125x8946 -> 8946x8946: узел в апогее 8946). Если общей апсиды
// нет - два узла, через перигей. Наклонение задаёт только выведение.
// Хранится на Архиве (F9MsFile), исполняется F9S2Profile после SECO.
set F9MsFile to "0:/f9mission.json".
set F9Ms to list().
set F9MsTol to 5.

function F9MsLoad {
    if homeconnection:isconnected and exists(F9MsFile) {
        local f is readjson(F9MsFile).
        if f:istype("List") {
            F9Ms:clear().
            for e in f { if e:istype("Lexicon") and e:haskey("ap") and e:haskey("pe") F9Ms:add(e). }
        }
    }
}

// dv узла в апсиде rb (км): другая апсида oOld -> oNew.
function F9MsBurnDv {
    parameter rb, oOld, oNew.
    local rad is body:radius.
    local r1 is rad + rb * 1000.
    return abs(F9VisViva(r1, (r1 + rad + oNew * 1000) / 2) - F9VisViva(r1, (r1 + rad + oOld * 1000) / 2)).
}

// Узлы перехода с орбиты ra x rp на A x P. Каждый - lexicon: at (apo/peri),
// rb (км, где жжём), to (км, новая другая апсида), dv.
function F9MsLeg {
    parameter ra, rp, a, p.
    local out is list().
    if abs(a - ra) < F9MsTol and abs(p - rp) < F9MsTol return out.
    if abs(a - ra) < F9MsTol or abs(p - ra) < F9MsTol {
        local o is choose p if abs(a - ra) < F9MsTol else a.
        out:add(lexicon("at", "apo", "rb", ra, "to", o, "dv", F9MsBurnDv(ra, rp, o))).
        return out.
    }
    if abs(p - rp) < F9MsTol or abs(a - rp) < F9MsTol {
        local o is choose a if abs(p - rp) < F9MsTol else p.
        out:add(lexicon("at", "peri", "rb", rp, "to", o, "dv", F9MsBurnDv(rp, ra, o))).
        return out.
    }
    out:add(lexicon("at", "peri", "rb", rp, "to", a, "dv", F9MsBurnDv(rp, ra, a))).
    for b in F9MsLeg(max(rp, a), min(rp, a), a, p) { out:add(b). }
    return out.
}

function F9MsSave {
    if homeconnection:isconnected writejson(F9Ms, F9MsFile).
}

function F9MsText {
    parameter m.
    return round(max(m["ap"], m["pe"])) + " x " + round(min(m["ap"], m["pe"])) + " km".
}

function F9MsBurnText {
    parameter b.
    return (choose "apo " if b["at"] = "apo" else "peri ") + round(b["rb"]) + " -> " + round(b["to"]).
}

// Бюджет профиля: выведение на орбиту ap x pe (сама или через парковку,
// если перигей выше F9DirectMax и списка нет), затем орбиты списка по
// очереди. Всё в км, dv в м/с, без резерва. how - узлы каждой орбиты.
function F9MsPlan {
    parameter ap, pe, inc, deoOn.
    local rad is body:radius.
    local pk is F9ParkKm(ap, pe).
    local auto is list().
    local ra is max(ap, pe).
    local rp is min(ap, pe).
    local asc is 0.
    if pk < 0 set asc to F9PfNeedOrb(ra, rp, inc) - F9GReserve.
    else {
        set asc to F9PfNeedLeo(pk, inc) - F9GReserve.
        local bs is F9PfBurns(ap, pe).
        auto:add(lexicon("nm", "raise apoapsis " + round(ra) + " km", "dv", bs[0])).
        if bs[1] > 0 auto:add(lexicon("nm", "raise periapsis " + round(rp) + " km", "dv", bs[1])).
        else set rp to pk.
    }
    local low is false.
    local ms is list().
    local how is list().
    for m in F9Ms {
        local a is max(m["ap"], m["pe"]).
        local p is min(m["ap"], m["pe"]).
        local bs is F9MsLeg(ra, rp, a, p).
        local dv is 0.
        for b in bs { set dv to dv + b["dv"]. }
        ms:add(dv).
        how:add(bs).
        set ra to a.
        set rp to p.
        if rp * 1000 < body:atm:height + 20000 set low to true.
    }
    local deo is 0.
    if deoOn set deo to F9PfDeorbRaw(ra, rp).
    return lexicon("pk", pk, "asc", asc, "auto", auto, "ms", ms, "how", how, "deo", deo,
                   "ra", ra, "rp", rp, "inc", inc, "gone", false, "low", low).
}

function F9MsTotal {
    parameter pl.
    local n is pl["asc"] + pl["deo"] + F9GReserve.
    for b in pl["auto"] { set n to n + b["dv"]. }
    for d in pl["ms"] { set n to n + d. }
    return n.
}

// Импульс с парковки в эллипс с апоцентром ra.
function F9PfApo {
    parameter ra.
    local rr is body:radius + F9PfPark * 1000.
    return sqrt(body:mu / rr) * (sqrt(2 * ra / (rr + ra)) - 1).
}

// Импульс с парковки на гиперболу с избытком vinf.
function F9PfDep {
    parameter vinf.
    local rr is body:radius + F9PfPark * 1000.
    return sqrt(vinf ^ 2 + 2 * body:mu / rr) - sqrt(body:mu / rr).
}

// Избыток скорости для перелёта по Хоману к планете pl.
function F9PfVinf {
    parameter pl.
    local sn is body:body.
    local r1 is body:orbit:semimajoraxis.
    local r2 is pl:orbit:semimajoraxis.
    return abs(sqrt(sn:mu / r1) * (sqrt(2 * r2 / (r1 + r2)) - 1)).
}

function F9PfTargets {
    local out is list().
    for h in list(150, 200, 300, 400, 600, 1000, 2000) {
        out:add(lexicon("nm", h + " km", "leo", true, "h", h, "dv", 0)).
    }
    local rg is (body:mu * body:rotationperiod ^ 2 / (4 * constant:pi ^ 2)) ^ (1 / 3).
    out:add(lexicon("nm", "GTO", "leo", false, "h", 0, "dv", F9PfApo(rg), "ap", (rg - body:radius) / 1000, "tra", rg)).
    for nm in list("Moon", "Luna") {
        if bodyexists(nm) and body(nm):body = body {
            local rm is body(nm):orbit:semimajoraxis.
            out:add(lexicon("nm", "MOON", "leo", false, "h", 0, "dv", F9PfApo(rm), "tra", rm)).
        }
    }
    out:add(lexicon("nm", "ESCAPE", "leo", false, "h", 0, "dv", F9PfDep(0), "vinf", 0)).
    if body:hasbody {
        for nm in list("Mercury", "Venus", "Mars", "Jupiter", "Saturn") {
            if bodyexists(nm) and body(nm):body = body:body {
                local vi is F9PfVinf(body(nm)).
                out:add(lexicon("nm", nm:toupper, "leo", false, "h", 0, "dv", F9PfDep(vi), "vinf", vi)).
            }
        }
    }
    return out.
}

function F9PfCalc {
    set F9PfDirty to false.
    set F9PfMode to choose F9GForce if F9GForce <> "" else (choose F9GMode if F9GMode <> "" else "exp").
    local m is F9PfMass().
    local inc is F9GNum(F9GFInc, F9GCfg0["incl"]).
    local res is F9PfRes(F9PfMode).
    local nPark is F9PfNeedLeo(F9PfPark, inc).
    local caps is list().
    local top is 0.1.
    for rr in F9PfRows {
        local need is choose F9PfNeedMission(rr["h"], rr["h"], inc) + F9PfDeorb(rr["h"], rr["h"]) if rr["leo"] else nPark + rr["dv"].
        if rr:haskey("ap") set need to need + F9PfDeorb(rr["ap"], F9PfPark).
        local c is F9PfCap(m, res, need).
        caps:add(c).
        set top to max(top, c).
    }
    from { local i is 0. } until i >= F9PfRows:length step { set i to i + 1. } do {
        local rr is F9PfRows[i].
        local c is caps[i].
        local col is choose "green" if c >= F9GPayload else "yellow".
        F9GBarSet(rr["bar"], c / top, col).
        set rr["val"]:text to (choose "—" if c <= 0 else round(c, 1) + " t").
        set rr["val"]:style:textcolor to choose F9GTxt if c >= F9GPayload else F9GYel.
    }
    F9PfMission().
    set F9PfHead:text to (choose "S2 DRAGON" if F9GHasDragon else "S2 FAIRING") + " · payload now " + round(F9GPayload, 2) + " t · incl " + round(inc, 1) +
        "° · S1 " + round(m[0], 1) + "+" + round(m[1], 1) + " t · S2 " + round(m[2], 1) + "+" + round(m[3], 1) + " t".
}

// Итог на PLAN: орбита 1 - поля выведения, дальше список орбит, сход S2 и
// возврат - те же переключатели на этой же вкладке. Модель та же, что меню.
function F9PfMission {
    local m is F9PfMass().
    local a0 is F9GNum(F9GFAp, -1).
    local p0 is F9GNum(F9GFPe, -1).
    local ap is max(a0, p0).
    local pe is min(a0, p0).
    local inc is F9GNum(F9GFInc, -999).
    local res is F9PfRes(F9PfMode).
    local lat is abs(ship:latitude).
    set F9PfDeoOn to F9GDeorbOn.
    set F9MsOrb1:text to "1  " + round(ap) + " x " + round(pe) + " km · " + round(inc, 1) + "° · ascent".
    local err is "".
    if inc < lat - 0.05 or inc > 180 - lat + 0.05 set err to "inclination " + round(lat, 1) + "…" + round(180 - lat, 1) + "°".
    if pe < 0 or pe * 1000 < body:atm:height + 20000 set err to "periapsis inside atmosphere".
    if err <> "" {
        F9MsDraw(lexicon()).
        set F9PfOut:text to "".
        set F9PfOutMax:text to "• " + err.
        set F9PfOutMax:style:textcolor to F9GRed.
        return.
    }
    local pl is F9MsPlan(ap, pe, inc, F9PfDeoOn).
    F9MsDraw(pl).
    local need is F9MsTotal(pl).
    local have is F9PfHave(m, F9GPayload, res).
    local cap is F9PfCap(m, res, need).
    local d2 is F9PfS2Dv(m, F9GPayload, res).
    local l125 is F9PfNeedLeo(125, inc) - F9GReserve.
    local c125 is l125 - (have - d2).
    local lns is list().
    lns:add("S2 vacuum dv " + round(d2) + " m/s (payload " + round(F9GPayload, 2) + " t)").
    lns:add("S2 ascent to 125 km (" + F9PfMode:toupper + ")  -" + round(c125) + "  → left " + round(d2 - c125)).
    if pl["pk"] < 0 lns:add("125 → " + round(ap) + "x" + round(pe) + " km  " + (choose "+" if pl["asc"] >= l125 else "") + round(pl["asc"] - l125) + " m/s").
    else lns:add("125 → parking " + round(pl["pk"]) + " km  " + (choose "+" if pl["asc"] >= l125 else "") + round(pl["asc"] - l125) + " m/s").
    for b in pl["auto"] { lns:add(b["nm"] + "  +" + round(b["dv"]) + " m/s"). }
    local sm is 0.
    for d in pl["ms"] { set sm to sm + d. }
    local nb is 0.
    for h in pl["how"] { set nb to nb + h:length. }
    if F9Ms:length > 0 lns:add("orbits 2.." + (F9Ms:length + 1) + ", burns " + nb + "  +" + round(sm) + " m/s").
    if F9PfDeoOn lns:add("S2 deorbit  +" + round(pl["deo"]) + " m/s").
    lns:add("reserve  +" + F9GReserve + " m/s").
    lns:add("after 125 km need " + round(need - l125) + " · left " + round(d2 - c125) + " m/s").
    lns:add("final orbit " + round(pl["ra"]) + "x" + round(pl["rp"]) + " km, incl " + round(pl["inc"], 1) + "°").
    if pl["low"] lns:add("! periapsis inside atmosphere in the chain").
    set F9PfOut:text to lns:join(char(10)).
    set F9PfOutMax:text to "MAX " + round(cap, 2) + " t · " + F9PfMode:toupper + " · margin " + round(have - need) + " m/s".
    set F9PfOutMax:style:textcolor to choose F9GAcc if have >= need else F9GYel.
}

// Строки списка перерисовываются из F9GTick (через F9PfDirty), не из
// onclick: кнопка удаления только правит F9Ms.
function F9MsDraw {
    parameter pl.
    F9MsBox:clear().
    if F9Ms:length = 0 {
        F9GLabel(F9MsBox, "no more orbits - ascent only", 10, F9GGray).
        return.
    }
    from { local i is 0. } until i >= F9Ms:length step { set i to i + 1. } do {
        local rw is F9MsBox:addhlayout().
        local l is F9GLabel(rw, (i + 2) + "  " + F9MsText(F9Ms[i]), 11, F9GTxt).
        set l:style:hstretch to true.
        local dtx is "".
        if pl:haskey("ms") {
            local bt is list().
            for b in pl["how"][i] { bt:add(F9MsBurnText(b)). }
            set dtx to (choose "no burn" if bt:length = 0 else bt:join(" · ")) + "  +" + round(pl["ms"][i]) + " m/s".
        }
        local dl is F9GLabel(rw, dtx, 10, F9GGray, true, "right").
        set dl:style:width to 220.
        local b is F9GButton(rw, "X", "btn", 22, 10).
        set b:style:hstretch to false.
        set b:style:width to 26.
        F9MsDelBtn(b, i).
    }
}

function F9MsDelBtn {
    parameter b, idx.
    set b:onclick to {
        if F9GPhase <> "pad" return.
        F9Ms:remove(idx).
        F9MsSave().
        set F9PfDirty to true.
    }.
}

// Режим возврата обычно выбирается сам - берётся первый, на который хватает
// топлива, то есть почти всегда RTLS. Баржа при этом недостижима: она стоит
// в списке ниже. Поэтому в меню есть принудительный выбор, кнопка в строке
// RECOVERY. Пустая строка - авто.
set F9GForce to "".
set F9GForceList to list("", "rtls", "asds", "exp").

function F9GPickMode {
    parameter ap, pe, inc.
    local cap is F9GDvNow().
    local lst is list("rtls", "asds", "exp").
    if F9GForce <> "" set lst to list(F9GForce).
    // Бюджет тот же, что на PLAN: dv S2 в вакууме минус расход S2 на выход
    // на 125 км в этом режиме, остаток против всего, что после 125 км.
    local m is F9PfMass().
    local pl is F9MsPlan(ap, pe, inc, F9GDeorbOn).
    local nAll is F9MsTotal(pl).
    local l125 is F9PfNeedLeo(125, inc) - F9GReserve.
    for md in lst {
        local hv is F9PfHave(m, F9GPayload, F9PfRes(md)).
        local d2 is F9PfS2Dv(m, F9GPayload, F9PfRes(md)).
        set F9GMargin to hv - nAll.
        set F9GBudTxt to md:toupper + " · S2 vac " + round(d2) + " − to 125 km " + round(l125 - (hv - d2)) +
            " = left " + round(hv - l125) + " · after 125 km need " + round(nAll - l125) + " m/s".
        if F9GMargin >= 0 return md.
    }
    return "".
}

function F9GFieldsOn {
    parameter en.
    set F9GFAp:enabled to en.
    set F9GFPe:enabled to en.
    set F9GFInc:enabled to en.
    set F9GFLan:enabled to en.
}

function F9GValidate {
    if F9GPhase <> "pad" return.
    local ap is F9GNum(F9GFAp, -1).
    local pe is F9GNum(F9GFPe, -1).
    local inc is F9GNum(F9GFInc, -999).
    local lat is abs(ship:latitude).
    local errs is list().
    local bad is ap < 0 or pe < 0.
    if bad errs:add("enter numbers").
    local lo is min(ap, pe).
    local hi is max(ap, pe).
    local peBad is not bad and lo * 1000 < body:atm:height + 20000.
    if peBad errs:add("periapsis inside atmosphere").
    if not bad and F9Ms:length > 0 and lo > F9DirectMax errs:add("orbit 1 Pe > " + F9DirectMax + " km: raise it with + ORBIT").
    local incBad is inc < lat - 0.05 or inc > 180 - lat + 0.05.
    if incBad errs:add("inclination " + round(lat, 1) + "…" + round(180 - lat, 1) + "°").
    F9GFieldErr(F9GFAp, ap < 0).
    F9GFieldErr(F9GFPe, pe < 0 or peBad).
    local lanv is F9GNum(F9GFLan, -1).
    local lanBad is lanv > 360.
    if lanBad errs:add("RAAN 0…360°, −1 = off").
    F9GFieldErr(F9GFInc, incBad).
    F9GFieldErr(F9GFLan, lanBad).
    set F9GMode to "".
    if errs:length = 0 {
        set F9GMode to F9GPickMode(hi, lo, inc).
        if F9GMode = "" {
            if F9GForce = "" errs:add("not enough S2 propellant").
            else errs:add("not enough S2 propellant for " + F9GForce).
            errs:add("short ~" + round(-F9GMargin) + " m/s · payload " + round(F9GPayload, 1) + " t").
        }
    }
    local pln is list("1  " + round(hi) + " x " + round(lo) + " km · " + round(inc, 1) + "°" +
        (choose " · RAAN " + round(lanv, 1) + "°" if lanv >= 0 else "") + " · ascent").
    from { local i is 0. } until i >= F9Ms:length step { set i to i + 1. } do {
        pln:add((i + 2) + "  " + F9MsText(F9Ms[i])).
    }
    pln:add("recovery " + (choose "—" if F9GMode = "" else F9GMode:toupper) + (choose " (auto)" if F9GForce = "" else "") +
        " · S2 " + (choose "deorbit" if F9GDeorbOn else "left in orbit")).
    set F9GPlanL:text to pln:join(char(10)).
    set F9PfDirty to true.
    set F9GOk to errs:length = 0.
    set F9GBudL:text to F9GBudTxt.
    set F9GDeoVal:text to choose "DEORBIT · " + round(F9PfDeorb(hi, lo)) + " m/s" if F9GDeorbOn else "LEFT IN ORBIT".
    set F9GDeoBtn:text to choose "ON" if F9GDeorbOn else "OFF".
    F9GBg("deolamp", F9GDeoLamp, choose "lamp_green" if F9GDeorbOn else "lamp_yellow").
    if F9GOk {
        set F9GWarn0:text to "PAYLOAD " + round(F9GPayload, 1) + " t · S2 MARGIN ~" + round(F9GMargin) + " m/s".
        set F9GWarn0:style:textcolor to F9GGray.
    } else {
        set F9GWarn0:text to "• " + errs:join(" · ").
        set F9GWarn0:style:textcolor to F9GRed.
    }
    set F9PfErr:text to choose "" if F9GOk else F9GWarn0:text.
    local rv is "—".
    local rl is "off".
    if F9GMode = "rtls" {
        set rv to "RTLS · LZ-1".
        set rl to "green".
    }
    if F9GMode = "asds" {
        set rv to "ASDS · DRONESHIP".
        set rl to "green".
    }
    if F9GMode = "splashdown" {
        set rv to "SEA · SPLASHDOWN".
        set rl to "yellow".
    }
    if F9GMode = "exp" {
        set rv to "EXP · EXPENDABLE".
        set rl to "red".
    }
    set F9GRetVal:text to rv.
    F9GBg("retlamp", F9GRetLamp, "lamp_" + rl).
    F9GEnable("go", F9GGo, "go", F9GOk).
}

function F9GCycleMode {
    if F9GPhase <> "pad" return.
    local i is F9GForceList:find(F9GForce) + 1.
    if i >= F9GForceList:length set i to 0.
    set F9GForce to F9GForceList[i].
    set F9GRetBtn:text to choose "AUTO" if F9GForce = "" else F9GForce:toupper.
    F9GValidate().
}

function F9GWinTgt {
    if not hastarget return false.
    if not target:istype("Vessel") and not target:istype("Body") return false.
    if target:body <> ship:body return false.
    return true.
}

function F9GRnUpdate {
    parameter orb.
    F9GEnable("rnplane", F9GRnPlane, "btn", orb and F9RnTgt()).
    F9GEnable("rngo", F9GRnGo, "blue", orb and F9RnTgt()).
    F9GEnable("rnapp", F9GRnApp, "btn", orb and F9RnTgt()).
    if not F9RnTgt() {
        set F9GRnVal:text to "NO TARGET".
        F9GBg("rnlamp", F9GRnLamp, "lamp_off").
        return.
    }
    local di is F9RnRelInc().
    set F9GRnVal:text to F9GKm(target:distance) + " · phase " +
        round(F9RnPhase()) + "° · plane " + round(di, 2) + "°".
    local lm is "lamp_yellow".
    if di > F9RnIncWarn set lm to "lamp_red".
    if target:distance < 2000 set lm to "lamp_green".
    F9GBg("rnlamp", F9GRnLamp, lm).
}

function F9GBrgUpdate {
    if F9GMode <> "asds" and F9GForce <> "asds" {
        set F9GBrgVal:text to "not needed".
        F9GBg("brglamp", F9GBrgLamp, "lamp_off").
        return.
    }
    local a is F9AsdsRead().
    if not (a:haskey("lat") and a:haskey("lng")) {
        set F9GBrgVal:text to "NO POINT".
        F9GBg("brglamp", F9GBrgLamp, "lamp_off").
        return.
    }
    if not (a:haskey("blat") and a:haskey("blng")) {
        set F9GBrgVal:text to "POINT SENT · SILENT".
        F9GBg("brglamp", F9GBrgLamp, "lamp_red").
        return.
    }
    local off is (latlng(a["lat"], a["lng"]):position -
                  latlng(a["blat"], a["blng"]):position):mag.
    local age is 9999.
    if a:haskey("bt") set age to time:seconds - a["bt"].
    local rd is F9AsdsOnSt(a, off).
    local dk is 0.
    if a:haskey("deck") set dk to a["deck"].
    if age > F9GBrgStale {
        set F9GBrgVal:text to "NO LINK · data age " + round(age / 3600, 1) + " h · run f9asog".
        F9GBg("brglamp", F9GBrgLamp, "lamp_red").
        return.
    }
    local bv is "".
    if a:haskey("bv") and not rd set bv to " · speed " + round(a["bv"], 1) + " m/s".
    set F9GBrgVal:text to (choose "ON STATION · from point " if rd else "NOT ON STATION · to point ") +
        round(off) + " m" + bv + " · deck " + round(dk, 1) +
        (choose " · pre-revert" if age < -5 else " · " + round(age) + " s").
    local lm is "lamp_yellow".
    if age > F9GBrgStale set lm to "lamp_red".
    else if rd and age >= -5 set lm to "lamp_green".
    F9GBg("brglamp", F9GBrgLamp, lm).
}

function F9GWinUpdate {
    local inc is 0.
    local lan is 0.
    if F9GWinTgt() {
        if F9GPhase = "pad" and target:name <> F9GTgtName F9GWinTake().
        set inc to target:orbit:inclination.
        set lan to target:orbit:lan.
    } else {
        set lan to F9GNum(F9GFLan, -1).
        set inc to F9GNum(F9GFInc, -1).
        if lan < 0 and inc >= 0 {
            local dd is F9PlaneDelta(inc).
            if dd > -900 {
                set F9GWinVal:text to "NOW Ω" +
                    round(mod(F9SiteRa() - dd + 720, 360)) + " · DESCΩ" +
                    round(mod(F9SiteRa() + dd - 180 + 720, 360)).
                F9GBg("winlamp", F9GWinLamp, "lamp_off").
                return.
            }
        }
        if lan < 0 or inc < 0 {
            set F9GWinVal:text to "NO PLANE".
            F9GBg("winlamp", F9GWinLamp, "lamp_off").
            return.
        }
    }
    local ta is F9WindowSec(inc, lan, true).
    local td is F9WindowSec(inc, lan, false).
    if ta < 0 {
        set F9GWinVal:text to round(inc, 1) + "° BELOW LATITUDE".
        F9GBg("winlamp", F9GWinLamp, "lamp_red").
        return.
    }
    local asc is ta <= td.
    local tw is td.
    if asc set tw to ta.
    set F9GWinVal:text to F9Hms(tw) + " · " + round(inc, 1) + "° · " +
        (choose "ASC" if asc else "DESC") +
        " az" + round(F9WindowAz(inc, F9InsAlt, asc)).
    local lm is "lamp_yellow".
    if tw < 120 set lm to "lamp_green".
    F9GBg("winlamp", F9GWinLamp, lm).
}

function F9GWinTake {
    if F9GPhase <> "pad" or not F9GWinTgt() return.
    set F9GFInc:text to "" + round(target:orbit:inclination, 2).
    set F9GFLan:text to "" + round(target:orbit:lan, 2).
    set F9GTgtName to target:name.
    F9GValidate().
}

// Кнопки PLAN. SAVE PLAN пишет план в f9cfg.json (поля, возврат, сход;
// орбиты списка и так в f9mission.json) - при возврате к ракете меню
// поднимается с ним. SEND BARGE POINT отдаёт курс первой ступени, та
// считает точку (F9AsdsSetup) и пишет её барже. Точка зависит только от
// курса, хватает ли топлива на ASDS - не важно.
function F9GIncOk {
    local inc is F9GNum(F9GFInc, -999).
    local lat is abs(ship:latitude).
    return inc >= lat - 0.05 and inc <= 180 - lat + 0.05.
}

function F9GPlanSave {
    if F9GPhase <> "pad" return.
    if not F9GIncOk() {
        set F9PfBtnMsg:text to "• inclination out of range - not saved".
        return.
    }
    local c is F9GLaunchCfg()[0].
    set c["mode"] to choose F9GMode if F9GMode <> "" else (choose F9GForce if F9GForce <> "" else "rtls").
    F9CfgWrite(c).
    F9MsSave().
    set F9PfBtnMsg:text to "plan saved · " + round(c["ap"]) + " x " + round(c["pe"]) + " km · " +
        round(c["incl"], 1) + "° · course " + round(c["az"], 1) + " · " + c["mode"]:toupper.
    print "plan saved to " + F9CfgFile.
}

function F9GAsdsPub {
    if F9GPhase <> "pad" return.
    if F9GS1Cpu:istype("String") {
        set F9PfBtnMsg:text to "• S1 CPU not found".
        return.
    }
    if not F9GIncOk() {
        set F9PfBtnMsg:text to "• inclination out of range".
        return.
    }
    local c is F9GLaunchCfg()[0].
    set c["mode"] to "asds".
    F9GS1Cpu:connection:sendmessage(lexicon("cmd", "asds", "cfg", c)).
    set F9PfBtnMsg:text to "barge point requested · course " + round(c["az"], 1) + " - see S1 terminal".
    print "barge: point requested, heading " + round(c["az"], 1).
}

function F9GOnGo {
    F9GValidate().
    if F9GPhase <> "pad" or not F9GOk return.
    if F9GS1Cpu:istype("String") {
        set F9GWarn0:text to "• S1 CPU not found".
        set F9GWarn0:style:textcolor to F9GRed.
        return.
    }
    local lc is F9GLaunchCfg().
    local c is lc[0].
    local asc is lc[1].
    local waitw is lc[2].
    local inc is c["incl"].
    local lanv is c["lan"].
    set c["t0"] to time:seconds + max(max(10, c["count"]), waitw).
    F9GOnGoSend(c, asc, waitw, inc, lanv).
}

function F9GLaunchCfg {
    local ap is F9GNum(F9GFAp, 0).
    local pe is F9GNum(F9GFPe, 0).
    local inc is F9GNum(F9GFInc, 0).
    local c is F9CfgRead().
    set c["ap"] to max(ap, pe).
    set c["pe"] to min(ap, pe).
    set c["incl"] to inc.
    local lanv is F9GNum(F9GFLan, -1).
    set c["lan"] to lanv.
    local asc is true.
    local waitw is 0.
    if lanv >= 0 {
        local ta is F9WindowSec(inc, lanv, true).
        local td is F9WindowSec(inc, lanv, false).
        if ta >= 0 {
            set asc to ta <= td.
            set waitw to td.
            if asc set waitw to ta.
        }
    }
    local pkw is F9ParkKm(c["ap"], c["pe"]).
    set c["az"] to F9WindowAz(inc, (choose pkw if pkw > 0 else c["pe"]) * 1000, asc).
    set c["mode"] to F9GMode.
    set c["force"] to F9GForce.
    set c["deo"] to F9GDeorbOn.
    return list(c, asc, waitw).
}

function F9GOnGoSend {
    parameter c, asc, waitw, inc, lanv.
    F9CfgWrite(c).
    F9S2ApplyCfg(c).
    set F9GPhase to "count".
    F9GFieldsOn(false).
    F9GEnable("go", F9GGo, "go", false).
    F9GS1Cpu:connection:sendmessage(lexicon("cmd", "go", "t0", F9GT0, "cfg", c)).
    print "LAUNCH: " + c["ap"] + " x " + c["pe"] + " km, " + inc + " deg, heading " +
          round(c["az"], 1) + ", recovery " + F9GMode.
    if waitw > 0 {
        print "  window in " + F9Hms(waitw) + ", node " +
              (choose "ascending" if asc else "descending") +
              ", Ω " + round(lanv, 2).
    } else if lanv >= 0 {
        print "  NO WINDOW: inclination below the pad latitude".
    }
}

function F9GOnCancel {
    if F9GPhase = "burn" {
        set F9GAbort to true.
        print "ABORT BURN".
        return.
    }
    if F9GPhase <> "count" or time:seconds > F9GT0 - 1 return.
    F9GS1Cpu:connection:sendmessage(lexicon("cmd", "abort")).
    set F9GPhase to "pad".
    F9GFieldsOn(true).
    F9GValidate().
    print "ABORT LAUNCH".
}

function F9VisViva {
    parameter rr, a.
    return sqrt(body:mu * max(0, 2 / rr - 1 / a)).
}

function F9ManDv {
    parameter apN, peN.
    local r1 is body:radius + ship:orbit:periapsis.
    local r2 is body:radius + apN.
    local r3 is body:radius + peN.
    local dv1 is abs(F9VisViva(r1, (r1 + r2) / 2) - F9VisViva(r1, ship:orbit:semimajoraxis)).
    local dv2 is abs(F9VisViva(r2, (r2 + r3) / 2) - F9VisViva(r2, (r1 + r2) / 2)).
    return dv1 + dv2.
}

function F9GValidate1 {
    local ap is F9GNum(F9GFNAp, -1).
    local pe is F9GNum(F9GFNPe, -1).
    local hi is max(ap, pe).
    local lo is min(ap, pe).
    local err is "".
    local dv is 0.
    local lft is 0.
    if ap < 0 or pe < 0 set err to "enter numbers".
    else if lo * 1000 < body:atm:height + 10000 set err to "periapsis inside atmosphere".
    else {
        set dv to F9ManDv(hi * 1000, lo * 1000).
        local fu is F9S2Fuel().
        local used is ship:mass * (1 - constant:e ^ (-dv / F9GVe())).
        if fu[1] > 0 set lft to (fu[0] - used) / fu[1] * 100.
        if fu[0] < used set err to "not enough S2 propellant".
    }
    set F9GManOk to err = "".
    F9GFieldErr(F9GFNAp, ap < 0).
    F9GFieldErr(F9GFNPe, pe < 0 or err = "periapsis inside atmosphere").
    if F9GManOk {
        set F9GWarn1:text to "• MANEUVER ΔV " + round(dv) + " m/s · PROPELLANT LEFT " + round(lft) + "%".
        set F9GWarn1:style:textcolor to F9GYel.
    } else {
        set F9GWarn1:text to "• " + err.
        set F9GWarn1:style:textcolor to F9GRed.
    }
}

function F9S2Node {
    parameter t, rOther.
    local rr is (positionat(ship, t) - body:position):mag.
    local rLo is body:radius + ship:periapsis - 1000.
    local rHi is body:radius + ship:apoapsis + 1000.
    if rr < rLo or rr > rHi {
        print "  NODE NOT PLACED: r " + round(rr / 1000, 1) + " km outside orbit " +
              round(rLo / 1000, 1) + "..." + round(rHi / 1000, 1) + " km".
        local n0 is node(t, 0, 0, 0).
        add n0.
        return n0.
    }
    local vNow is velocityat(ship, t):orbit:mag.
    local vWant is F9VisViva(rr, (rr + rOther) / 2).
    local nd is node(t, 0, 0, vWant - vNow).
    add nd.
    print "  node: r " + round(rr / 1000, 1) + " km, have " + round(vNow, 1) +
          ", need " + round(vWant, 1) + ", dv " + round(vWant - vNow, 1) +
          " (target r " + round(rOther / 1000, 1) + " km, ecc " +
          round(ship:orbit:eccentricity, 4) + ")".
    return nd.
}

function F9S2Exec {
    parameter nd.
    set F9GAbort to false.
    local dv0 is nd:deltav:mag.
    if dv0 < 0.3 or F9GEng:istype("String") {
        remove nd.
        return true.
    }
    local av is F9GDvNow().
    if dv0 > av {
        print "BURN EXCEEDS RESERVE: need " + round(dv0) +
              " m/s, have " + round(av) + " m/s - node removed".
        remove nd.
        set F9GPhase to "orbit".
        return false.
    }
    local ve is F9GVe().
    local fmax is max(1, F9GEng:possiblethrust).
    local bt is ship:mass * ve / fmax * (1 - constant:e ^ (-dv0 / ve)).
    set F9GBurnT to nd:time - bt / 2.
    set F9GBurnDv to dv0.
    set F9GBurnNode to nd.
    set F9GPhase to "burn".
    print "burn " + round(dv0, 1) + " m/s, burn time " + round(bt, 1) + " s".
    sas off.
    rcs on.
    set F9BurnDir to nd:deltav.
    lock steering to F9BurnDir.
    if F9GBurnT - time:seconds > 120 {
        wait until vang(ship:facing:forevector, F9BurnDir) < 3 or F9GAbort
              or time:seconds > F9GBurnT - 100.
        if not F9GAbort kuniverse:timewarp:warpto(F9GBurnT - 60).
    }
    wait until time:seconds >= F9GBurnT or F9GAbort.
    if F9GAbort {
        kuniverse:timewarp:cancelwarp().
        unlock steering.
        rcs off.
        sas on.
        set F9GBurnNode to "".
        set F9GPhase to "orbit".
        remove nd.
        print "BURN ABORTED before ignition".
        return false.
    }
    set F9BurnDir to nd:deltav.
    F9GEng:activate.
    lock throttle to max(0.05, min(1, nd:deltav:mag * ship:mass / max(1, ship:availablethrust) / 2)).
    local tIgn is time:seconds.
    until nd:deltav:mag < 0.2 or vdot(F9BurnDir, nd:deltav) < 0 or F9GAbort
          or (time:seconds - tIgn > 3 and ship:availablethrust <= 0) {
        if nd:deltav:mag > 3 set F9BurnDir to nd:deltav.
        wait 0.02.
    }
    lock throttle to 0.
    set ship:control:pilotmainthrottle to 0.
    F9GEng:shutdown.
    unlock steering.
    unlock throttle.
    rcs off.
    sas on.
    if F9GAbort print "ENGINE STOPPED BY ABORT".
    print "  node remainder " + round(nd:deltav:mag, 2) + " m/s, orbit " +
          round(ship:apoapsis / 1000, 1) + " x " + round(ship:periapsis / 1000, 1) + " km".
    set F9GBurnNode to "".
    set F9GPhase to "orbit".
    remove nd.
    return not F9GAbort.
}

function F9S2Deorbit {
    set F9GPhase to "deorbit".
    sas off.
    rcs on.
    lock steering to retrograde.
    local tw is time:seconds.
    wait until vang(ship:facing:forevector, retrograde:vector) < 3 or time:seconds - tw > 60.
    F9GEng:activate.
    lock throttle to 1.
    set tw to time:seconds.
    until ship:periapsis < body:atm:height * 0.4 or (time:seconds - tw > 3 and ship:availablethrust <= 0) {
        wait 0.05.
    }
    lock throttle to 0.
    set ship:control:pilotmainthrottle to 0.
    F9GEng:shutdown.
    unlock steering.
    unlock throttle.
    rcs off.
    print "S2 deorbited: periapsis " + round(ship:periapsis / 1000, 1) + " km".
}

function F9S2SepPayload {
    set F9GPhase to "sep".
    print "payload separation".
    if not F9PartDoEventLike(core:part, "decouple") {
        print "  adapter has no decouple event: " + F9PartEvents(core:part).
    }
    set F9GPhase to "orbit".
    set F9GPayGone to true.
}

function F9S2SepDragon {
    if not F9GDragonOn() return.
    set F9GPhase to "sep".
    print "Dragon separation".
    if not F9PartDoEventLike(core:part, "decouple") {
        print "  decoupler has no decouple event: " + F9PartEvents(core:part).
        set F9GPhase to "orbit".
        return.
    }
    wait 2.
    list targets in F9GTl.
    for tv in F9GTl {
        if tv:distance < 1000 and tv:partsnamedpattern("DRAGONV2[._]POD"):length > 0 {
            set kuniverse:activevessel to tv.
            print "  focus on " + tv:name.
            break.
        }
    }
    set F9GPhase to "orbit".
}

function F9RnTgt {
    if not hastarget return false.
    if not target:istype("Vessel") and not target:istype("Body") return false.
    if target:body <> ship:body return false.
    return true.
}

function F9RnNorm {
    parameter pos, vel.
    return vcrs(pos, vel):normalized.
}

function F9RnTgtNorm {
    return F9RnNorm(target:position - body:position, target:velocity:orbit).
}

function F9RnRelInc {
    if not F9RnTgt() return 0.
    return vang(F9RnNorm(-body:position, ship:velocity:orbit), F9RnTgtNorm()).
}

function F9RnPhase {
    if not F9RnTgt() return 0.
    local hn is F9RnNorm(-body:position, ship:velocity:orbit).
    local aa is vxcl(hn, -body:position).
    local bb is vxcl(hn, target:position - body:position).
    local ang is vang(aa, bb).
    if vdot(vcrs(aa, bb), hn) < 0 return 360 - ang.
    return ang.
}

function F9RnNodeTime {
    local ln0 is vcrs(F9RnNorm(-body:position, ship:velocity:orbit),
                      F9RnTgtNorm()):normalized.
    local per is ship:orbit:period.
    local best is 0.
    local bv is 999.
    local stp is per / 180.
    local tt is 0.
    until tt > per {
        local pp is positionat(ship, time:seconds + tt) - body:position.
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
                local pp is positionat(ship, time:seconds + t2) - body:position.
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

function F9S2MatchPlane {
    if not F9RnTgt() return.
    local di is F9RnRelInc().
    if di < F9RnIncOk {
        print "planes already match: " + round(di, 2) + " deg".
        return.
    }
    local tn is F9RnNodeTime().
    local vv is velocityat(ship, tn):orbit:mag.
    local dv0 is 2 * vv * sin(di / 2).
    local bt is ship:mass * F9GVe() / max(1, F9GEng:possiblethrust) *
                (1 - constant:e ^ (-dv0 / F9GVe())).
    print "plane change: " + round(di, 2) + " deg, " +
          round(dv0, 1) + " m/s, burn time " + round(bt, 1) + " s".
    set F9GAbort to false.
    local nd is node(tn, 0, dv0, 0).
    add nd.
    local nWant is -vdot(velocityat(ship, tn):orbit, F9RnTgtNorm()) * F9RnTgtNorm().
    if vdot(nd:deltav, nWant) < 0 set nd:normal to -dv0.
    set F9GBurnNode to nd.
    set F9GPhase to "burn".
    set F9GBurnT to tn - bt / 2.
    set F9GBurnDv to dv0.
    sas off.
    rcs on.
    set F9RnDir to -vdot(ship:velocity:orbit, F9RnTgtNorm()) * F9RnTgtNorm().
    lock steering to F9RnDir.
    if F9GBurnT - time:seconds > 120 {
        wait until vang(ship:facing:forevector, F9RnDir) < 5 or F9GAbort or
                   time:seconds > F9GBurnT - 100.
        if not F9GAbort kuniverse:timewarp:warpto(F9GBurnT - 40).
    }
    wait until time:seconds >= F9GBurnT or not F9RnTgt() or F9GAbort.
    if F9GAbort or not F9RnTgt() {
        kuniverse:timewarp:cancelwarp().
        unlock steering.
        rcs off.
        sas on.
        set F9GBurnNode to "".
        remove nd.
        set F9GPhase to "orbit".
        print "PLANE CHANGE ABORTED before ignition".
        return.
    }
    F9GEng:activate.
    lock throttle to 1.
    local prev is 999999.
    local tIgn is time:seconds.
    until false {
        set F9RnDir to -vdot(ship:velocity:orbit, F9RnTgtNorm()) * F9RnTgtNorm().
        local outv is F9RnDir:mag.
        if outv < 0.3 or outv > prev or F9GAbort break.
        if time:seconds - tIgn > 3 and ship:availablethrust <= 0 break.
        set prev to outv.
        wait 0.05.
    }
    lock throttle to 0.
    set ship:control:pilotmainthrottle to 0.
    F9GEng:shutdown.
    unlock steering.
    unlock throttle.
    rcs off.
    sas on.
    if F9GAbort print "ENGINE STOPPED BY ABORT".
    print "  remaining " + round(F9RnRelInc(), 2) + " deg".
    set F9GBurnNode to "".
    remove nd.
    set F9GPhase to "orbit".
}

function F9S2Rndz {
    if not F9RnTgt() return.
    if F9RnRelInc() > F9RnIncWarn {
        print "match the plane first: " + round(F9RnRelInc(), 2) + " deg".
        return.
    }
    if ship:orbit:eccentricity > F9RnEccOk {
        print "circularize first: eccentricity " +
              round(ship:orbit:eccentricity, 4) + ", phasing assumes a circular orbit".
        return.
    }
    if target:orbit:eccentricity > F9RnEccOk {
        print "target orbit is elliptical, eccentricity " +
              round(target:orbit:eccentricity, 4) + " - cannot phase".
        return.
    }
    local r2 is target:orbit:semimajoraxis.
    local r1 is ship:orbit:semimajoraxis.
    local sma is (r1 + r2) / 2.
    local tH is constant:pi * sqrt(sma ^ 3 / body:mu).
    local w2 is 360 / target:orbit:period.
    local w1 is 360 / ship:orbit:period.
    local need is mod(180 - w2 * tH + 720, 360).
    local dw is w2 - w1.
    if abs(dw) < 0.000001 {
        print "phase does not change: orbits have the same period".
        return.
    }
    local wait0 is mod(need - F9RnPhase() + 720, 360) / dw.
    if dw < 0 set wait0 to mod(F9RnPhase() - need + 720, 360) / (-dw).
    print "phasing: wait " + F9Hms(wait0) + ", transfer " + F9Hms(tH).
    print "  phase now " + round(F9RnPhase(), 1) + ", needed " + round(need, 1).
    if not F9S2Exec(F9S2Node(time:seconds + wait0, r2)) return.
    wait 1.
    F9S2Exec(F9S2Node(time:seconds + eta:apoapsis, body:radius + ship:apoapsis)).
    print "rendezvous: " + round(target:distance / 1000, 1) + " km to target".
}

function F9Lim1 {
    parameter x.
    if x > 1 return 1.
    if x < -1 return -1.
    return x.
}

function F9RnMono {
    local m is 0.
    for r in ship:resources { if r:name = "MonoPropellant" set m to r:amount. }
    return m.
}

// Гасим не скорость, а ошибку скорости: хотим лететь на цель со скоростью vA,
// всё остальное в векторе rel - боковой снос, его давим теми же двигателями.
function F9S2Approach {
    if not F9RnTgt() return false.
    local d0 is target:distance.
    if d0 > F9RnAppFar {
        print "approach: to target " + round(d0 / 1000, 1) + " km, beyond " +
              round(F9RnAppFar / 1000) + " km not handled - RENDEZVOUS first".
        return false.
    }
    if F9RnMono() <= 0 print "  no monopropellant - approach will use whatever feeds the RCS".
    set F9GAbort to false.
    set F9GPhase to "burn".
    print "approach to " + target:name + ": " + round(d0) + " m, " +
          round((ship:velocity:orbit - target:velocity:orbit):mag, 1) + " m/s relative".
    sas off.
    rcs on.
    set F9RnAppDir to target:position.
    lock steering to F9RnAppDir.
    local t0 is time:seconds.
    local tp is 0.
    local done is false.
    until F9GAbort {
        local d is target:distance.
        local rel is ship:velocity:orbit - target:velocity:orbit.
        set F9RnAppDir to target:position.
        if d < F9RnAppStop and rel:mag < 1 {
            set done to true.
            break.
        }
        if time:seconds - t0 > F9RnAppTmax {
            print "  approach: timeout " + round(F9RnAppTmax) + " s".
            break.
        }
        local vA is min(F9RnAppVmax, max(0.5, d * F9RnAppK)).
        if d < F9RnAppStop set vA to 0.
        local err is F9RnAppDir:normalized * vA - rel.
        set ship:control:fore to F9Lim1(vdot(err, ship:facing:forevector) * F9RnAppGain).
        set ship:control:starboard to F9Lim1(vdot(err, ship:facing:starvector) * F9RnAppGain).
        set ship:control:top to F9Lim1(vdot(err, ship:facing:topvector) * F9RnAppGain).
        if time:seconds - tp > 5 {
            set tp to time:seconds.
            print "  " + round(d) + " m, " + round(rel:mag, 1) + " m/s, need " + round(vA, 1).
        }
        wait 0.1.
    }
    set ship:control:neutralize to true.
    unlock steering.
    rcs off.
    sas on.
    set F9GPhase to "orbit".
    if F9GAbort print "APPROACH ABORTED: " + round(target:distance) + " m".
    else if done print "approach done: " + round(target:distance) + " m, " +
        round((ship:velocity:orbit - target:velocity:orbit):mag, 2) +
        " m/s - manual from here".
    return done.
}

function F9S2DoCmd {
    parameter c.
    local rad is body:radius.
    if c["cmd"] = "circap" F9S2Exec(F9S2Node(time:seconds + eta:apoapsis, rad + ship:apoapsis)).
    else if c["cmd"] = "circpe" F9S2Exec(F9S2Node(time:seconds + eta:periapsis, rad + ship:periapsis)).
    else if c["cmd"] = "deorbit" F9S2Deorbit().
    else if c["cmd"] = "sepdragon" { F9S2SepDragon(). F9S2AutoDeorbit(). }
    else if c["cmd"] = "seppay" { F9S2SepPayload(). F9S2AutoDeorbit(). }
    else if c["cmd"] = "plane" F9S2MatchPlane().
    else if c["cmd"] = "rndz" F9S2Rndz().
    else if c["cmd"] = "approach" F9S2Approach().
    else if c["cmd"] = "set" {
        local rp1 is rad + ship:periapsis.
        local ra2 is rad + c["ap"] * 1000.
        if F9S2Exec(F9S2Node(time:seconds + eta:periapsis, ra2)) {
            local t2 is time:seconds + eta:periapsis.
            if ra2 > rp1 set t2 to time:seconds + eta:apoapsis.
            F9S2Exec(F9S2Node(t2, rad + c["pe"] * 1000)).
        } else print "second node not placed: first one not executed".
    }
}

// Сход S2 сам после отделения груза, если стоит S2 DISPOSAL. Пауза
// F9DeoWait, чтобы груз отошёл; во время паузы ABORT BURN отменяет сход.
function F9S2AutoDeorbit {
    if not F9GDeorbOn return.
    print "S2 deorbit in " + F9DeoWait + " s - ABORT BURN cancels.".
    set F9GAbort to false.
    set F9GPhase to "burn".
    local tw is time:seconds + F9DeoWait.
    wait until time:seconds >= tw or F9GAbort.
    if F9GAbort {
        print "S2 deorbit cancelled.".
        set F9GPhase to "orbit".
        return.
    }
    F9S2Deorbit().
    set F9GPhase to "orbit".
}

// Довыведение с парковки: те же узлы, что команда "set" на вкладке ORBIT.
// Перигей почти равен парковке (GTO) - второй импульс не ставим.
function F9S2Profile {
    if F9Prof = "park" {
        print " ".
        print "=== PARKING " + round(ship:apoapsis / 1000) + " km -> " + F9FinAp + " x " + F9FinPe + " km ===".
        set F9GPhase to "orbit".
        local pe is F9FinPe.
        if pe * 1000 < ship:periapsis + 5000 set pe to ship:periapsis / 1000.
        F9S2DoCmd(lexicon("cmd", "set", "ap", F9FinAp, "pe", pe)).
        if F9GPhase = "burn" set F9GPhase to "orbit".
        print "  orbit " + round(ship:apoapsis / 1000, 1) + " x " + round(ship:periapsis / 1000, 1) + " km".
    }
    if F9Ms:length = 0 return.
    print " ".
    print "=== ORBIT LIST: " + F9Ms:length + " ===".
    set F9GPhase to "orbit".
    local rad is body:radius.
    local pl is F9MsPlan(F9FinAp, F9FinPe, F9GIncl, false).
    from { local k is 0. } until k >= F9Ms:length step { set k to k + 1. } do {
        print "orbit " + (k + 2) + ": " + F9MsText(F9Ms[k]).
        local ok is true.
        for b in pl["how"][k] {
            if ok {
                print "  node " + F9MsBurnText(b) + " km, plan " + round(b["dv"]) + " m/s".
                local tb is time:seconds + (choose eta:apoapsis if b["at"] = "apo" else eta:periapsis).
                set ok to F9S2Exec(F9S2Node(tb, rad + b["to"] * 1000)).
                if F9GPhase = "burn" set F9GPhase to "orbit".
            }
        }
        print "  orbit " + round(ship:apoapsis / 1000, 1) + " x " + round(ship:periapsis / 1000, 1) + " km".
        if not ok {
            print "list stopped at orbit " + (k + 2).
            break.
        }
    }
}

function F9S2OrbitOps {
    set F9GPhase to "orbit".
    F9GValidate1().
    until false {
        if F9GCmd:istype("Lexicon") {
            local c is F9GCmd.
            set F9GCmd to "".
            F9S2DoCmd(c).
            if F9GPhase = "burn" set F9GPhase to "orbit".
            F9GValidate1().
        }
        wait 0.2.
    }
}

function F9GKm {
    parameter x.
    if x <= 0 return "—".
    return round(x / 1000, 1) + " <size=11><color=#8A96A3>km</color></size>".
}

function F9GTick {
    local now is time:seconds.
    local clk is "".
    local st is "".
    local cc is F9GAcc.
    if F9GPhase = "pad" {
        set clk to "T-" + F9Hms(max(10, F9GCount)).
        set st to choose "READY FOR LAUNCH" if F9GOk else "HOLD".
        if not F9GOk set cc to F9GYel.
    } else if F9GPhase = "count" and now < F9GT0 {
        set clk to "T-" + F9Hms(F9GT0 - now).
        set st to "COUNTDOWN · GO".
    } else {
        if F9GPhase = "count" set F9GPhase to "s1".
        set clk to choose "T+" + F9Hms(now - F9GT0) if F9GT0 > 0 else "T+--:--:--".
        if F9GPhase = "s1" set st to "ASCENT · S1".
        if F9GPhase = "s2" set st to "ASCENT · S2".
        if F9GPhase = "orbit" set st to choose "IN ORBIT" if ship:periapsis > body:atm:height else "NO ORBIT".
        if F9GPhase = "burn" set st to "BURN".
        if F9GPhase = "deorbit" set st to "S2 DEORBIT".
        if F9GPhase = "sep" set st to "DRAGON SEPARATION".
    }
    set F9GClock:text to clk.
    set F9GClock:style:textcolor to cc.
    F9GWinUpdate().
    F9GBrgUpdate().
    if F9PfDirty and F9GTab3:pressed F9PfCalc().
    set F9GState:text to st.

    local att is F9GAttached().
    local fu is F9S2Fuel().
    local fuFrac is 0.
    if fu[1] > 0 set fuFrac to fu[0] / fu[1].
    F9GBarPct(F9GBFuel, fuFrac, choose "green" if fuFrac > 0.25 else "yellow").

    local drOn is F9GDragonOn().
    local l2 is "green".
    if F9GEng:istype("String") or (F9GPhase = "pad" and not F9GOk) set l2 to "red".
    local sts is list(choose "green" if att else "off", l2,
                      choose "yellow" if drOn else "off",
                      choose "green" if homeconnection:isconnected else "yellow").
    local i is 0.
    for ls in F9GLampSets {
        for j in range(4) { F9GBg("lamp" + i + "_" + j, ls[j], "lamp_" + sts[j]). }
        set i to i + 1.
    }

    if F9GPhase <> "pad" F9GEnable("go", F9GGo, "go", false).
    F9GEnable("cancel", F9GCancel, "red",
              (F9GPhase = "count" and now < F9GT0 - 1) or F9GPhase = "burn").
    F9GEnable("abrt", F9GAbrt, "red", F9GPhase = "burn").

    set F9GCurAp:text to F9GKm(ship:apoapsis).
    set F9GCurPe:text to F9GKm(ship:periapsis).
    local orb is F9GPhase = "orbit".
    F9GEnable("exec", F9GExec, "blue", orb and F9GManOk).
    F9GEnable("circap", F9GCircAp, "btn", orb).
    F9GEnable("circpe", F9GCircPe, "btn", orb).
    F9GEnable("deorb", F9GDeorb, "red", orb and not drOn).
    F9GEnable("pay", F9GPay, "blue", orb and not drOn and not F9GPayGone).
    F9GRnUpdate(orb).
    if F9GPhase = "burn" and not F9GBurnNode:istype("String") {
        local rem is F9GBurnNode:deltav:mag.
        local fr is 1 - rem / max(0.1, F9GBurnDv).
        if now < F9GBurnT set F9GImpTxt:text to "T-" + F9Hms(F9GBurnT - now) + " · " + round(F9GBurnDv) + " m/s".
        else set F9GImpTxt:text to round(100 * max(0, fr)) + "% · " + round(rem) + " m/s left".
        F9GBarSet(F9GImpBar, fr, "blue").
    } else {
        set F9GImpTxt:text to "—".
        F9GBarSet(F9GImpBar, 0, "blue").
    }

    F9GEnable("sep", F9GSep, "blue", orb and drOn).
    local drSt is "NOT ON BOARD".
    local drL is "off".
    if F9GHasDragon {
        set drSt to choose "ATTACHED" if drOn else "SEPARATED".
        set drL to choose "yellow" if drOn else "green".
    }
    set F9GDrState:text to drSt.
    F9GBg("drlamp", F9GDrLamp, "lamp_" + drL).
}

set F9GPhase to "s2".
if F9S1Attached() {
    if ship:status = "PRELAUNCH" or ship:status = "LANDED" set F9GPhase to "pad".
    else set F9GPhase to "s1".
} else if ship:periapsis > body:atm:height set F9GPhase to "orbit".

set F9GS1Cpu to "".
list processors in F9GCpus.
for cpu in F9GCpus {
    if cpu:part:name:contains("Interstage") set F9GS1Cpu to cpu.
}

set F9GM2 to ship:mass.
set F9GS1Dry to 0.
set F9GPayload to 0.
if F9S1Attached() {
    set F9GM2 to 0.
    for p in F9GStack() {
        set F9GM2 to F9GM2 + p:mass.
        // Декуплер Dragon - железо S2, остаётся на ступени; груз - капсула с trunk.
        if not p:name:contains("F9") and not p:name:contains("Dragon.Decoupler") and not p:name:contains("Dragon_Decoupler")
           and p:uid <> core:part:uid {
            set F9GPayload to F9GPayload + p:mass.
            print "  payload: " + p:name + " " + round(p:mass, 3) + " t".
        }
    }
    print "S2 stack " + round(F9GM2, 2) + " t, payload " + round(F9GPayload, 2) +
          " t, S2 fuel " + round(F9S2Fuel()[0], 2) + " t".
    set F9GS1Dry to F9Stage1Dry().
}
set F9GPerf to F9GPerfRead().
set F9GCfg0 to F9CfgRead().
set F9GCount to F9GCfg0["count"].
if F9GCfg0:haskey("force") set F9GForce to F9GCfg0["force"].
if F9GCfg0:haskey("deo") set F9GDeorbOn to F9GCfg0["deo"].
set F9GHasDragon to F9GDragonOn().
F9MsLoad().
set F9GPayGone to false.
set F9GTgtName to "".
set F9GBrgStale to 120.

set F9GWin to gui(440).
set F9GWin:x to 40.
set F9GWin:y to 120.
set F9GWin:style:bg to F9GImg + "panel_bg".
set F9GWin:style:on:bg to F9GImg + "panel_bg".
set F9GWin:style:border:h to 12.
set F9GWin:style:border:v to 12.
set F9GWin:style:padding:h to 18.
set F9GWin:style:padding:top to 14.
set F9GWin:style:padding:bottom to 16.

set F9GHd to F9GWin:addhlayout().
set F9GLogo to F9GHd:addlabel("").
set F9GLogo:style:bg to F9GImg + "logo".
F9GNoBorder(F9GLogo).
set F9GLogo:style:width to 24.
set F9GLogo:style:height to 24.
set F9GLogo:style:margin:top to 6.
set F9GHdT to F9GHd:addvlayout().
F9GLabel(F9GHdT, "FALCON 9", 12, white).
F9GLabel(F9GHdT, "kOS FLIGHT CTRL", 9, F9GGray).
F9GHd:addspacing(-1).
set F9GHdR to F9GHd:addvlayout().
set F9GClock to F9GLabel(F9GHdR, "", 19, F9GAcc, true, "right").
set F9GState to F9GLabel(F9GHdR, "", 9, F9GGray, true, "right").
F9GWin:addspacing(8).

set F9GTabRow to F9GWin:addhlayout().
set F9GTab0 to F9GButton(F9GTabRow, "LAUNCH", "tab", 32, 11).
set F9GTab1 to F9GButton(F9GTabRow, "ORBIT", "tab", 32, 11).
set F9GTab2 to F9GButton(F9GTabRow, "DRAGON", "tab", 32, 11).
set F9GTab3 to F9GButton(F9GTabRow, "PLAN", "tab", 32, 11).
for b in list(F9GTab0, F9GTab1, F9GTab2, F9GTab3) {
    set b:toggle to true.
    set b:exclusive to true.
}
F9GDivider(F9GWin).
set F9GPages to F9GWin:addstack().
set F9GP0 to F9GPages:addvlayout().
set F9GP1 to F9GPages:addvlayout().
set F9GP2 to F9GPages:addvlayout().
set F9GP3 to F9GPages:addvlayout().

F9GLabel(F9GP0, "FLIGHT PLAN · edit in PLAN", 10, F9GGray).
set F9GPlanL to F9GLabel(F9GP0, "", 11, F9GTxt).
set F9GPlanL:style:wordwrap to true.
set F9GWarn0 to F9GLabel(F9GP0, "", 10, F9GGray).
set F9GBudL to F9GLabel(F9GP0, "", 9, F9GGray).
set F9GBudL:style:wordwrap to true.
set F9GWarn0:style:wordwrap to true.
F9GDivider(F9GP0).
set F9GBrgBox to F9GBox(F9GP0, true).
set F9GBrgLamp to F9GLamp(F9GBrgBox).
F9GLabel(F9GBrgBox, "BARGE", 11, F9GGray).
F9GBrgBox:addspacing(-1).
set F9GBrgVal to F9GLabel(F9GBrgBox, "—", 12, white, true, "right").

set F9GBFuel to F9GBarRow(F9GP0, "FUEL S2").
F9GLamps(F9GP0).
set F9GBtnRow to F9GP0:addhlayout().
set F9GGo to F9GButton(F9GBtnRow, "LAUNCH", "go", 42, 13).
set F9GCancel to F9GButton(F9GBtnRow, "ABORT", "red", 42, 13).

set F9GCurRow to F9GP1:addhlayout().
set F9GCurAp to F9GBig(F9GCurRow, "CURRENT APOAPSIS").
set F9GCurPe to F9GBig(F9GCurRow, "CURRENT PERIAPSIS").
set F9GFNAp to F9GField(F9GP1, "New apoapsis", max(F9GCfg0["ap"], F9GCfg0["pe"]), "km").
set F9GFNPe to F9GField(F9GP1, "New periapsis", min(F9GCfg0["ap"], F9GCfg0["pe"]), "km").
set F9GWarn1 to F9GLabel(F9GP1, "", 10, F9GYel).
set F9GExec to F9GButton(F9GP1, "EXECUTE", "blue", 36, 12).
set F9GAbrt to F9GButton(F9GP1, "ABORT BURN", "red", 30, 11).
set F9GCircRow to F9GP1:addhlayout().
set F9GCircAp to F9GButton(F9GCircRow, "CIRCULARIZE AT AP", "btn", 34, 10).
set F9GCircPe to F9GButton(F9GCircRow, "CIRCULARIZE AT PE", "btn", 34, 10).
set F9GImpRow to F9GP1:addhlayout().
F9GLabel(F9GImpRow, "BURN", 10, F9GGray).
F9GImpRow:addspacing(-1).
set F9GImpTxt to F9GLabel(F9GImpRow, "—", 10, white, true, "right").
set F9GImpBar to F9GBar(F9GP1, 404).
F9GDivider(F9GP1).
F9GLamps(F9GP1).
set F9GRnBox to F9GBox(F9GP1, true).
set F9GRnLamp to F9GLamp(F9GRnBox).
F9GLabel(F9GRnBox, "TARGET", 11, F9GGray).
F9GRnBox:addspacing(-1).
set F9GRnVal to F9GLabel(F9GRnBox, "—", 12, white, true, "right").
set F9GRnRow to F9GP1:addhlayout().
set F9GRnPlane to F9GButton(F9GRnRow, "MATCH PLANE", "btn", 34, 10).
set F9GRnGo to F9GButton(F9GRnRow, "RENDEZVOUS", "blue", 34, 10).
set F9GRnApp to F9GButton(F9GP1, "APPROACH TARGET", "btn", 30, 11).

set F9GPay to F9GButton(F9GP1, "SEPARATE PAYLOAD", "blue", 42, 12).
set F9GDeorb to F9GButton(F9GP1, "DEORBIT S2", "red", 42, 12).

set F9GDrBox to F9GBox(F9GP2, false).
set F9GDrRow to F9GDrBox:addhlayout().
set F9GDrLamp to F9GLamp(F9GDrRow).
F9GLabel(F9GDrRow, "STATUS", 11, F9GGray).
F9GDrRow:addspacing(-1).
set F9GDrState to F9GLabel(F9GDrRow, "—", 12, white, true, "right").
set F9GDrNote to F9GLabel(F9GDrBox, "After separation the camera switches to Dragon. Capsule controls open in its own window.", 11, F9GGray, false).
set F9GDrNote:style:wordwrap to true.
set F9GDrBeta to F9GLabel(F9GDrBox, "Dragon capsule control is experimental - will be in the next version.", 11, F9GYel, false).
set F9GDrBeta:style:wordwrap to true.
set F9GSep to F9GButton(F9GP2, "SEPARATE DRAGON", "blue", 42, 12).
F9GDivider(F9GP2).
F9GLamps(F9GP2).

set F9PfHead to F9GLabel(F9GP3, "", 10, F9GGray).
set F9PfHead:style:wordwrap to true.
F9GLabel(F9GP3, "ORBIT 1 · ASCENT (plane is set here only)", 10, F9GGray).
set F9GFAp to F9GField(F9GP3, "Apoapsis", F9GCfg0["ap"], "km").
set F9GFPe to F9GField(F9GP3, "Periapsis", F9GCfg0["pe"], "km").
set F9GFInc to F9GField(F9GP3, "Inclination", F9GCfg0["incl"], "°").
set F9GFLan to F9GField(F9GP3, "RAAN", F9GCfg0["lan"], "°").
set F9GHint to F9GLabel(F9GP3, "Examples: low 150×150 · " + round(abs(ship:latitude), 1) +
    "° | ISS-like 250×250 · 51.6° | polar 300×300 · 90°", 11, F9GDim, false).
set F9GHint:style:wordwrap to true.
set F9PfCalcBox to F9GBox(F9GP3, false).
F9GLabel(F9PfCalcBox, "ORBITS AFTER SECO · one node per step", 10, F9GGray).
set F9MsOrb1 to F9GLabel(F9PfCalcBox, "", 11, F9GTxt).
set F9MsBox to F9PfCalcBox:addvlayout().
set F9MsAddRow to F9PfCalcBox:addhlayout().
set F9MsAddRow:style:margin:top to 6.
function F9MsNumField {
    parameter parent, nm.
    F9GLabel(parent, nm, 11, F9GGray).
    local f is parent:addtextfield("").
    set f:style:width to 70.
    set f:style:height to 26.
    set f:style:font to F9GMono.
    set f:style:fontsize to 12.
    set f:style:align to "right".
    set f:style:normal:bg to F9GImg + "field".
    set f:style:hover:bg to F9GImg + "field".
    set f:style:focused:bg to F9GImg + "field_focus".
    set f:style:normal:textcolor to white.
    set f:style:focused:textcolor to white.
    return f.
}
set F9MsFAp to F9MsNumField(F9MsAddRow, "Ap").
set F9MsFPe to F9MsNumField(F9MsAddRow, "Pe").
set F9MsAddB to F9GButton(F9MsAddRow, "+ ORBIT", "btn", 26, 10).
set F9MsClrB to F9GButton(F9MsAddRow, "CLEAR", "btn", 26, 10).
set F9GRetBox to F9GBox(F9GP3, true).
set F9GRetLamp to F9GLamp(F9GRetBox).
F9GLabel(F9GRetBox, "RECOVERY", 11, F9GGray).
F9GRetBox:addspacing(-1).
set F9GRetVal to F9GLabel(F9GRetBox, "—", 12, white, true, "right").
set F9GRetBtn to F9GButton(F9GRetBox, "AUTO", "go", 20, 10).
set F9GRetBtn:style:hstretch to false.
set F9GRetBtn:style:width to 64.
set F9GRetBtn:text to choose "AUTO" if F9GForce = "" else F9GForce:toupper.
set F9GDeoBox to F9GBox(F9GP3, true).
set F9GDeoLamp to F9GLamp(F9GDeoBox).
F9GLabel(F9GDeoBox, "S2 DISPOSAL", 11, F9GGray).
F9GDeoBox:addspacing(-1).
set F9GDeoVal to F9GLabel(F9GDeoBox, "—", 12, white, true, "right").
set F9GDeoBtn to F9GButton(F9GDeoBox, "ON", "go", 20, 10).
set F9GDeoBtn:style:hstretch to false.
set F9GDeoBtn:style:width to 64.
set F9GWinBox to F9GBox(F9GP3, true).
set F9GWinLamp to F9GLamp(F9GWinBox).
F9GLabel(F9GWinBox, "WINDOW", 11, F9GGray).
F9GWinBox:addspacing(-1).
set F9GWinVal to F9GLabel(F9GWinBox, "—", 12, white, true, "right").
set F9GWinBtn to F9GButton(F9GWinBox, "TARGET", "go", 20, 10).
set F9GWinBtn:style:hstretch to false.
set F9GWinBtn:style:width to 64.
set F9PfBtnRow to F9GP3:addhlayout().
set F9PfSaveB to F9GButton(F9PfBtnRow, "SAVE PLAN", "go", 30, 11).
set F9PfSendB to F9GButton(F9PfBtnRow, "SEND BARGE POINT", "blue", 30, 11).
set F9PfBtnMsg to F9GLabel(F9GP3, "", 10, F9GGray).
set F9PfBtnMsg:style:wordwrap to true.
set F9PfSumBox to F9GBox(F9GP3, false).
set F9PfErr to F9GLabel(F9PfSumBox, "", 10, F9GRed).
set F9PfErr:style:wordwrap to true.
set F9PfOut to F9GLabel(F9PfSumBox, "", 10, F9GTxt).
set F9PfOut:style:wordwrap to true.
set F9PfOutMax to F9GLabel(F9PfSumBox, "", 13, white).
F9GDivider(F9GP3).
F9GLabel(F9GP3, "MAX PAYLOAD BY DESTINATION", 10, F9GGray).
for t in F9PfTargets() {
    if t["nm"] = "GTO" {
        F9GDivider(F9GP3).
        F9GLabel(F9GP3, "BEYOND LEO · from " + F9PfPark + " km parking", 10, F9GGray).
    } else if t["nm"] = "150 km" {
        F9GLabel(F9GP3, "CIRCULAR LEO", 10, F9GGray).
    }
    local rw is F9GP3:addhlayout().
    local l is F9GLabel(rw, t["nm"], 10, F9GTxt).
    set l:style:width to 64.
    set t["bar"] to F9GBar(rw, 230).
    set t["val"] to F9GLabel(rw, "", 11, F9GTxt, true, "right").
    set t["val"]:style:width to 70.
    F9PfRows:add(t).
}
set F9PfNote to F9GLabel(F9GP3, "Max payload, t. Green = current payload fits. Model: S2 rocket eq. + 0.8 of S1 gain, fitted to 26 flights at 125 km (±0.4 t). Above 125 km and beyond LEO - Hohmann, not flown yet.", 9, F9GGray, false).
set F9PfNote:style:wordwrap to true.

set F9GTab0:ontoggle to { parameter pr. if pr F9GPages:showonly(F9GP0). }.
set F9GTab1:ontoggle to { parameter pr. if pr F9GPages:showonly(F9GP1). }.
set F9GTab2:ontoggle to { parameter pr. if pr F9GPages:showonly(F9GP2). }.
set F9GTab3:ontoggle to { parameter pr. if pr { F9GPages:showonly(F9GP3). set F9PfDirty to true. } }.
set F9MsAddB:onclick to {
    if F9GPhase <> "pad" return.
    local a is F9GNum(F9MsFAp, -1).
    local p is F9GNum(F9MsFPe, -1).
    if a < 0 or p < 0 return.
    F9Ms:add(lexicon("ap", max(a, p), "pe", min(a, p))).
    F9MsSave().
    F9GValidate().
    set F9PfDirty to true.
}.
set F9MsClrB:onclick to {
    if F9GPhase <> "pad" return.
    F9Ms:clear().
    F9MsSave().
    F9GValidate().
    set F9PfDirty to true.
}.
set F9GFAp:onchange to { parameter s. F9GValidate(). set F9PfDirty to true. }.
set F9GFPe:onchange to { parameter s. F9GValidate(). set F9PfDirty to true. }.
set F9GFInc:onchange to { parameter s. F9GValidate(). set F9PfDirty to true. }.
set F9GFLan:onchange to { parameter s. F9GValidate(). }.
set F9GFNAp:onchange to { parameter s. if F9GPhase = "orbit" F9GValidate1(). }.
set F9GFNPe:onchange to { parameter s. if F9GPhase = "orbit" F9GValidate1(). }.
set F9GRetBtn:onclick to { F9GCycleMode(). }.
set F9GDeoBtn:onclick to {
    if F9GPhase = "pad" {
        set F9GDeorbOn to not F9GDeorbOn.
        set F9PfDirty to true.
        F9GValidate().
    }
}.
set F9GWinBtn:onclick to { F9GWinTake(). }.
set F9PfSaveB:onclick to { F9GPlanSave(). }.
set F9PfSendB:onclick to { F9GAsdsPub(). }.
set F9GGo:onclick to { F9GOnGo(). }.
set F9GCancel:onclick to { F9GOnCancel(). }.
set F9GAbrt:onclick to { if F9GPhase = "burn" F9GOnCancel(). }.
set F9GExec:onclick to {
    if F9GPhase = "orbit" and F9GManOk {
        local ap is F9GNum(F9GFNAp, 0).
        local pe is F9GNum(F9GFNPe, 0).
        set F9GCmd to lexicon("cmd", "set", "ap", max(ap, pe), "pe", min(ap, pe)).
    }
}.
set F9GCircAp:onclick to { if F9GPhase = "orbit" set F9GCmd to lexicon("cmd", "circap"). }.
set F9GCircPe:onclick to { if F9GPhase = "orbit" set F9GCmd to lexicon("cmd", "circpe"). }.
set F9GDeorb:onclick to { if F9GPhase = "orbit" and not F9GDragonOn() set F9GCmd to lexicon("cmd", "deorbit"). }.
set F9GRnPlane:onclick to { if F9GPhase = "orbit" and F9RnTgt() set F9GCmd to lexicon("cmd", "plane"). }.
set F9GRnGo:onclick to { if F9GPhase = "orbit" and F9RnTgt() set F9GCmd to lexicon("cmd", "rndz"). }.
set F9GRnApp:onclick to { if F9GPhase = "orbit" and F9RnTgt() set F9GCmd to lexicon("cmd", "approach"). }.
set F9GPay:onclick to {
    if F9GPhase = "orbit" and not F9GDragonOn() and not F9GPayGone
        set F9GCmd to lexicon("cmd", "seppay").
}.
set F9GSep:onclick to { if F9GPhase = "orbit" and F9GDragonOn() set F9GCmd to lexicon("cmd", "sepdragon"). }.

if F9GPhase = "pad" {
    set F9GTab0:pressed to true.
    F9GPages:showonly(F9GP0).
    F9GValidate().
} else {
    F9GFieldsOn(false).
    set F9GTab1:pressed to true.
    F9GPages:showonly(F9GP1).
}
F9GEnable("go", F9GGo, "go", F9GPhase = "pad" and F9GOk).
F9GWin:show().
set F9GNext to 0.
when time:seconds > F9GNext then {
    set F9GNext to time:seconds + 0.5.
    F9GTick().
    return true.
}

function F9S2Log {
    parameter tag.
    local lf is 0. local ox is 0.
    for t in ship:partsnamedpattern("F9\.S2\.Tank") {
        for rs in t:resources {
            if rs:name = "LiquidFuel" set lf to lf + rs:amount.
            if rs:name = "Oxidizer" set ox to ox + rs:amount.
        }
    }
    local e is F9S2Engine().
    local es is " no eng".
    if not e:istype("String") {
        set es to " ign " + e:ignition + " fo " + e:flameout + " thrust " + round(e:thrust, 1) +
                  "/" + round(e:availablethrust, 1).
    }
    log "T+" + round(missiontime) + " " + tag + " h " + round(ship:altitude) +
        " vv " + round(ship:verticalspeed) + " v " + round(ship:velocity:orbit:mag) +
        " LF " + round(lf) + " Ox " + round(ox) + es +
        " unp " + ship:unpacked +
        " act " + (kuniverse:activevessel = ship)
        to "0:/f9s2fuel.log".
}

if F9S2Engine():istype("String") {
    print " ".
    print "SECOND STAGE ENGINE NOT FOUND.".
    wait until false.
}

// ---------------------------------------------------------------------
// Ждём разделения. Пока первая ступень с нами - не трогаем ничего: рулит
// она, и два автопилота на одном судне подерутся за управление.
// ---------------------------------------------------------------------
if F9S1Attached() {
    print " ".
    print "waiting for stage separation...".
    local nextFuel is 0.
    until not F9S1Attached() {
        if time:seconds >= nextFuel {
            set nextFuel to time:seconds + 5.
            F9S2Log("wait").
        }
        wait 0.2.
    }
}

if ship:periapsis > body:atm:height {
    print " ".
    print "already in orbit - nothing to do.".
    print "  " + round(ship:apoapsis / 1000, 1) + " x " +
          round(ship:periapsis / 1000, 1) + " km".
    F9S2OrbitOps().
}

print " ".
print "separation done, stage is free.".
F9S2Log("sep").
set F9SepTime to time:seconds.
set F9SepMass to ship:mass.
set F9GPhase to "s2".
when time:seconds > F9SepTime + 2 then {
    // Берём только СВОЙ бустер: ближайший с этим префиксом и не дальше
    // 5 км. Старые невернувшиеся бустеры носят то же начало имени, и раньше
    // фокус уходил на первый попавшийся, где бы он ни лежал.
    list targets in F9Tl.
    local bb is 0.
    local bd is 5000.
    for t in F9Tl {
        if t:name:startswith(F9BoosterName) and t:distance < bd {
            set bb to t.
            set bd to t:distance.
        }
    }
    if bb:istype("Vessel") {
        kuniverse:forceactive(bb).
        print "  focus given to booster " + bb:name + " (" + round(bd) + " m)".
    } else {
        print "  own booster not within 5 km - focus unchanged".
    }
}

// Поднимаем СВОЮ дальность физики прямо здесь: с этого момента игрок уходит
// смотреть посадку первой ступени, и без этого вторую упакует на 22 км.
F9SetLoadDist(F9LoadDist).

// Читаем обратно, что РЕАЛЬНО встало. PhysicsRangeExtender в сборке нет, и
// KSP вполне может обрезать запрошенное - тогда цифры разойдутся, и это
// будет видно сразу, а не по факту "ступень опять исчезла".
print "  physics range: requested " + round(F9LoadDist / 1000) + ", actual " +
      round(ship:loaddistance:flying:unload / 1000) + "/" +
      round(ship:loaddistance:suborbital:unload / 1000) + "/" +
      round(ship:loaddistance:orbit:unload / 1000) + " km".

set F9T0 to time:seconds.
lock F9Met to time:seconds - F9T0.

// Пауза перед запуском: на реальном пуске между разделением и SES-1
// проходит несколько секунд, чтобы ступени успели разойтись.
wait 4.

// ---------------------------------------------------------------------
// SES-1. Двигатель зажигаем напрямую, а не стейджингом: в крафте он стоит
// в одной стадии с обтекателем (istg 0 у обоих), и одна команда stage
// сбросила бы створки прямо сейчас - на высоте, где напор ещё заметный.
// ---------------------------------------------------------------------
// Зажигание с ПЛАВНЫМ набором тяги. На полной сразу нельзя: первая ступень
// ещё рядом, и струя Vacuum Merlin бьёт ей прямо в межступенник.
//
// Раньше это была ступенька: 20% - пауза пять секунд - и разом 100%. Скачок
// тяги впятеро за один тик - это удар по связке и по самой ступени. Теперь
// газ едет линейно от F9SoftThrottle до полного за F9RampTime секунд.
//
// Отсчёт начинается НЕ от команды зажигания, а от момента, когда появилась
// настоящая тяга: между activate и первыми килоньютонами проходит время, и
// разгонять по нему рампу значило бы съесть половину плавности впустую.
set F9SoftThrottle to 0.15.        // с чего начинаем
set F9RampTime to 3.               // секунд до полной тяги
set F9S2MaxG to 3.

function F9S2GThr {
    if ship:availablethrust <= 0 return 1.
    return min(1, F9S2MaxG * constant:g0 * ship:mass / ship:availablethrust).
}

// Пока зажигание не подтвердилось, F9IgnT лежит далеко в будущем - рампа
// стоит на F9SoftThrottle и никуда не едет.
set F9IgnT to time:seconds + 3600.
lock F9Ramp to min(1, F9SoftThrottle + (1 - F9SoftThrottle) *
                      max(0, time:seconds - F9IgnT) / F9RampTime).

sas off.
rcs off.
lock steering to heading(F9Azimuth, 20).
lock throttle to min(F9Ramp, F9S2GThr()).
F9S2Log("pre SES").
F9S2Engine():activate.

until ship:availablethrust > 0 or F9Met > 8 {
    F9S2Log("SES").
    wait 0.5.
}
if ship:availablethrust <= 0 {
    F9S2Log("FAIL").
    lock throttle to 0.
    print "SES-1 FAILED - no thrust.".

    // Почему именно нет - "тяги нет" не диагноз, а симптом. Печатаем
    // состояние двигателя и баки: зажёгся ли он вообще, не сорвало ли
    // пламя, есть ли чем гореть и сколько деталей осталось на судне.
    // Разбирать это по скриншоту обломков я не берусь.
    local e is F9S2Engine().
    if not e:istype("String") {
        print "  engine " + e:name.
        print "    ignited " + e:ignition + ", flameout " + e:flameout +
              ", thrust " + round(e:availablethrust, 1) + " of " +
              round(e:possiblethrust, 1) + " kN".
        print "    thrust limiter " + round(e:thrustlimit) + "%".
    }
    print "  parts on vessel: " + ship:parts:length.
    for r in ship:resources {
        if r:amount > 0 or r:capacity > 0 {
            print "    " + r:name + ": " + round(r:amount, 1) +
                  " of " + round(r:capacity, 1).
        }
    }
    wait until false.
}
// Тяга есть - с этой секунды рампа поехала.
set F9IgnT to time:seconds.
print "T+" + round(F9Met, 1) + " SES-1 at " + round(100 * F9SoftThrottle) +
      "%, thrust " + round(ship:availablethrust, 0) + " kN".
print "  spool-up in " + F9RampTime + " s".

wait F9RampTime.
print "T+" + round(F9Met, 1) + " full thrust".

// ---------------------------------------------------------------------
// Выведение.
// ---------------------------------------------------------------------
set F9S2PitchMax to 45.
set F9S2TGoMin to 5.
set F9S2TTail to 15.
set F9S2PitchTail to 8.
set F9S2Stretch to 2.2.
set F9S2ThrMin to 0.3.
// Точная отсечка (21.09 17:58, F9-KARTA "SECO точнее"). Газ убывает по
// остатку dv до целевой полуоси, в хвосте гасится вертикальная скорость.
set F9S2FineT to 2.                // с, постоянная спада газа по остатку dv
set F9S2FineThr to 0.15.           // нижний газ перед отсечкой
set F9S2CutLead to 0.04.           // с, упреждение отсечки (два такта)

// Доворот в плоскость цели прямо на выведении.
//
// Азимут считается один раз на столе и дальше держится намертво. Всё, что
// уводит ступень из плоскости - неточность азимута, снос первой ступени,
// старт не в свою секунду - к SECO остаётся как есть, и потом это чинит
// вторая ступень отдельным манёвром за свой запас. 17.09 так набежало 2.89
// градуса относительного наклонения.
//
// Тяга доворачивается против ТОЙ составляющей скорости, что смотрит из
// плоскости цели. Знак берётся из данных, а не из моего представления о
// том, куда смотрит нормаль: он пересчитывается каждый такт и сам сходится
// в ноль.
//
// Позиционную часть промаха это не лечит - если стартовал не в окно, узел
// всё равно сдвинут. Лечит угловую, а она и набегает на выведении.
set F9S2YawK to 0.004.             // доля тяги вбок на м/с выхода из плоскости
set F9S2YawMax to 10.              // градусов, потолок доворота
set F9S2YawAlt to 40000.           // ниже не рыскаем, там ещё есть напор
set F9S2YawNow to 0.
set F9S2YawN to V(0, 0, 0).
set F9S2P to 0.
set F9S2T to 1.
set F9S2TStar to 0.
set F9S2TgUsed to 0.
set F9TargetSma to body:radius + (F9TargetAp + F9TargetPe) / 2.

function F9S2DvLeft {
    local rNow is body:radius + ship:altitude.
    return sqrt(max(0, body:mu * (2 / rNow - 1 / F9TargetSma))) - ship:velocity:orbit:mag.
}

function F9S2ACmd {
    if ship:mass <= 0 return 0.
    return min(F9Ramp, min(F9S2GThr(), F9S2T)) * ship:availablethrust / ship:mass.
}

function F9S2TGo {
    local e is F9S2Engine().
    if e:istype("String") or ship:availablethrust <= 0 return 0.
    local vc is sqrt(body:mu * (2 / (body:radius + F9InsAlt) - 1 / F9TargetSma)).
    local hv is vxcl(up:vector, ship:velocity:orbit):mag.
    local dv is sqrt(max(0, vc - hv) ^ 2 + ship:verticalspeed ^ 2).
    local ve is max(1, e:isp) * constant:g0.
    local mdot is ship:availablethrust / ve.
    local aLim is F9S2MaxG * constant:g0.
    local mLim is ship:availablethrust / aLim.
    if ship:mass <= mLim return dv / aLim.
    local dv1 is ve * ln(ship:mass / mLim).
    if dv <= dv1 return ship:mass / mdot * (1 - constant:e ^ (-dv / ve)).
    return (ship:mass - mLim) / mdot + (dv - dv1) / aLim.
}

function F9S2Guide {
    local rr is body:radius + ship:altitude.
    local hv is vxcl(up:vector, ship:velocity:orbit):mag.
    local gEff is body:mu / (rr * rr) - hv * hv / rr.
    if ship:mass <= 0 or ship:availablethrust <= 0 {
        set F9S2P to 0.
        set F9S2T to 1.
        return.
    }
    local aFull is ship:availablethrust / ship:mass.
    local aMax is min(aFull, F9S2MaxG * constant:g0).
    local vv is ship:verticalspeed.
    local dh is F9InsAlt - ship:altitude.
    local tFull is F9S2TGo().
    local tg is tFull.
    set F9S2TStar to 0.
    if vv > 1 and dh > 0 {
        // Вертикальная тяга спадает к нулю к SECO (21.09 18:02, F9-KARTA).
        set F9S2TStar to 3 * dh / vv.
        set tg to max(tFull, min(F9S2TStar, tFull * F9S2Stretch)).
    }
    set F9S2TgUsed to tg.
    local tc is tg.
    local lim is F9S2PitchMax.
    local aV is 0.
    if tc > F9S2TGoMin {
        // Три условия на конце: высота, vv = 0 и вертикальная тяга = 0
        // (ускорение = -gЭфф на высоте ввода). Тангаж к SECO сам уходит в 0.
        local rIns is body:radius + F9InsAlt.
        local vcI is sqrt(body:mu * (2 / rIns - 1 / F9TargetSma)).
        local gEnd is body:mu / (rIns * rIns) - vcI * vcI / rIns.
        set aV to 12 * dh / (tc * tc) - 6 * vv / tc - gEnd.
    } else {
        set aV to 2 * dh / (F9S2TTail ^ 2) - 2 * vv / F9S2TTail.
        set lim to min(F9S2PitchMax, F9S2PitchTail * max(0, tg) / (F9S2TTail + F9S2TGoMin)).
    }
    local vc is sqrt(body:mu * (2 / (body:radius + F9InsAlt) - 1 / F9TargetSma)).
    local aH is max(0, vc - hv) / max(1, tg).
    local aNeed is sqrt(aH ^ 2 + (aV + gEff) ^ 2).
    set F9S2T to 1.
    if tg > tFull + 0.5 set F9S2T to max(F9S2ThrMin, min(1, aNeed / aFull)).
    set F9S2T to min(F9S2T, max(F9S2FineThr, F9S2DvLeft() / (aFull * F9S2FineT))).
    local aUse is min(aMax, aFull * F9S2T).
    local sinP is max(-1, min(1, (aV + gEff) / aUse)).
    set F9S2P to max(-lim, min(lim, arcsin(sinP))).
}

function F9S2PlaneN {
    if not hastarget return V(0, 0, 0).
    if not target:istype("Vessel") and not target:istype("Body") return V(0, 0, 0).
    if target:body <> ship:body return V(0, 0, 0).
    return vcrs(target:position - body:position, target:velocity:orbit):normalized.
}

function F9S2YawCalc {
    set F9S2YawN to V(0, 0, 0).
    set F9S2YawNow to 0.
    if ship:altitude < F9S2YawAlt return.
    local nt is F9S2PlaneN().
    if nt:mag < 0.5 return.
    local corr is -F9S2YawK * vdot(ship:velocity:orbit, nt).
    local lim is tan(F9S2YawMax).
    if corr > lim set corr to lim.
    if corr < -lim set corr to -lim.
    set F9S2YawN to nt.
    set F9S2YawNow to corr.
}

function F9S2Dir {
    local base is heading(F9Azimuth, F9S2P):vector:normalized.
    if F9S2YawN:mag < 0.5 return base.
    return (base + F9S2YawNow * F9S2YawN):normalized.
}

F9S2Guide().
F9S2YawCalc().
lock steering to F9S2Dir().
lock throttle to min(F9Ramp, min(F9S2GThr(), F9S2T)).

set F9NextPrint to 0.
set F9NextLoadDist to 0.
set F9FairingDone to false.
until ship:orbit:semimajoraxis >= F9TargetSma or ship:availablethrust <= 0
      or F9S2DvLeft() <= F9S2ACmd() * F9S2CutLead {
    F9S2Guide().
    F9S2YawCalc().
    // Переставляем дальность физики заново раз в пять секунд.
    //
    // Одного вызова у разделения может не хватить: KSP сбрасывает
    // vesselRanges при упаковке и при смене ситуации (FLYING ->
    // SUB_ORBITAL), а ситуация на выведении меняется как раз посередине.
    // Вызов дешёвый, а цена пропущенного сброса - ступень выпадает из
    // симуляции и выведение доигрывается по рельсам.
    if time:seconds > F9NextLoadDist {
        set F9NextLoadDist to time:seconds + 5.
        F9SetLoadDist(F9LoadDist).
    }

    // Створки сбрасываем по напору, а не по высоте: напор - это ровно то,
    // от чего они защищают, и он честнее любой заранее вбитой высоты.
    if not F9FairingDone and ship:altitude > F9FairingAlt and ship:q < F9FairingQ {
        set F9FairM0 to ship:mass.
        set F9FairM1 to ship:mass.
        for p in F9Fairings { set F9FairM1 to F9FairM1 - p:mass. }
        local n is F9FairingJettison().
        set F9FairingDone to true.
        print "T+" + round(F9Met, 0) + " fairing jettisoned (" + n + " halves)" +
              " at " + round(ship:altitude / 1000, 1) + " km".
    }
    if time:seconds > F9NextPrint {
        set F9NextPrint to time:seconds + 1.
        F9S2Log("asc pitch " + round(F9S2P, 1) +
                " yaw " + round(F9S2YawNow, 3) + " thr " + round(F9S2T, 2) +
                " tg " + round(F9S2TgUsed) + " T* " + round(F9S2TStar)).
        print "T+" + round(F9Met, 0) +
              "  ap=" + round(ship:apoapsis / 1000, 1) +
              "  pe=" + round(ship:periapsis / 1000, 1) +
              "  v=" + round(ship:velocity:orbit:mag, 0) +
              "  phys=" + round(ship:loaddistance:flying:unload / 1000) +
              "  vv=" + round(ship:verticalspeed, 0) +
              "  tgo=" + round(F9S2TgUsed, 0) +
              "  pitch=" + round(F9S2P, 1) +
              "  thr=" + round(F9S2T, 2).
    }
    wait 0.02.
}

// Глушим по-настоящему.
//
// "lock throttle to 0" держит газ на нуле только пока блокировка жива, а в
// конце скрипта стоит unlock - и газ возвращается игроку с тем значением,
// что осталось у него в рычаге. На первой ступени это уже приводило к тому,
// что двигатель продолжал работать после посадки.
//
// Здесь дополнительно гасим сам двигатель: вторая ступень остаётся на
// орбите, и работающий Merlin ей там ни к чему.
set F9SecoOk to F9S2DvLeft() < 5.
F9S2Log("SECO dv left " + round(F9S2DvLeft(), 2) + " vv " + round(ship:verticalspeed, 2)).
set F9SecoMass to ship:mass.
lock throttle to 0.
wait 0.1.
set ship:control:pilotmainthrottle to 0.
if not F9S2Engine():istype("String") F9S2Engine():shutdown.
F9S2Log("SECO").

print " ".
if F9SecoOk print "T+" + round(F9Met, 1) + " SECO - ORBIT".
else print "T+" + round(F9Met, 1) + " SECO - out of fuel before orbit".

// Двигатель отработал - держать вокруг ступени физику больше незачем,
// возвращаем штатные дистанции. Так же делает starship.ks после своей
// программы: SetLoadDistances(ship, "default").
F9SetLoadDist("default").
print "  physics range restored to default".
print "  apoapsis " + round(ship:apoapsis / 1000, 1) + " km".
print "  periapsis " + round(ship:periapsis / 1000, 1) + " km".
hudtext("S2 SECO: " + (choose "ORBIT " if F9SecoOk else "OUT OF FUEL ") +
        round(ship:apoapsis / 1000, 1) + " x " + round(ship:periapsis / 1000, 1) + " km",
        10, 2, 26, (choose green if F9SecoOk else red), false).

// Если створки всё ещё на месте - сбрасываем, дальше напора не будет.
if not F9FairingDone {
    F9FairingJettison().
    print "  fairing jettisoned after SECO-1".
}

// Отдельного импульса циркуляризации здесь БОЛЬШЕ НЕТ.
//
// Он был мёртвым кодом. Цикл выше выходит по одному из двух: либо перигей
// достиг цели - и циркуляризовать уже нечего, либо кончилась тяга - и
// циркуляризовать нечем. Блок стоял под условием "перигей ниже цели", то
// есть срабатывал только во втором случае, где его собственный цикл
// "пока есть тяга" завершался в тот же тик.
//
// Единый закон подъёма делает эту работу сам: круговая орбита - его
// неподвижная точка, а не отдельная фаза после неё.

// Ручной рычаг обнуляем ДО снятия блокировки - иначе он и вернёт газ.
set ship:control:pilotmainthrottle to 0.
unlock steering.
unlock throttle.
for e in ship:engines {
    if e:ignition e:shutdown.
}
sas on.

print " ".
print "=== ORBIT ===".
print "  " + round(ship:apoapsis / 1000, 1) + " x " + round(ship:periapsis / 1000, 1) + " km".
print "  inclination " + round(ship:orbit:inclination, 2) + " deg".
print "  fuel " + round(F9FuelPct(), 1) + "%".

// Замер для PLAN: сколько dv S2 ушло от разделения до SECO. Сброс створок
// - потеря массы без топлива, поэтому участки до и после него отдельно.
if F9SepMass > 0 and F9SecoMass > 0 and homeconnection:isconnected {
    local dvS2 is F9GVe() * ln(F9SepMass / F9SecoMass).
    if F9FairM0 > 0 set dvS2 to F9GVe() * (ln(F9SepMass / F9FairM0) + ln(F9FairM1 / F9SecoMass)).
    log time:calendar + " " + time:clock + " mode " + F9GMode + " payload " + round(F9GPayload, 2) +
        " t · sep " + round(F9SepMass, 2) + " t · SECO " + round(F9SecoMass, 2) + " t · fairing " +
        (choose round(F9FairM0, 2) + "->" + round(F9FairM1, 2) if F9FairM0 > 0 else "none") +
        " · orbit " + round(ship:apoapsis / 1000) + "x" + round(ship:periapsis / 1000) +
        " incl " + round(ship:orbit:inclination, 2) + " · S2 used " + round(dvS2) + " m/s" +
        (choose "" if F9SecoOk else " · DID NOT MAKE IT")
        to "0:/f9s2dv.log".
    print "  S2 ascent: " + round(dvS2) + " m/s (f9s2dv.log)".
}
if F9SecoOk and F9SepMass > 0 and F9SecoMass > 0 and homeconnection:isconnected {
    local dvUsed is F9GVe() * ln(F9SepMass / F9SecoMass).
    writejson(lexicon("dv", dvUsed, "sma", F9TargetSma, "sI", F9LaunchSinAz(F9GIncl), "mode", F9GMode), F9PerfFile).
    print "  S2 usage saved to f9perf.json: " + round(dvUsed) + " m/s".
}
if F9SecoOk F9S2Profile().
F9S2OrbitOps().
