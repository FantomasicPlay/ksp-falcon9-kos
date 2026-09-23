// =====================================================================
// f9lib.ks - опознание железа Falcon 9 (Tundra Exploration + KRE)
//
// Отдельный файл от полётной логики намеренно: детект деталей - это то,
// что ломается при каждом обновлении модов и при смене сборки крафта, и
// его надо уметь чинить, не трогая наведение.
//
// Загружается через RUN ONCE f9lib. Ничего не делает сам по себе, только
// заполняет глобальные переменные и даёт функции опроса.
// =====================================================================

// ---------------------------------------------------------------------
// Имена деталей ищем ПАТТЕРНОМ, а не точным совпадением.
//
// В craft-файле детали записаны как TE.19.F9.S1.Engine, а в cfg мода то же
// самое зовётся TE_19_F9_S1_Engine. Что именно вернёт kOS в part:name,
// зависит от версии - booster.ks по этой же причине ищет палочки башни
// через PARTSNAMEDPATTERN("PadB[ .]Chopsticks"). Повторяем приём: класс
// [._ ] покрывает все три написания разом.
// ---------------------------------------------------------------------
function F9Find {
    parameter pat.
    return ship:partsnamedpattern(pat).
}

// Деталь по модулю - самый надёжный способ, имя детали при этом не важно.
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

// ---------------------------------------------------------------------
// На какой мы ступени. Библиотека грузится обоими компьютерами - и тем,
// что в Interstage (первая ступень), и тем, что в Fairing.Adapter
// (вторая). Октавеб есть только у первой, по нему и различаем. Без этого
// вторая ступень честно докладывала бы, что у неё нет опор и рулей.
// ---------------------------------------------------------------------
set F9IsS1 to false.
for p in ship:parts {
    if p:hasmodule("ModuleTundraEngineSwitch") set F9IsS1 to true.
}

// ---------------------------------------------------------------------
// Октавеб. Одна деталь на девять Merlin, режимы переключает
// ModuleTundraEngineSwitch: All (9) -> ThreeLanding (3) -> CenterOnly (1).
// Ищем именно по этому модулю - он есть только у неё.
// ---------------------------------------------------------------------
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

// ---------------------------------------------------------------------
// Режим двигателя читаем из ПОЛЯ "mode" переключателя.
//
// По тяге определять нельзя, хотя это и было первой мыслью: maxthrust у
// незажжённого двигателя равен 0 (проверено на столе), а possiblethrust
// суммирует все три ModuleEnginesFX разом - 4561.7 кН = (2560+1706+764)
// * 282/311 - и от режима не меняется вообще.
//
// Поле отдаёт человекочитаемые строки "All Engines" / "Three Landing" /
// "Center Only". Сравниваем по куску слова, а не целиком: пробелы и
// регистр в GUI-именах - не то, на что стоит завязываться.
//
// Писать в поле нельзя (kOS: "Labels are read-only objects that can't be
// changed"), поэтому режим ставится только событием "next engine mode".
// Порядок по кругу: All -> Three -> Center -> All.
// ---------------------------------------------------------------------
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

// Сырая строка режима для отчёта. Отдельной функцией, а не выражением
// choose в print: если переключателя нет, обращение к getfield упадёт.
function F9ModeName {
    if F9EngSwitch:istype("String") return "-".
    if not F9EngSwitch:hasfield("mode") return "?".
    return F9EngSwitch:getfield("mode").
}

// Паспортная тяга режима в вакууме. Нужна для прикидок до зажигания,
// когда ship:maxthrust ещё нулевой; в полёте берём настоящую.
function F9ModeThrust {
    parameter n.
    if n = 9 return F9ThrAll.
    if n = 3 return F9Thr3.
    return F9Thr1.
}

// Переключение режима: жмём "next engine mode", пока поле не покажет
// нужный. Круг из трёх режимов, поэтому больше трёх шагов - значит
// событие не отрабатывает, и врать об успехе не надо.
function F9SetEngineMode {
    parameter want.   // 9, 3 или 1
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

// ---------------------------------------------------------------------
// Решётчатые рули. У KRE это ModuleControlSurface + ModuleDeployableAero,
// причём деталь появляется СЛОЖЕННОЙ (DeployModulePos = 1, спавн в 0),
// поэтому раскрывать их надо явно перед входом в атмосферу.
// ---------------------------------------------------------------------
set F9GridFins to list().
for p in F9ByModule("ModuleControlSurface") {
    // Решётчатый руль от обычной аэродинамической поверхности отличает то,
    // что он складывается: у него есть анимация раскрытия.
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

// Событие по КУСКУ имени, а не по точному совпадению.
//
// hasevent("extend") требует, чтобы событие звалось ровно так. У модов оно
// сплошь и рядом называется иначе - "extend grid fins", "deploy" - и тогда
// doevent молча не вызывается, а скрипт продолжает считать, что всё сделал.
// Именно так лог печатал "рули раскрыты", пока рули оставались сложены.
// Возвращаем, нашлось событие или нет, чтобы врать было нечем.
function F9DoEventLike {
    // Имя pm, а не mod: mod в kOS - встроенная функция остатка от деления,
    // писать в это имя запрещено. Тот же класс ошибки, что с v, r и q.
    parameter pm.
    parameter frag.
    for e in pm:allevents {
        // allevents отдаёт строки вида "(callable) extend, is KSPEvent"
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

// Событие ищем ПО ВСЕМ МОДУЛЯМ детали, а не в одном угаданном.
//
// Это оказалось принципиально. У решётчатого руля KRE есть и
// ModuleDeployableAero, и ModuleControlSurface, и ModuleAnimateGeneric, а
// раскрытие живёт в последнем и зовётся "extend fins". При этом
// ModuleDeployableAero у детали ПУСТОЙ - ни событий, ни полей. Пока код
// обращался именно к нему, рули не раскрывались ни разу за весь полёт,
// а скрипт считал, что команду отдал.
function F9PartDoEventLike {
    parameter prt.
    parameter frag.
    for mn in prt:modules {
        local pm is prt:getmodule(mn).
        if F9DoEventLike(pm, frag) return true.
    }
    return false.
}

// Поле по всем модулям детали - тем же приёмом.
function F9PartField {
    parameter prt.
    parameter fname.
    for mn in prt:modules {
        local pm is prt:getmodule(mn).
        if pm:hasfield(fname) return pm:getfield(fname).
    }
    return "?".
}

// Возвращает, сколько рулей реально приняли команду.
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

// Фактическое состояние рулей - по полю детали, а не по нашим намерениям.
// Список событий первого руля. Нужен ровно для одного случая: когда
// F9GridFinsDeploy вернул 0 из 4, а рули при этом явно работают (в прогоне
// они держали 25 градусов угла атаки с отставанием меньше градуса). Значит
// подходящего события в модуле нет, и гадать, как оно называется, дешевле
// один раз напечатать, чем править вслепую.
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

// --- Копоть после входа в атмосферу ---
//
// ModuleTundraSoot стоит на баке, межступеннике, октавебе и носовом конусе
// (ShowTransitionEvent = True, то есть событие в меню детали есть). В меню
// оно подписано "Toggle Soot" со значением Off.
//
// Имя события подбирать не буду - на решётчатых рулях это уже стоило
// нескольких прогонов. Ищем по куску слова во ВСЕХ модулях детали, как
// F9PartDoEventLike, а если не нашли - печатаем, что там вообще есть.
// --- Что вообще можно отвести перед стартом ---
//
// Стрела Ghidorah ищется по имени и по паре модулей, и на связке с башней
// Crew Dragon не нашлась: там другая деталь. Гадать её имя по конфигам
// мода я не буду - это уже дважды выходило боком (рули, копоть).
//
// Вместо этого перечисляем ВСЁ, что на судне умеет анимироваться и при этом
// не является рулём или опорой. Список печатает f9check, и по нему сразу
// видно и имя детали, и как называется её событие.
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

// --- Дальность физики ---
//
// Ставится ЧУЖОМУ судну, и это главное. Так делает starship.ks:
//   set vessel(tgt:name):loaddistance:prelaunch:load to ...
//
// Логика KSP: грузить или паковать судно решается по ЕГО собственным
// дистанциям, но менять их должен тот, кто в этот момент живёт - то есть
// активное судно. Вторая ступень поднимала дистанции себе сама, и это
// работало ровно до того момента, как её упаковали: упакованное судно свой
// процессор не крутит и переставить ничего уже не может.
//
// Поэтому первая ступень, которая остаётся активной, делает это за неё и
// повторяет по ходу спуска.
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
    // Четвёртый диапазон - PRELAUNCH. У starship он есть, у нас его не было,
    // и это единственное расхождение с оригиналом.
    //
    // Отступы здесь ДРУГИЕ - 250/500/750 вместо 5000/2500/10000. Так у
    // starship, и это осмысленно: на столе судно стоит вплотную к тому, на
    // что смотрит игрок, и растаскивать пороги на километры незачем.
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

// Копоть - это ПОЛЕ, а не событие. f9check показал:
//   [поле] (settable) toggle soot, is Boolean
// Поэтому не doevent, а setfield. Заодно это делает включение
// идемпотентным: повторный вызов не выключит копоть обратно, как выключил бы
// повторный toggle.
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

// Что модуль вообще предлагает - на случай, если событие не нашлось.
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

// ---------------------------------------------------------------------
// Посадочные опоры. KRE ставит их на колёсную механику (ModuleWheelDeployment),
// поэтому они же ходят по стандартной группе GEAR - ей и пользуемся, а модуль
// держим как запасной путь.
// ---------------------------------------------------------------------
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

// ---------------------------------------------------------------------
// Холодный газ - им ступень переворачивается в вакууме, где рули не работают.
// ---------------------------------------------------------------------
set F9ColdGas to F9Find("F9[._]CGT").
if F9ColdGas:length = 0 set F9ColdGas to F9Find("CGT").
if F9ColdGas:length = 0 F9Note("cold gas not found - turns will use reaction wheels").

// ---------------------------------------------------------------------
// Стрела пусковой платформы Ghidorah.
//
// Деталь TE_Ghidorah_Erector: ModuleAnimateGeneric с событиями "Open
// Erector" / "Close Erector" плюс ModuleTundraDecoupler со staged = true.
// Декаплер сидит в ОДНОЙ стадии с зажиганием первой ступени (istg 2 у
// обоих), поэтому развести отвод стрелы и запуск двигателей стейджингом
// нельзя - двигатели придётся зажигать напрямую, а stage оставить на
// отпуск. Смотри предстартовую последовательность в f9s1.
// ---------------------------------------------------------------------
// Что отводится перед стартом.
//
// Искать по ИМЕНИ детали оказалось тупиком: на связке Ghidorah стрела звалась
// Ghidorah.Erector, а на башне Crew Dragon это уже две другие детали -
// 39A.pad с событием "retract erector" и FSS с "retract crew access arm"
// (показал f9check). Имён пусковых сооружений столько, сколько модов.
//
// Поэтому ищем по СОБЫТИЮ. Событие называет действие, а не изготовителя, и
// переносится между площадками само.
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

// Отвод стрелы. Возвращает false, если стрелы нет или событие не нашлось,
// чтобы предстартовая последовательность могла честно об этом сказать.
// Отводим ВСЁ, что нашлось, а не одну деталь: на башне Crew Dragon это и
// стрела, и мостик экипажа, и оба мешают одинаково. Возвращаем число
// сработавших, чтобы предстартовая последовательность могла честно сказать,
// что именно отвела.
// Отпуск ракеты со стола.
//
// На связке Ghidorah отпуск делала команда stage: декаплер стрелы стоял в
// одной стадии с двигателями. На башне Crew Dragon у детали 39A.pad есть
// отдельное событие "release clamp", и это лучше - зажигание и отпуск
// разводятся во времени, как на настоящем пуске: сначала двигатели выходят
// на режим, и только потом ракету отпускают.
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

// ---------------------------------------------------------------------
// Бак первой ступени. Нужен и для остатка топлива, и чтобы отличить
// первую ступень от второй, когда скрипт стартует уже после разделения.
// ---------------------------------------------------------------------
set F9Tank to "false".
for p in F9Find("F9[._]S1[._]Tank") { set F9Tank to p. break. }
if F9Tank:istype("String") {
    // Запасной путь: самый ёмкий бак с LiquidFuel на борту.
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

// Остаток топлива первой ступени в долях от полного.
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

// ---------------------------------------------------------------------
// Запас характеристической скорости первой ступени.
//
// Мерить остаток топлива в процентах бака бессмысленно: проценты ничего не
// говорят о том, хватит ли на возврат. Считаем по Циолковскому, но массу
// берём ТОЛЬКО первой ступени - до разделения ship:mass включает вторую со
// всей её заправкой, и цифра получилась бы втрое оптимистичнее правды.
//
// Состав первой ступени собираем из деталей, которые уже опознаны выше,
// плюс межступенчатый отсек. Обходить дерево частей не нужно: список и так
// полный, а любая забытая мелочь даст ошибку в доли процента.
// ---------------------------------------------------------------------
set F9Interstage to list().
for p in F9Find("Interstage") { F9Interstage:add(p). }

set F9Isp to 300.   // между 282 у земли и 311 в вакууме
set F9MecoDvRtls to 1850.
set F9MecoDvSplash to 1000.
set F9MecoDvExp to 150.

// Баржа: boostback не нужен, но нужен запас на доворот в entry и на честную
// посадку. Splashdown в прогоне 16.09 сел с остатком ноль, не хватило около
// десяти метров в секунду - отсюда 1150, а не 1000.
set F9MecoDvAsds to 1300.

// Точка посадки на баржу. Общий файл на архиве: сюда меню кладёт цель,
// скрипт баржи читает её и туда идёт, а потом дописывает, где он оказался
// на самом деле. Первая ступень целится в фактическую позицию баржи, если
// та отчиталась, и в расчётную точку, если нет.
set F9AsdsFile to "0:/f9asds.json".

// Точка в d метрах от g по большому кругу курсом az.
function F9GeoAlong {
    parameter g, az, d.
    local dd is d / ship:body:radius * constant:radtodeg.
    local gla is arcsin(sin(g:lat) * cos(dd) + cos(g:lat) * sin(dd) * cos(az)).
    local glo is g:lng + arctan2(sin(az) * sin(dd) * cos(g:lat),
                                 cos(dd) - sin(g:lat) * sin(gla)).
    return latlng(gla, glo).
}

// Расстояние по поверхности между двумя точками, метры. Не :distance - то
// хорда сквозь планету от судна и с высотой.
function F9GeoArc {
    parameter g1, g2.
    local a is sin((g2:lat - g1:lat) / 2) ^ 2 +
               cos(g1:lat) * cos(g2:lat) * sin((g2:lng - g1:lng) / 2) ^ 2.
    return 2 * arcsin(sqrt(min(1, a))) * constant:degtorad * ship:body:radius.
}

// Начальный пеленг из g1 на g2, градусы 0..360.
function F9GeoBrg {
    parameter g1, g2.
    local dl is g2:lng - g1:lng.
    return mod(arctan2(sin(dl) * cos(g2:lat),
                       cos(g1:lat) * sin(g2:lat) - sin(g1:lat) * cos(g2:lat) * cos(dl)) + 360, 360).
}

// Отчёт баржи - в СВОЁМ файле. Раньше она дописывала blat/blng в общий
// файл через чтение-запись всего файла, и если ступень успевала записать
// новую точку между её чтением и записью, баржа возвращала старую.
// Читатели видят оба файла как один: отчёт баржи поверх точки.
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

// 24.09: "на месте" решает читатель по расстоянию и ходу, а не по ready.
// Баржа вдали от ступени не загружена и отчёт не пишет, а после отката
// архив остаётся от "будущего" - ready в нём от старого правила или
// старого места. Ступень целится в blat/blng, поэтому десятки метров от
// точки меню - норма. Нет bv (старый f9asog) - судим по расстоянию.
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

// Масса первой ступени сейчас и она же без топлива.
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

// Сколько метров в секунду ступень ещё может себе позволить.
function F9DvLeft {
    local m0 is F9Stage1Mass().
    local m1 is F9Stage1Dry().
    if m1 <= 0 return 0.
    if m0 <= m1 return 0.
    return F9Isp * 9.80665 * ln(m0 / m1).
}

// ---------------------------------------------------------------------
// Планета и масштаб. Ту же развилку делает booster.ks: одна и та же ракета
// летает в стоке, в KSRSS и в RSS, и от этого зависят все высоты и дистанции.
// Радиус Земли/Кербина - самый простой признак, который не врёт.
// ---------------------------------------------------------------------
set F9Body to ship:body:name.
set F9BoosterName to "F9 B".
set F9SerialFile to "0:/f9serial.json".

// Бортовой номер бустера как у SpaceX: F9 B1001, B1002... Счётчик лежит на
// архиве и растёт на единицу при каждом разделении. Нет связи - номер из
// времени игры, чтобы имя всё равно было уникальным.
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
    set F9Scale to 1.6.       // RSS, реальный размер
    set F9World to "RSS".
} else if F9Radius > 900000 {
    set F9Scale to 1.0.       // KSRSS / Sol quarter scale
    set F9World to "KSRSS".
} else {
    set F9Scale to 0.55.      // сток
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

// ---------------------------------------------------------------------
// ОКНО ЗАПУСКА - когда стартовать, чтобы попасть в ПЛОСКОСТЬ цели.
//
// Наклонения мало. Оно задаёт только угол между плоскостями, а не их
// взаимное положение: можно уйти на те же 51.6 градуса и разойтись с целью
// на сто градусов по узлу, и свести это потом стоит дороже всего полёта.
// Плоскость определяется парой (наклонение, долгота восходящего узла), и
// вторую величину ракета не выбирает - её выбирает МОМЕНТ СТАРТА, потому
// что стартовый стол едет вместе с планетой.
//
// Точка на широте la лежит в плоскости (inc, lan) тогда, когда её прямое
// восхождение th удовлетворяет sin(th - lan) = tan(la) / tan(inc). Решений
// два за оборот планеты: восходящий проход (ракета уходит на северо-восток)
// и нисходящий (на юго-восток). Если |la| > inc, решений нет вообще -
// с этой широты в такую плоскость не попасть прямым выведением.
function F9PlaneDelta {
    parameter incl.
    local ii is abs(incl).
    if ii < 0.01 or ii > 179.99 return -999.
    local ss is tan(ship:latitude) / tan(ii).
    if abs(ss) > 1 return -999.
    return arcsin(ss).
}

// Прямое восхождение стартового стола СЕЙЧАС. body:rotationangle - угол
// нулевого меридиана планеты в той же опорной системе, в которой KSP
// считает долготу восходящего узла, поэтому их можно вычитать напрямую.
function F9SiteRa {
    return mod(body:rotationangle + ship:longitude + 720, 360).
}

// Секунды до ближайшего прохода стола через плоскость (inc, lan).
// asc = true - восходящий проход, false - нисходящий.
function F9WindowSec {
    parameter incl, lan, asc.
    local dd is F9PlaneDelta(incl).
    if dd < -900 return -1.
    local th is lan + dd.
    if not asc set th to lan + 180 - dd.
    return mod(th - F9SiteRa() + 720, 360) / 360 * body:rotationperiod.
}

// Азимут для выбранного прохода. Нисходящий - зеркало восходящего
// относительно направления на восток.
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

// ---------------------------------------------------------------------
// Отчёт. Первое, что нужно увидеть в игре: скрипт опознал ракету или нет.
// ---------------------------------------------------------------------
function F9Report {
    clearscreen.
    print "=== Falcon 9 - hardware check ===".
    print " ".
    print "World:      " + F9World + "  (radius " + round(F9Radius/1000) + " km, Scale " + F9Scale + ")".
    print "Octaweb:    " + (choose F9Octaweb:name if not F9Octaweb:istype("String") else "NONE").
    print "  modes:    " + (choose "yes" if not F9EngSwitch:istype("String") else "NO SWITCH").
    // Показываем и число двигателей, и сырую строку режима: если мод
    // переименует режимы, это будет видно сразу, а не в полёте.
    print "  mode:     " + F9EngineCount() + " eng. [" + F9ModeName() + "]".
    print "  thrust:   rated " + F9ModeThrust(F9EngineCount()) +
          " kN, live " + round(ship:maxthrust, 1) + " kN".
    print "Grid fins:  " + F9GridFins:length + " pcs".
    print "Legs:       " + F9Legs:length + " pcs" + (choose "  (DEPLOYED)" if F9LegsDeployed() else "").
    print "Cold gas:   " + F9ColdGas:length + " pcs".
    // Копоть в отчёте, чтобы проверять её на столе, а не по факту входа в
    // атмосферу: включается она один раз за полёт, и переигрывать пуск
    // ради проверки имени события дорого.
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
