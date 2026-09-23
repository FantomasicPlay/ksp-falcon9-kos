// =====================================================================
// f9.ks - полёт первой ступени Falcon 9 (Tundra Exploration + KRE).
//
// Запускать с процессора ПЕРВОЙ ступени (он стоит на TE.19.F9.S1.Interstage),
// стоя на столе:   RUN f9.
//
// Скрипт ведёт ступень от старта до MECO и разделения. Возврат (boostback,
// entry burn, посадка) добавляется следующим куском - сначала надо увидеть,
// что вывод и точка MECO вменяемые, иначе возвращать будет нечего.
//
// ВАЖНО про два компьютера: kOSProcessor есть и на второй ступени, ею
// занимается f9s2. После разделения физику KSP считает только для активного
// судна и всего в 22 км от него, а FMRS на Falcon 9 не работает - отыграть
// вторую ступень задним числом не получится. Поэтому оставайся на первой,
// если хочешь её посадить: улетишь ко второй - эта замрёт на полуслове.
// Вернёшься - скрипт перезапустится и подхватит посадку с текущей фазы.
//
// BoosterGuidance на ступени тоже стоит и тоже хочет рулить. Держи его
// выключенным, пока летает этот скрипт, иначе они будут драться за руль.
// =====================================================================

run once f9lib.

// ---------------------------------------------------------------------
// Настройки вывода. Всё, что в метрах и метрах в секунду, умножается на
// F9Scale: одна и та же ракета летает в стоке, в KSRSS и в RSS, и высоты
// там отличаются в разы. F9Scale приходит из f9lib по радиусу планеты.
// ---------------------------------------------------------------------
set F9Azimuth to 90.              // курс выведения, 90 = на восток

// Высоты профиля считаем ДОЛЯМИ ОТ АТМОСФЕРЫ, а не от радиуса планеты и не
// от F9Scale. Радиус и атмосфера в этих сборках масштабируются по-разному:
// в Sol quarter радиус Земли четвертной, а граница атмосферы - 80 км, в RSS
// это 100 км, в стоке - около 14. Ракета, чей профиль привязан к радиусу,
// в quarter заканчивает работу первой ступени на 20 км, где воздух ещё
// плотный и холодный газ развернуть ступень не может. Доля же от атмосферы
// переносится между сборками сама.
//
// Ориентир - настоящий Falcon 9: MECO около 65 км при линии Кармана 100 км,
// то есть примерно две трети высоты атмосферы.
set F9Atm to body:atm:height.
set F9ClearAlt to 200 * F9Scale.    // клиренс башни, от атмосферы не зависит
set F9TurnStart to F9Atm * 0.03.    // начало гравитационного разворота
set F9TurnEnd to F9Atm * 0.50.      // высота выхода на конечный угол
set F9TurnFinal to 25.              // угол над горизонтом в конце разворота
set F9TurnPow to 1.10.              // форма кривой, см. F9Pitch

// Крен на подъёме только ГАСИТСЯ, угол не выдерживается. Две попытки до
// этого были мимо, обе по одной причине - я не читал, что делает менеджер.
//
// Как оно устроено на самом деле (документация SteeringManager): пока
// ошибка по носу БОЛЬШЕ ROLLCONTROLANGLERANGE, kOS только гасит угловую
// скорость крена и не догоняет угол. И отдельно: при рулении ВЕКТОРОМ kOS
// всё равно достраивает до Direction, "выбрав произвольный крен" - то есть
// цель по крену прыгает от кадра к кадру. Это и есть дёрганое вращение.
//
// Окно 0.2 градуса было ошибкой, и телеметрия это показала. На подъёме в
// логе стоит "e-0.2/12" ... "e-0.4/21": по носу регулятор держит 0.2-0.4
// градуса, то есть отлично, а по крену копится 11-21. Причина ровно в окне:
// оно стоит на 0.2, а ошибка по носу колеблется вокруг тех же 0.2-0.4 -
// управление креном то включается, то выключается на каждом кадре. Отсюда и
// дёрганье, и то, что крен никогда не доходит до нуля.
//
// Раз по носу ступень держится на четверти градуса, крен ей по силам.
// Возвращаю штатное окно 5 градусов - оно заведомо шире колебаний ошибки,
// значит управление креном будет включено постоянно, - и делаю его вдвое
// резче штатного (roll TS 5 против прежних 30), чтобы 20 градусов не
// выбирались весь полёт.
set F9Roll to 0.
set steeringmanager:rollcontrolanglerange to 5.

// Настройка самого ПИД-регулятора. SteeringManager - это и есть PID, но с
// коэффициентами, посчитанными под ракету с нормальной управляемостью:
// Ki = I * (4 / TS)^2, Kp = 2*sqrt(I*Ki), где TS - время успокоения. Чем TS
// БОЛЬШЕ, тем мягче реакция.
//
// У нас на два градуса качания сопел приходится 48-тонная дура: регулятор
// просит момент, которого нет, копит интеграл и потом перекладывает рули в
// другую сторону - это и выглядит дёрганьем. Растягиваем время успокоения:
// по тангажу и рысканью вдвое против стандартного, по крену ещё сильнее,
// там управляемости меньше всего.
//
// MAXSTOPPINGTIME ограничивает скорость доворота тем, что ступень успеет
// остановить. Тоже поднимаем: медленнее начинает - меньше перелёт.
set steeringmanager:pitchts to 4.
set steeringmanager:yawts to 4.
set steeringmanager:rollts to 5.
set steeringmanager:maxstoppingtime to 4.


// Почему профиль такой крутой. Для миссии с возвратом на площадку вертикаль
// выгоднее горизонта дважды: она поднимает MECO выше без лишнего топлива и
// сразу уменьшает горизонтальную скорость, которую потом всё равно пришлось
// бы гасить boostback-ом. На графиках реальных пусков это видно прямо:
// RTLS-миссии уходят на 65-87 км при downrange всего 25-50 км, а миссии на
// баржу с тех же высот улетают на 75-120 км - им гасить ничего не нужно.
//
// Проверка модели: при прошлых 85% и 20 градусах формула давала на 21.5 км
// угол 51.7, в полёте вышло 52 - кривая описывает реальность верно.

// --- ГЛАВНЫЕ РУЧКИ. Их и крутим, остальное трогать не надо. ---
//
// Высота MECO. Теперь это ГЛАВНЫЙ критерий, а запас топлива - только пол
// под ним.
//
// Раньше было наоборот, и получалось вот что: двигатели работали, пока в
// баке не останется 1000 м/с, ступень к этому моменту забиралась на 56 км
// и улетала по инерции на апогей 137. С такого апогея она возвращается
// почти отвесно и на скорости, которую воздух уже не успевает съесть -
// в прошлом прогоне на 6.5 км было ещё 891 м/с при реальных ~300.
//
// Глушим на 40 км. Ступень остаётся ниже, летит положе, входит в плотные
// слои под меньшим углом и дольше по ним идёт - это и есть торможение,
// которое не стоит топлива.
set F9MecoAlt to 40000.

// Разделение сразу после MECO, на той же высоте. Отдельная высота
// разделения больше не нужна: она была нужна, только пока MECO случался
// низко и ступень надо было донести до разрежённого воздуха по инерции.
set F9SepWait to 3.                 // секунд на успокоение перед stage
set F9HoldDown to 2.               // секунд на захватах после зажигания
set F9Countdown to 20.
set F9Mission to "Falcon 9 Launch Test".
set F9TelEvery to 0.1.
set F9TelEveryLand to 0.25.

// Пауза ПОСЛЕ разделения, прежде чем трогать руль и холодный газ.
//
// Сразу после расцепки вторая ступень ещё висит прямо над межступенником.
// Если в этот момент начать разворот к ретроградному, длинная ступень
// поворачивается и цепляет соплом второй; а холодный газ бьёт ей прямо в
// двигатель. Обе - ровно то, что ты видел.
//
// Десять секунд на скорости расхождения от толкателей - это уже десятки
// метров, и обе ступени идут по инерции, так что терять нечего.
set F9SepCoast to 10.
set F9SepCoastRtls to 3.             // RTLS: короче, по Егору 21.09

// Дальность физики, которую первая ступень держит вокруг ВТОРОЙ.
// Переставляется заново, потому что KSP сбрасывает vesselRanges при смене
// ситуации судна, а она на выведении меняется как раз посередине.
// 1.65 млн метров - столько же, сколько просит booster.ks для Superheavy.
// Пятисот километров не хватило, а занижать смысла нет: если KSP обрежет,
// это будет видно в строке "физика: просил ..., стоит ...".
set F9S2LoadDist to 1650000.
set F9S2DistEvery to 5.            // секунд между переустановками
set F9S2Name to "".
// Сама S2 - объектом, не по имени: у старых S2 на орбите то же имя, и
// vessel(имя) возвращал прошлую (21.09: "S2 НА ОРБИТЕ" через 20 с после sep).
set F9S2Ves to 0.
set F9NextS2Dist to 0.

// Прогноз вех для оверлея (F9TelEta, F9-KARTA "Вехи: формулы").
set F9EntryAlt to F9Atm * 0.50.    // начало тормозного импульса входа
set F9SimIgnH to 0.
set F9AtmR to 8.314462.            // Дж/(моль·К), для F9AtmRho
set F9EtaQT to 0.                  // прошлый замер для ускорений прогноза Max Q
set F9EtaQVs to 0.
set F9EtaQVv to 0.
set F9EtaQA to 0.
set F9EtaQAv to 0.
set F9S2SecoEta to -1.
set F9TelEtaStr to "".
set F9TelEtaT to 0.
set F9TelM2 to 0.                  // масса S2 с грузом, снимается на столе
set F9S2ThrKn to 580.              // тяга MVac, кН (TE_19_F9_S2_Engine)
set F9S2IspV to 348.               // Isp MVac, с
set F9S2DvNeed to 3400.            // м/с S2 от разделения до орбиты
set F9S2BurnK to 1.8.              // прожиг / прожиг на полной тяге (растяжка)
set F9S2IgnDelay to 5.             // с от разделения до SES-1
set F9TelFlipEst to 22.            // с на разворот под boostback
set F9TelThrAvg to 0.85.           // средний газ S1 до MECO (напор, перегрузка)

set F9CoastFlipErr to 5.
set F9RcsOnErr to 8.
set F9RcsOffErr to 2.
set F9RcsOffRate to 0.5.
set F9RcsGate to false.
set F9LastVesselChange to 0.
set F9S2Orbit to false.

// Режим возврата:
//   "splashdown" - никакого boostback и никакого наведения. Ступень просто
//                  тормозит и садится вертикально туда, куда её несёт, то
//                  есть в океан. Учимся мягко касаться, не воюя за точность.
//   "rtls"       - полный возврат на площадку старта.
// Пока не научимся садиться, точность только мешает: любой промах можно
// списать и на наведение, и на посадку, и разобраться будет нельзя.
//
// Объявлен ВЫШЕ порога MECO: порог от режима зависит, а в прошлой правке
// режим стоял ниже, и строка порога читала ещё не созданную переменную.
set F9Mode to "rtls".

// Запас на возврат - в МЕТРАХ В СЕКУНДУ, а не в процентах бака.
//
// Проценты ничего не говорят о том, хватит ли долететь: одна и та же доля
// бака при разной массе ступени даёт разный запас. Считаем по Циолковскому
// с массой только первой ступени - F9DvLeft() в библиотеке.
//
// Порог зависит от режима, и сильно.
//
// splashdown: нужны только тормозной импульс входа и посадка. 1000 м/с
// хватает - проверено, ступень села.
//
// rtls: сверху ложится boostback, а он тем дороже, чем больше горизонтальной
// скорости успела набрать ступень. Значит глушить двигатели надо РАНЬШЕ, а
// не искать топливо потом. По телеметрии подъёма: запас 1854 м/с приходится
// на 37.5 км, 1546 - уже на 43.6 км; в этом окне ступень ещё не разогналась
// вдоль горизонта, и возврат обходится дёшево.
set F9MecoDv to F9MecoDvSplash.
// 1850, а не 1700: в прогоне с возвратом ступень дошла до посадки и
// кончилась на 94 метрах. Считая по логу - boostback съел 831 (1697 -> 866),
// к четырём с половиной километрам осталось 542, а посадочный импульс с
// 277 м/с стоит около 534 вместе с гравитационными потерями. Не хватило
// буквально десятков.
//
// Ранний MECO помогает дважды: и запас больше, и горизонтальной скорости
// меньше - значит и boostback дешевле.
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
    // Баржа летит по тому же профилю, что и приводнение - boostback не
    // нужен, ступень садится там, куда её и так несёт. Отличие только в
    // запасе и в том, что у неё есть цель.
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

// Есть ли у возврата ЦЕЛЬ. Площадка и баржа с точки зрения наведения - одно
// и то же: прицел, боковой профиль, доворот в планировании, отчёт о промахе.
// Разница только в boostback (баржа стоит там, куда ступень и так летит) и в
// том, откуда берутся координаты.
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

// MECO идёт по ОСТАТКУ топлива, а не по скорости: если сначала выжать
// скорость, а потом смотреть на бак, возвращаться будет уже нечем - ровно
// на этом сгорел бустер у человека из фидбека, метан кончился на 779 м.
// Сам порог задан выше, в ручках.

// Дросселирование на максимальном скоростном напоре. Реальный F9 душит
// двигатели около Max Q; заодно это бережёт решётчатые рули.
set F9QOn to 0.10.
set F9MaxQ to 0.12.
set F9QThrottle to 0.72.

// Второе ограничение тяги - по перегрузке. Ступень пустеет на глазах, и к
// концу работы те же 2560 кН разгоняют уже почти голый бак: без потолка
// ракета в конце просто выстреливает. На графиках реальных пусков видно,
// что Falcon упирается примерно в 3-3.5 g и дальше душит двигатели.
set F9MaxG to 3.2.

// Локальное g - нужно уже на старте, для честного TWR в отчёте.
function F9GLocal0 {
    return body:mu / (body:radius + ship:altitude) ^ 2.
}

// ---------------------------------------------------------------------
// Проверки до старта. Дешевле не взлететь, чем разбираться в полёте.
// ---------------------------------------------------------------------
clearscreen.
F9Report().

// Печатаем то, что реально встало в рулевой менеджер. Настройки, заданные
// вслепую и не проверенные, у меня уже дважды оказывались не тем, чем я
// думал, - пусть говорят сами за себя.
print "PID: pitch/yaw TS " + steeringmanager:pitchts +
      "/" + steeringmanager:yawts + ", roll TS " + steeringmanager:rollts +
      ", roll window " + steeringmanager:rollcontrolanglerange.

// Кто считает точку падения. Без этой строки не отличить работу по
// Trajectories от работы по моей баллистике, а ведут они себя по-разному.
if addons:tr:available {
    print "impact prediction: Trajectories".
} else {
    print "impact prediction: built-in ballistics (no Trajectories)".
}
print " ".

// Кто мы. Процессор первой ступени стоит в Interstage, второй - в
// Fairing.Adapter. До разделения судно одно и по железу их не различить,
// поэтому спрашиваем деталь, в которой сидим.
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

// Стоим ли мы ещё на столе. Boot перезапускает скрипт каждый раз, когда
// возвращаешься к судну, поэтому отличать пуск от подхвата надо до того,
// как что-то трогать: в полёте ступень идёт на трёх или одном двигателе, и
// переключать её в девять - последнее, что стоит делать.
set F9OnPad to (ship:status = "PRELAUNCH").

if F9OnPad {
    if not F9SetEngineMode(9) {
        print "COULD NOT SET All Engines - launch aborted.".
        wait until false.
    }
}
print "engine mode: " + F9ModeName().

// Точка возврата.
//
// Задана ЯВНО координатами посадочной зоны, а не позицией стола: LZ стоит в
// стороне от старта, и садиться "под себя" - это садиться в чужой квадрат.
// Цифры твои: 28 18' 03" N, 80 20' 39" W.
//   28 + 18/60 + 3/3600    = 28.300833
//   80 + 20/60 + 39/3600   = 80.344167, западная - значит минус.
//
// Ноль в F9PadLat означает "площадки нет, беру позицию стола" - на случай
// пуска с другого космодрома.
// Смещение ТОЧКИ ПОСАДКИ относительно посадочной зоны, в метрах.
//
// Это не то же самое, что F9LngBias, и путать их не надо. F9LngBias
// компенсирует физику - сколько downrange съедает посадочный импульс, и
// живёт в баллистическом прицеле. А это осознанный сдвиг самой точки, куда
// садиться: центр зоны не всегда там, где хочется сидеть.
//
// Ноль в обоих - "ровно в посадочную зону", это значение по умолчанию.
//   Along - вдоль курса подхода, плюс = дальше за зону
//   Side  - вправо от курса подхода
//
// 20 метров вперёд - по четырём посадкам подряд. Недолёт оказался
// СИСТЕМАТИЧЕСКИМ, а не случайным: 22, ~20 и 19.4 метра, все три
// в одну сторону (четвёртый прогон, 112 м, имел свою причину -
// болтанку газа, она уже убрана).
//
// Систематическую ошибку закрывают ПРИЦЕЛОМ, а не доворотами у земли:
// ты сам это сказал - Falcon 9 не Superheavy, последние десятки метров
// ему закрывать нечем, и попытка кончается тем, что он ложится боком.
set F9PadOffAlong to 20.
set F9PadOffSide to 0.
set F9PadOffLand to F9PadOffAlong.

set F9PadLat to 28.300833.
set F9PadLng to -80.344167.

// Баржа. Точку считает САМА СТУПЕНЬ и ещё на столе: она одна знает курс,
// режим и резерв на MECO, и она же после каждой посадки пишет, куда попала
// на самом деле. Прогноз кладётся в общий файл, баржа его читает и идёт
// туда. Обратно баржа дописывает свою фактическую позицию - в полёте
// прицел переносится на неё (F9AsdsRefresh), потому что садиться надо
// туда, где палуба, а не туда, где ей полагалось быть.
//
// Сам прогноз - среднее по прошлым посадкам с тем же курсом И В ТОМ ЖЕ
// РЕЖИМЕ. Режим здесь не формальность: приводнение садится на 214 км
// (три прогона 16.09: 214.3, 214.5, 216.4), а баржа с её большим резервом
// на MECO - на 193.4. Смешивать их значит промахнуться на двадцать
// километров, что вечером 16.09 и вышло.
//
// Истории нет - откладываем F9AsdsDefDown по большому кругу.
// Смещение прицела для баржи. Недолёт СИСТЕМАТИЧЕСКИЙ, и закрывать его
// надо прицелом заранее, а не доворотами у палубы.
//
// Замер по двум прогонам 16.09 ночью, курс 42.73, баржа на месте:
//   касание N -147 / E -163 от баржи -> вдоль подхода -218 м
//   касание N -123 / E -136           -> вдоль подхода -182 м
// Оба недолёт, разброс 36 метров. Среднее - 200, его и ставим.
// Боковая часть -20 и -17 метров - это уже уровень шума, вбок не двигаем.
//
// Уходит это число в F9LngBias - в БАЛЛИСТИЧЕСКИЙ прицел, а не в
// F9PadOffAlong. Разница принципиальная: баллистический прицел двигает
// точку, за которую дерутся entry burn и планирование, то есть промах
// закрывается высоко и дёшево. F9PadOffAlong двигал бы цель посадочного
// импульса, а это доворот наклоном у самой палубы - ровно то, от чего
// уходим. Складывать их нельзя: получится двойной счёт и перелёт.
// Двести метров были взяты с потолка. Три прогона подряд дали закон:
// посадочный импульс проходит по горизонту ровно 5.15 горизонтальной
// скорости на зажигании (624/121, 675/132, 696/135 - совпадение до
// процента), а баллистика на том же месте прошла бы vh*t_падения. Разница
// и есть потребный прицел: 143, 232 и 244 метра. Константа в двести давала
// -57, +32 и +44 - ровно те промахи, что и вышли. Для нынешнего прихода
// (гор 135, падение 7 с) нужно 245.
//
// Прогон 22:48 на 245 дал перелёт 29 м (по координатам; терминал показал
// недолёт 43 - у него был сломан знак). Четыре прогона: 200 -> +24, -36,
// -47 и 245 -> +29. Наклон около метра промаха на метр прицела, ноль
// приходится на 220.
set F9AsdsOffAlong to 220.

set F9AsdsDeck to 0.

// ЗАМЕРЕННАЯ высота настила баржи над водой, метры. Ноль означает "верить
// тому, что прислала баржа".
//
// Верить ей нельзя. Баржа меряет себя через ship:bounds, то есть до самой
// верхней точки корпуса - мачты, а не настила, и присылает 6.3-7.0 метра.
// Прямой замер 23:18: ступень стоит на настиле после посадки, alt:radar
// 33.1, вылет опор 31, значит настил 2.1 метра. Ошибка в четыре с лишним
// метра - ровно на столько F9H занижалась, и ровно с такой высоты ступень
// падала после останова двигателя.
set F9AsdsDeckFix to 2.1.

// Старше этого отчёт баржи считается протухшим: она либо не загружена, либо
// её скрипт не работает.
set F9AsdsStale to 120.
set F9AsdsDefDown to 193000 * F9Scale.
set F9AsdsAzTol to 2.
// 23.09: 177.28 т -> 174.33 т дали +20.7 км естественной точки, 7.0 км/т.
set F9AsdsKmT to 7.0.
set F9AsdsMdvOld to 1150.
set F9AsdsKmDv to 70.

// Опорная точка - НЕ прошлый полёт, а один зафиксированный: естественная
// точка после entry полёта 23.09 22:05 (груз 1.2 т). Брать каждый раз
// прошлый полёт нельзя: его точка зависит от того, где стояла баржа, и
// баржа ползла к старту (F9-KARTA "Точка баржи формулой").
set F9AsdsRefLat to 28.53336.
set F9AsdsRefLng to -72.36060.
set F9AsdsRefAz to 88.1525.
set F9AsdsRefMp to 1074.38.
set F9AsdsRefDv to 1300.
// Баржа дальше естественной точки: глайд должен добирать вперёд, а не
// срезать перелёт. В удачных посадках было 1.1-1.3 км.
set F9AsdsGlideMargin to 1500.

// Прогноз точки - ДАЛЬНОСТЬ и ПЕЛЕНГ от стола, оба по координатам прошлых
// посадок. Прежнее "down" мерилось хордой от посадочной зоны LZ, а
// откладывалось от стола - разные начала.
//
// Пеленг не равен курсу: трасса загибается. Посадки на курсе 88.2 легли на
// пеленгах 85.68, 85.83, 85.71 - увод 2.5 градуса, 9-10 км влево на 225 км,
// все три с разбросом 700 м. На курсе 40.6 увод 0.25 градуса. Поэтому увод
// берётся с посадки с ближайшим курсом.
//
// Дальность - с посадки с ближайшей стартовой массой, сдвинутая на разницу
// масс: F9AsdsKmT км на тонну (оценка, пока нет двух посадок с разной массой;
// потом наклон по ним). Записи без "m0" встают в очередь последними.
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

// Прогноз падения из Trajectories - в файл, для следующего полёта. Заодно
// видно прямо в полёте, куда ступень идёт на самом деле: если это далеко
// от баржи, садиться на палубу уже не получится.
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

// Перенос прицела на баржу, если она отчиталась. Зовётся и на столе, и в
// полёте: пока ступень поднимается, баржа ещё идёт к точке.
// Готовность баржи ПЕРЕД пуском, а не догадки после посадки.
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

// Публикация прогноза. Зовётся дважды: при загрузке скрипта (курс из
// f9cfg.json, баржа успевает выйти) и заново по команде ПУСК, если в меню
// поменяли курс - тогда точка пересчитывается под фактический пуск.
function F9AsdsSetup {
    if F9Mode <> "asds" or not F9OnPad return.
    // Двадцать метров "за зону" - это поправка СУХОПУТНАЯ, снятая на LZ-1
    // по четырём посадкам с систематическим недолётом. У баржи снос другой:
    // 22:12 с двадцатью сел +3 от прицела, 22:23 с нулём -37. Среднее по
    // двум прогонам -17. Разброс шёл от состояния на зажигании, и его
    // закрывает F9LandKappa, а не смещение цели. Складывать их нельзя:
    // масштаб профиля считается от расстояния до САМОЙ баржи, значит целить
    // надо тоже в баржу.
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

// Выбор точки возврата под текущий режим. Зовётся при загрузке и заново по
// ПУСК: режим мог смениться в меню (asds -> rtls), а точка, палуба и
// смещение оставались от баржи (баг 21.09 17:48).
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

// Прогноз вех, MET в секундах, -1 = нечем считать (оверлей берёт шаблон
// режима со сдвигом). Формулы - F9-KARTA "Вехи: формулы".
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

    // Max Q: ускорения по модулю скорости и по вертикали - по двум замерам
    // (сглажено), дальше прогон q = 1/2 rho v^2 вперёд с шагом 2 с до пика.
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

// Рули и опоры на старте должны быть сложены. KRE спавнит их сложенными,
// но крафт мог сохраниться иначе.
// ---------------------------------------------------------------------
// Всё, что ниже до разделения - работа со стола. При подхвате в полёте
// этот блок пропускается целиком и скрипт идёт сразу к возврату.
// ---------------------------------------------------------------------
if F9OnPad {

    // Пуск - кнопкой на экране, а не группой действий. Групп у ракеты и так
    // занято достаточно, а кнопку видно и случайно её не нажать.
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
                // Меню выбрало ASDS ещё на столе - точка барже сразу.
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

    // ---------------------------------------------------------------------
    // Предстартовая последовательность: отвод стрелы, затем пуск.
    //
    // Зажигание и отпуск делает ОДНА команда stage - декаплер стрелы стоит
    // в той же стадии, что и двигатели (istg 2 у обоих), и развести их
    // нечем. Прямая активация двигателя тут не годится: Engine:ACTIVATE
    // зажигает все три ModuleEnginesFX детали разом, то есть 9 + 3 + 1 = 13
    // камер и 5030 кН вместо 2560 - проверено в полёте, MECO уезжает с
    // T+87 на T+52. Переключатель Tundra про такую активацию не знает.
    // ---------------------------------------------------------------------
    print " ".
    sas off.
    rcs off.
    lock steering to heading(F9Azimuth, 90, F9Roll).
    lock throttle to 1.

    // F9ErectorOpen теперь возвращает ЧИСЛО отведённого, а не да/нет: на
    // башне Crew Dragon отводить надо и стрелу, и мостик экипажа.
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

    // Зажигание и отпуск РАЗВЕДЕНЫ, если площадка это позволяет.
    //
    // На связке Ghidorah развести их было нечем: декаплер стрелы стоял в
    // одной стадии с двигателями, и stage делал сразу и то, и другое. У
    // 39A.pad есть отдельное событие release clamp, и тогда порядок
    // становится нормальным пусковым: сначала двигатели выходят на режим,
    // тяга проверяется, и только потом ракету отпускают. Если что-то не
    // запустилось, ракета остаётся на столе, а не падает на него.
    set F9Clamped to F9HasClamp().
    if F9Clamped print "T+0  IGNITION (held by clamps)".
    else print "T+0  IGNITION AND RELEASE".
    stage.
    set F9Phase to "ascent".

    // Если тяга не появилась - лучше узнать сразу, а не по факту падения
    // ракеты обратно на стол.
    wait until ship:availablethrust > 0 or F9Met > 3.
    if ship:availablethrust <= 0 {
        lock throttle to 0.
        print "NO THRUST - engines did not start.".
        wait until false.
    }
    print "  thrust " + round(ship:availablethrust, 0) + " kN, TWR " +
          round(ship:availablethrust / (ship:mass * F9GLocal0()), 2) +
          ", " + F9EngineCount() + " eng.".
    // Стартовая масса - главный признак для прогноза дальности: MECO идёт по
    // остатку топлива, и чем легче ракета, тем дальше улетает ступень.
    set F9M0 to ship:mass.

    if F9Clamped {
        // Держим до выхода на режим и до TWR больше единицы. Отпустить
        // раньше - значит уронить ракету на стол; отпустить позже дёшево.
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

    // ---------------------------------------------------------------------
    // Гравитационный разворот.
    //
    // Кривая перевёрнута: было sqrt(frac) - резко в начале, полого в конце,
    // стало frac^1.5 - почти по градусу на километр вначале и всё быстрее к
    // концу. Так ступень уходит вверх, пока воздух плотный (там наклон стоит
    // дорого: и напор, и косинус), а горизонт набирает наверху, где дёшево.
    //
    // Кривые по высотам (атмосфера 80 км), последние три поколения:
    //
    //              ^1.5/0.72/40   ^1.15/0.68/35   ^1.10/0.50/25
    //   10 км          87.4            84.0            78.8
    //   20 км          81.0            74.2            61.8
    //   30 км          72.3            63.5            43.7
    //   40 км          61.9            52.1            25.0
    //
    // Первая была свечкой: MECO на 67 градусах, горизонтальной 329 м/с.
    // Вторая положе, но MECO переехал на фиксированные 40 км, и на этой
    // высоте она всё ещё командовала 52 градуса - в полёте вышло 68.2 над
    // горизонтом и горизонтальной всего 394. Скорость не успевает лечь.
    //
    // Третья кладёт ступень на конечные 25 градусов ровно к высоте MECO.
    // Пока летаем на splashdown, горизонтальной нужно БОЛЬШЕ: чем положе
    // вход, тем дольше ступень идёт сквозь воздух и тем больше он с неё
    // снимает. Для rtls это придётся пересматривать - там горизонталь,
    // наоборот, надо потом гасить boostback-ом.
    // ---------------------------------------------------------------------
    function F9Pitch {
        local h is ship:altitude.
        if h < F9TurnStart return 90.
        if h > F9TurnEnd return F9TurnFinal.
        local frac is (h - F9TurnStart) / (F9TurnEnd - F9TurnStart).
        return 90 - (90 - F9TurnFinal) * frac ^ F9TurnPow.
    }

    lock steering to heading(F9Azimuth, F9Pitch(), F9Roll).

    // Дросселирование по напору. ship:q в kOS - в атмосферах.
    // Тяга ограничена двумя потолками сразу: напором на разгоне в плотных
    // слоях и перегрузкой ближе к MECO. Берём меньший из них - какой
    // ограничитель сейчас главный, зависит от высоты, и разводить их по
    // расписанию незачем.
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

    // ---------------------------------------------------------------------
    // Полёт до MECO. Печатаем раз в полсекунды - чаще незачем, а терминал
    // в 53 колонки от частой печати становится нечитаемым.
    // ---------------------------------------------------------------------
    set F9NextPrint to 0.
    // Глушим по ВЫСОТЕ, а запас топлива оставляем нижней границей: если
    // топливо кончится раньше 40 км, тянуть до высоты нечем и незачем.
    until ship:altitude >= F9MecoAlt or F9DvLeft() <= F9MecoDv {
        if F9Met > F9NextPrint {
            set F9NextPrint to F9Met + 0.5.
            // err - ошибки регулятора: по носу / по крену. Без них про
            // дёрганье можно только гадать, а так видно, растёт ли ошибка
            // и по какой оси регулятор не справляется.
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

    // ---------------------------------------------------------------------
    // MECO и разделение.
    // ---------------------------------------------------------------------
    lock throttle to 0.
    print " ".
    print "T+" + round(F9Met, 1) + " MECO".
    F9Mark("meco").
    set F9Phase to "coast".
    // Раскладываем скорость на вертикаль и горизонт: именно в этих осях
    // построены графики реальных пусков, и только так видно, тот ли у нас
    // профиль.
    //
    // Зелёная зона RTLS на графике "Velocity at MECO" - примерно 500..1300
    // горизонтальной при 1000..1700 вертикальной.
    //
    // Эти оси переносятся сюда БЕЗ пересчёта, и это не очевидно. Вдвое
    // меньше здесь только орбитальная скорость - то, что нужно набрать
    // второй ступени. А цена возврата первой считается по абсолютным
    // величинам: развернуть 800 м/с горизонтали стоит 800 м/с и здесь, и на
    // Земле, потому что ступень та же и тяга та же. Планета мельче - дешевле
    // выведение, но не возврат.
    //
    // Прошлый прогон дал 818 гориз и 1182 верт, вектор 1437 - это край
    // зелёной зоны. Ориентир верный, новая кривая разворота должна сдвинуть
    // точку вглубь зоны: меньше горизонтали при той же сумме.
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

    // Разделяемся сразу, на высоте MECO. Ожидание отдельной высоты больше
    // не нужно и в прошлом прогоне выглядело глупо: скрипт печатал "жду
    // высоту разделения 38 км", стоя на 56, и делил через три секунды.
    // Смысл у того ожидания был, только пока MECO случался низко.
    wait F9SepWait.
    stage.
    F9Mark("sep").
    print "T+" + round(F9Met, 1) + " SEPARATION at " +
          round(ship:altitude / 1000, 1) + " km, q=" + round(ship:q, 4).

    // Расходимся молча: руль отпущен, газ выключен. Любое движение здесь -
    // это удар межступенником или струёй по двигателю второй ступени.
    unlock steering.
    rcs off.
    // Имя уникальное, бортовой номер F9 B1001... (F9NextBooster). Одинаковые
    // имена у невернувшихся бустеров путали вторую ступень при передаче фокуса.
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

    // Запоминаем вторую ступень и берём на себя её дальность физики.
    //
    // Сразу после расхождения она единственное судно рядом, так что ищем
    // ближайшее. Дальше первая ступень остаётся активной и переставляет ей
    // дистанции по ходу спуска - сама вторая этого делать не может, её
    // процессор после упаковки не крутится.
    set F9S2Name to "".
    list targets in F9Near.
    local best is 1.0e12.
    for v in F9Near {
        if v:distance < best { set best to v:distance. set F9S2Name to v:name. set F9S2Ves to v. }
    }
    if F9S2Name = "" print "  second stage not found nearby".
    else {
        F9SetVesselLoadDist(F9S2Ves, F9S2LoadDist).
        // Читаем ОБРАТНО. PhysicsRangeExtender в сборке не установлен, и
        // KSP вполне может обрезать запрошенное своим потолком. Если тут
        // окажется 22 км вместо 500 - причина найдена, и лечится она модом,
        // а не скриптом. Гадать про этот механизм я уже дважды пробовал.
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

// ---------------------------------------------------------------------
// На той ли мы ступени?
//
// kOSProcessor стоит и на Interstage (первая ступень), и на Fairing.Adapter
// (вторая), оба без тега, и по заголовку терминала их не различить. До
// разделения это неважно - судно одно. После разделения kOS видит только
// своё судно, поэтому наличие октавеба и есть ответ.
// ---------------------------------------------------------------------
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

// Детали после разделения - уже другие объекты, перечитываем железо.
run once f9lib.

// ---------------------------------------------------------------------
// Настройки возврата. Подбираются по факту, поэтому держим их вместе.
// ---------------------------------------------------------------------
// ЧЕМ ЭТИ ДОЛИ ОБОСНОВАНЫ. Раньше они были взяты на глаз, теперь привязаны
// к реперам с инфографики реальных пусков. Работает это потому, что
// атмосфера Sol Quarter - земная, сжатая по высоте примерно в 0.8. Проверил
// по её pressureCurve из Quarter_Earth-Kopernicus.cfg против стандартной
// земной атмосферы, восемь точек от 5 до 80 км - совпадает в пределах
// десятка процентов:
//
//   Земля 10 км = 26.5 кПа   |   здесь 8 км  = 28.5 кПа
//   Земля 30 км = 1.20 кПа   |   здесь 24 км = 1.42 кПа
//   Земля 50 км = 0.080 кПа  |   здесь 40 км = 0.102 кПа
//
// Гравитация при этом ровно земная: в конфиге radius /= 4 и gravParameter
// /= 16, то есть mu/r^2 не меняется. А вот СКОРОСТИ вдвое меньше земных
// (sqrt(mu/r) при делении mu на 16 и r на 4). Отсюда правило пересчёта
// инфографики: высоты умножать на 0.8, скорости - на 0.5, а вот
// терминальную скорость НЕ трогать, она чисто аэродинамическая и при той же
// плотности и той же g остаётся прежней.
//
// Реперы с картинки, пересчитанные в доли этой атмосферы:
//   старт entry burn     10^-3 атм: 55 км реальных -> 40.1 км -> 0.50
//   плотная атмосфера    10^-2 атм: 30 км реальных -> 25.9 км -> 0.32
//   старт landing burn   0.5 атм:    5 км реальных ->  4.6 км -> 0.057
set F9BoostbackErr to 15.          // м/с, точность гашения при boostback
set F9FlipErr to 25.               // град, при какой ошибке уже зажигаться
set F9FinsAlt to F9Atm * 0.70.     // высота раскрытия решётчатых рулей
set F9EntryEnd to F9Atm * 0.32.    // нижняя граница импульса входа
// До какой скорости гасим на входе.
//
// 600 не влезает в запас: по прогону тормозной импульс с 1506 до 1078 м/с
// стоил 489 м/с из 977, и на оставшиеся 478 ушёл бы весь остаток, а на
// посадку не осталось бы ничего. Смысл импульса не в том, чтобы погасить
// всё, а чтобы ступень не влетела в плотные слои слишком быстро - дальше
// её тормозит воздух, терминальная скорость у земли около 120 м/с.
// 600 - твоя рабочая цифра с ручных посадок. Раньше она не влезала в
// запас, теперь влезает с большим запасом: MECO на 40 км оставляет 1784 м/с
// вместо прежних 996, а импульс до 1000 в прошлом прогоне стоил всего 75.
set F9EntryTargetV to 600.         // м/с
// RTLS после boostback падает круто и к 4 км приходит на 530 м/с при напоре
// ~1 атм (ASDS - 290 м/с, 0.3). Гасим глубже: запас на касании RTLS 240-400
// м/с против 150 у ASDS (21.09, F9-KARTA "RTLS"). Оценка, калибровать.
set F9EntryTargetVRtls to 450.
set F9LegsAlt to 500 * F9Scale.    // высота выпуска опор

// --- Планирование на решётчатых рулях ---
//
// Чистое ретроградное - это падение иглой: потоку подставлен только донный
// срез, и тормозить нечем. Настоящий Falcon идёт под углом атаки: корпус
// подставляет потоку бок, сопротивление вырастает в разы, а рули этот угол
// держат и заодно дают боковую силу для наведения.
//
// Отдельно: рост скорости на спуске (1031 м/с на 31.7 км против 1061 на 28)
// я сначала записал в баг - зря. По инфографике ступень идёт на терминальной
// скорости (нулевое чистое ускорение) при 1700 м/с на 35-40 км реальных, то
// есть на 28-32 наших. Терминальная скорость аэродинамическая, при земной g
// и той же плотности она не пересчитывается - значит на 30 км мы шли ВДВОЕ
// медленнее терминальной, и разгон там нормален. Смотреть надо ниже 20 км,
// где по графику терминальная падает до 800 и дальше.
//
// Угол НАБИРАЕТСЯ по напору и снимается по ВЫСОТЕ, у самой посадки.
//
// Раньше он снимался тоже по напору, выше 0.45 атм, из осторожности - я
// боялся, что на большом напоре рули не удержат момент. В прогоне вышло
// ровно то, на что ты и показал: угол доходил до 18 к 22 км, а дальше, где
// воздух наконец плотный и торможение только начинается, скрипт его убирал
// в ноль. В логе это видно построчно - "aoa 18/16.5" на 22 км и "aoa 0/0"
// на 10-13 км. Тормозить было нечем ровно там, где было чем.
//
// Опасение при этом не подтвердилось: на 22 км при напоре 0.16 атм рули
// держали 16.5 градуса из заказанных 18, отставание меньше двух градусов.
//
// Теперь угол растёт с напором и держится до самого низа, а снимается
// только перед посадочным импульсом - там нос должен смотреть ретроградно,
// иначе тяга уйдёт вбок. Снятие по высоте, а не по напору: момент включения
// импульса тоже задан высотой, и привязывать их к разным величинам значит
// однажды получить работающий двигатель при живом угле атаки.
// Обратно на 25 с семнадцати. Семнадцать я взял у Superheavy Block 3, но
// там угол работает вместе с боковым PID и на куда более длинной
// траектории; у нас с ним планирования не хватило - в логе "aoa15/11" на
// 8.7 км и посадочный импульс с 277 м/с, который и съел весь остаток.
// Знак наклона теперь верный, подъёмная сила есть, и больший угол её просто
// увеличивает.
//
// История цифр, чтобы не ходить по кругу: на 35 рули не вытянули, в логе
// "aoa35/14" при ошибке регулятора 21 градус, то есть команда выросла, а
// РЕАЛЬНЫЙ угол упал с прежних 19 до 14. Заказывать больше, чем ступень
// может отработать, хуже, чем не заказывать: регулятор всё время в насыщении
// и заодно теряет тангаж.
//
// На 25 держалось 24.2-24.8 - управляемость есть.
set F9AoAMax to 25.                // градусов от ретроградного

// Насколько команде разрешено обгонять факт. Ниже, в F9AoA, команда
// ограничивается достигнутым углом плюс этот запас - тогда угол растёт
// ровно до предела управляемости и там останавливается сам, каким бы ни был
// потолок. Это лечит насыщение без подбора цифр под каждую высоту.
// Запас поднят с 4 до 8: при четырёх угол набирался слишком лениво, к 8.7
// км команда дошла только до 15 из 25, и половина спуска прошла почти без
// планирования.
set F9AoALead to 8.

// Наведение в планировании (только rtls). Структура взята у Superheavy из
// booster.ks - там она отработана, а моя самодельная не сходилась.
//
// Чем она отличается от того, что я писал до сих пор. У меня был чистый
// пропорциональный коэффициент: угол = функция(промах). У такой схемы нет
// интеграла, поэтому установившаяся ошибка не убирается в принципе - она
// ровно та, при которой пропорциональная поправка уравновешивает снос. Все
// прошлые прогоны это и показывали: промах приходил к какой-то величине и
// там ЗАМИРАЛ (сначала на +1.0 км, потом боковой на -0.4), а я каждый раз
// крутил масштаб, то есть менял, на какой именно величине он замрёт.
//
// У Superheavy стоят два PIDLOOP, ошибка раскладывается по вектору подхода
// (LngError/LatError через vdot), и выход регулятора идёт прямо в угол
// поворота ретроградного. Интеграл и убирает остаток.
//
// Коэффициенты - оттуда же: продольный PIDLOOP(0.35, 0.3, 0.25),
// боковой PIDLOOP(0.25, 0.2, 0.15). Пределы наши: потолок угла атаки и
// потолок бокового доворота.
set F9LatMax to 12.
set F9GlideFactor to 1.15.         // множитель продольного выхода, как BoosterGlideFactor

// Смещение точки прицеливания - и это ГЛАВНАЯ ручка возврата.
//
// Trajectories предсказывает падение БЕЗ ДВИГАТЕЛЯ. Посадочный импульс
// тормозит и горизонталь тоже, поэтому реальная точка касания оказывается
// ближе баллистической. Значит целиться надо ЗА площадку - ровно на столько,
// сколько импульс съедает.
//
// У Superheavy это BoosterGlideDistance (1040-2800 м в разных версиях), и
// landingzone там смещается от impactpos именно на неё. У меня этого не было
// вовсе, отсюда и весь остаток: планирование честно свело баллистический
// промах до 80 метров (Trajectories 0.08 км), а ступень к началу вертикальной
// части оказалась в 340 метрах НЕ ДОЛЕТАЯ и так и села.
//
// Самонастройка прицела ВЫКЛЮЧЕНА. Объявление стоит здесь, а не ниже:
// предыдущей правкой я его случайно затёр вместе с куском комментария, и
// скрипт упал на "Undefined Variable Name F9BiasAuto" прямо в полёте.

// Прицел = 0: метимся РОВНО в площадку.
//
// Раньше здесь стояло смещение "за площадку" на столько, сколько съедает
// посадочный импульс, и число подбиралось. Пока импульс жёг предсказуемо,
// это работало (промах доходил до 16 м). Но с трёхдвигательной посадкой он
// стал жечь по-разному, и подбирать смещение под плавающую причину -
// значит гоняться за собственным хвостом: самонастройка успела уехать с
// 300 до 560, а промах вырос до 615.
//
// Сначала импульс должен перестать пережигать. Смещение вернём отдельной
// ручкой (F9BiasGain уже есть), когда будет что смещать.
//
// Для баржи смещать уже есть что и есть чем: недолёт замерен (два прогона,
// 218 и 182 метра), и закрывать его надо ЗДЕСЬ - в баллистическом прицеле,
// то есть ещё в entry burn и планировании. Тогда ступень приходит к
// посадочному импульсу на двести метров дальше и садится на палубу, не
// догоняя её наклоном у самой воды.
set F9LngBias to 0.
if F9Mode = "asds" {
    set F9LngBias to F9AsdsOffAlong.
    print "ballistic aim point shifted by " + F9LngBias + " m past the deck.".
}


// Команды регуляторов, со знаком. Нужны в телеметрии: без них не отличить
// "регулятор просит мало" от "регулятор упёрся в потолок".
set F9AoAOut to 0.
set F9LatOut to 0.

// Сами регуляторы. Пределы продольного переставляются каждый тик по
// текущему потолку угла (см. F9GlideDir), боковой стоит на F9LatMax.
set F9LngPID to pidloop(0.35, 0.3, 0.25, -F9AoAMax, F9AoAMax).
set F9LatPID to pidloop(0.25, 0.2, 0.15, -F9LatMax, F9LatMax).
set F9LngPID:setpoint to 0.
set F9LatPID:setpoint to 0.
// 400, а не 3000. При трёх тысячах боковой промах 200 метров давал доворот
// 0.067 градуса - меньше порога в полградуса, то есть боковое наведение не
// включалось вообще. В логе это видно построчно: "-0.2" держалось от начала
// спуска до конца и не сдвинулось ни разу.
set F9AoAqLo to 0.01.              // напор, с которого угол начинает расти
set F9AoAqFull to 0.09.            // напор, с которого держим угол целиком

// Потолок начала посадочного импульса.
//
// Без него импульс включался на 20 км: F9StopDist считает тормозной путь
// по чистой баллистике, сопротивления воздуха он не знает и на большой
// скорости выдаёт километры. Жечь там бессмысленно - воздух отнимает
// скорость даром, и до земли ступень доходит уже на терминальной.
//
// 0.057 - репер с инфографики: посадочный импульс на 0.5 атм, это 5 км
// реальных и 4.6 здесь. Я его ставил и откатывал на 0.08, потому что тогда
// ступень приходила на семь километров с 966 м/с и импульс ниже был бы
// ямой. Условие возврата выполнено: с работающим планированием она приходит
// примерно на 250 м/с.
//
// Это всё равно только ПОТОЛОК. Момент включения теперь задаёт тормозной
// путь (F9BurnMargin), и он получается ниже этой высоты.
set F9LandMaxAlt to F9Atm * 0.057.

// Окно снятия угла атаки. Привязано к высоте посадочного импульса: угол
// начинает уходить на F9AoAOffHi и полностью снят к F9AoAOffLo, то есть
// заведомо раньше, чем зажжётся двигатель.
set F9AoAOffHi to F9LandMaxAlt * 1.6.
set F9AoAOffLo to F9LandMaxAlt * 1.1.

// Отдельной ручки на момент зажигания больше НЕТ.
//
// Их было две - F9BurnMargin 0.85 на момент включения и F9ProfMargin 0.7 на
// профиль, которым потом тормозят. Момент выбирался по тормозу на двадцать
// процентов сильнее того, которым реально тормозили, и ступень приходила в
// точку зажигания со скоростью, которую её собственный профиль в этом месте
// уже не разрешал. В логе 16.09 это первый же такт импульса: факт -207,
// цель -167. Долг в сорок метров в секунду был заложен конструкцией, а не
// набран регулятором.
//
// Теперь ручка одна и она же строит профиль: F9LandK3 / F9LandK1.
// Высота опор над точкой отсчёта. Она вычитается из F9AltAbovePad, то есть
// говорит профилю, где для него ноль.
//
// Было 18 - взято на глаз и оказалось занижено вдвое. По логу последнего
// прогона: последняя строка h=32 при цели -3.2, дальше касание. Строки идут
// через 0.5 с, на скорости 3.8 м/с это два метра, значит опоры коснулись
// примерно на h=30. Профиль же считал, что до земли ещё двенадцать метров,
// и приходил к касанию на той скорости, которую планировал двенадцатью
// метрами выше - отсюда и -3.47 вместо -0.5.
//
// booster.ks делает то же самое через RadarAltOffset - это тоже измеренная
// константа, не расчётная.
set F9GearHeight to 30 * F9Scale.

// Высота опор для ПОСАДОЧНОГО ПРОФИЛЯ считается отдельно и от alt:radar, а
// не от высоты над площадкой.
//
// Почему пришлось разделить. F9AltAbovePad меряет от terrainheight ТОЧКИ
// ПРИЦЕЛИВАНИЯ. Пока ступень садится на саму площадку, это работает: в
// позапрошлом прогоне касание вышло на h=31.2 при выставленных 30. Но в
// прошлом ступень села в 157 метрах от площадки, на землю ниже бетона, - и
// та же тридцатка означала уже совсем другое. Профиль решил, что он на
// нуле, потребовал -0.5 м/с и ступень ЗАВИСЛА на восемнадцати метрах на
// 38% тяги, пока бак не опустел. Дальше падение с десяти метров.
//
// alt:radar меряет до того, что прямо под ступенью, где бы она ни садилась.
// Так же устроено у booster.ks: alt:radar минус измеренная константа
// (RadarAltOffset).
//
// 31 - ИЗМЕРЕНО дважды. Отчёт о посадке печатает alt:radar в момент, когда
// опоры уже на земле: вышло 30.8 и 31.4. Это свойство самой ступени -
// расстояние от точки отсчёта высоты до низа опор, - поэтому переносится на
// любую площадку.
//
// Сначала стояло 12, профиль считал, что под ним на восемнадцать метров
// больше, и касание выходило -3.84. С тридцатью стало -1.81.
set F9GearRadar to 31 * F9Scale.

// Страховка от зависания.
//
// По ВРЕМЕНИ, а не по высоте, и это важно. Высотный порог здесь бесполезен:
// он опирается на ту же самую константу, в которой и может быть ошибка.
// Зависание же опознаётся само по себе - ступень почти не снижается и не
// садится. Медленное снижение при этом остаётся законным, выравнивание не
// ломается.
set F9NoHoverV to 1.5.             // м/с, принудительное снижение
set F9HoverGrace to 8.             // секунд почти-нулевой скорости до срабатывания
set F9MinDesc to 0.

// ---------------------------------------------------------------------
// Профиль посадочного импульса. Три участка, считается от земли вверх.
// ---------------------------------------------------------------------
// 0.47, а не 0.8. Это и есть "начинать расчёт на посадку с двух
// километров": высота зажигания - обратная функция профиля, и задаётся она
// не высотой, а тем, насколько резко профиль тормозит.
//
// Три двигателя по паспорту 1706 кН на 31.3 т - это 54.5 м/с2. Доля 0.47
// даёт 25.6, за вычетом тяжести 16.4 м/с2 чистого торможения, и с 245 м/с
// (столько ступень приходит по трём прогонам) тормозной путь выходит 1830
// метров плюс 150 на одномоторный участок - без малого два километра.
//
// Платим временем: импульс растягивается с 8 до 15 секунд, а каждая
// секунда горения стоит 9.2 м/с тяжести - около 65 м/с сверху. Поэтому
// нижняя граница запаса в entry поднята до 480.
//
// Взамен получаем то, ради чего это и делается: пятнадцать секунд
// управляемого полёта вместо восьми, газ около половины (есть куда и
// прибавить, и убавить) и время закрыть остаточный промах наклоном,
// пока высота его ещё разрешает.
// 0.6 после прогона 16.09 ночью. Доля 0.47 верна только для прихода на
// 245 м/с; ступень пришла на 319 (после доворота entry тормозит хуже -
// косинус наклона), а высота зажигания растёт как КВАДРАТ скорости:
// вместо двух километров получилось 4.2, импульс длился тридцать секунд,
// и одна тяжесть съела 276 м/с - топливо кончилось на высоте метра.
//
// 0.6 даёт 23.5 м/с2 чистого торможения: с 245 м/с это 1.4 км, с 319 -
// 2.9 км и около 444 м/с на весь импульс. Это влезает в тот запас, с
// которым ступень реально приходит (488-505).
set F9LandK3 to 0.6.              // доля тяги трёх двигателей в профиле
set F9LandK1 to 0.7.              // доля тяги одного двигателя в профиле
set F9SwitchAlt to 150 * F9Scale.  // высота перехода с трёх на один
set F9FlareAlt to 20 * F9Scale.    // высота выравнивания
set F9FlareV to 12.                // м/с на входе в выравнивание
set F9TouchV to 1.                 // м/с на касании
set F9IgnLead to 0.2.              // с, упреждение зажигания на задержку цикла

// Высота над тем, на что садимся. Радар меряет до воды и до земли, но НЕ до
// палубы баржи - её высоту баржа сообщает сама, через общий файл.
// Поправка на палубу действует ТОЛЬКО над баржей. Прогон 16.09 вечером: у
// баржи в 13 км от точки посадки отчёт дал палубу 6.28 м, и ступень всю
// дорогу считала себя на шесть метров ниже, чем была. Радиовысотомер над
// открытой водой меряет до воды, и вычитать из него палубу, которой под
// ступенью нет, нельзя. Ближе 50 м - палуба целиком, дальше 200 - ноль,
// между ними линейно, чтобы профиль не прыгал ступенькой.
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

// Высота, на которой профиль разрешает текущую скорость. Это и есть момент
// зажигания: выше неё ступень профилю не противоречит, ниже - уже опаздывает.
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

// ---------------------------------------------------------------------
// Геометрия возврата.
//
// Точку падения считаем по плоской земле и постоянному g: время падения с
// текущей высоты при текущей вертикальной скорости, умноженное на
// горизонтальную. Это грубо и атмосферы не знает, но boostback пересчитывает
// результат каждый тик и сходится сам - точность одиночного прогноза не нужна.
// ---------------------------------------------------------------------
function F9GLocal {
    return body:mu / (body:radius + ship:altitude) ^ 2.
}

// Держим физику вокруг ВТОРОЙ ступени. Зовётся из КАЖДОГО длинного цикла
// от разделения до касания.
//
// Раньше это стояло ровно в двух местах: один раз при разделении и внутри
// цикла планирования. А между ними - ожидание разворота, boostback, полёт
// по инерции и тормозной импульс входа, то есть основная часть возврата,
// несколько минут. Ровно в это время вторая ступень и выводится, и как раз
// там она меняет ситуацию FLYING -> SUB_ORBITAL, на которой KSP сбрасывает
// vesselRanges. Переставить их в этот момент было некому - ступень
// выпадала из симуляции, и никакая цифра при разделении этому не мешала.
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
    // Детали - только у загруженной S2 (21.09 19:48: s2:parts у снятой с
    // физики S2 уронил скрипт в глайде). Снята - орбита по перигею.
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
    // SECO - перигей над атмосферой И двигатель молчит. Один перигей
    // срабатывал ещё на прожиге.
    if s2:orbit:periapsis > body:atm:height and s2thr < 1 {
        set F9S2Orbit to true.
        F9Mark("seco").
        print "  S2 IN ORBIT " + round(s2:orbit:apoapsis / 1000, 1) + " x " +
              round(s2:orbit:periapsis / 1000, 1) + " km".
        set F9S2Name to "".
        return false.
    }
    // Прогноз SECO по живой S2: dv до круговой на текущем радиусе при
    // текущей тяге (растяжка уже в ней).
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

// Разворот по тангажу одним импульсом (21.09 18:26, F9-KARTA "Флип
// разгон-инерция-торможение"). Штатный PID на слабом газе разгонялся и
// тормозил каждую секунду. Здесь сырое управление: газ толкает до скорости
// wMax, дальше ступень крутится по инерции, тормозит один раз так, чтобы
// встать у цели. Знак ship:control:pitch проверяется по факту на разгоне.
// tgtFn - делегат, куда смотреть (вектор), берётся проекция в плоскость
// тангажа, как у F9PitchOnly. Руль после возврата ставит вызывающий.
set F9FlipRateMax to 10.           // град/с, потолок скорости разворота
set F9FlipAlpha0 to 2.             // град/с^2, угловое ускорение до замера
set F9FlipBrakeK to 1.15.          // запас на торможение
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
        // Скорость сближения со сглаживанием: один шумный замер (такт
        // F9KeepS2 гуляет) раньше перекидывал coast обратно в acc - отсюда
        // серия импульсов вместо одного.
        if thPrev >= 0 and dt > 0.05 {
            set wr to wr + ((thPrev - th) / dt - wr) * 0.5.
            set tPrev to now.
            set thPrev to th.
        } else if thPrev < 0 {
            set tPrev to now.
            set thPrev to th.
        }
        if thAcc < 0 set thAcc to th.

        // Состояния только вперёд: acc -> coast -> brake -> done. Назад в
        // acc - лишь при явной остановке далеко от цели.
        if st = "acc" {
            // Знак - по самому углу, не по скорости: за секунду разгона угол
            // обязан уменьшиться, если вырос больше градуса - газ не туда.
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
            // Торможение не дольше, чем шёл разгон (+50%): при той же тяге
            // RCS больше не нужно, дальше это уже встречный импульс.
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

// Вектор от ступени до ТОЧКИ ПРИЦЕЛИВАНИЯ. Через него ходит всё наведение и
// посадочный импульс, так что смещение действует везде разом.
function F9ToPad {
    local raw is vxcl(up:vector, F9Pad:position).
    if F9PadOffAlong = 0 and F9PadOffSide = 0 return raw.
    if raw:mag < 1 return raw.
    // Направление подхода берём по СЫРОМУ вектору на зону, иначе смещение
    // считалось бы от самого себя.
    local fwd is raw:normalized.
    return raw + fwd * F9PadOffAlong + vcrs(up:vector, fwd) * F9PadOffSide.
}

// Чистая зона, без смещения - для отчёта, чтобы было видно и то, и другое.
function F9ToPadRaw {
    return vxcl(up:vector, F9Pad:position).
}

function F9FallTime {
    local h is max(1, F9AltAbovePad()).
    local vv is ship:verticalspeed.
    local gg is F9GLocal().
    return (vv + sqrt(vv * vv + 2 * gg * h)) / gg.
}

// Чего не хватает горизонтальной скорости, чтобы упасть в площадку. Именно
// это boostback и гасит - не скорость до нуля, а разницу между тем, что
// есть, и тем, что нужно.
function F9BoostbackDV {
    local toPad is F9ToPad().
    local tf is max(1, F9FallTime()).
    local want is toPad:normalized * (toPad:mag / tf).
    local now is vxcl(up:vector, ship:velocity:surface).
    return want - now.
}

// Сколько двигателей нужно, чтобы остановиться из текущего состояния.
//
// Прошлый прогон с Dragon разбился именно здесь: импульс включился на 4516 м
// при -515.7 м/с, профиль просил -208.9, и один Merlin такого прихода не
// тормозит физически. Арифметика:
//
//   515 м/с на 4516 м -> нужно 39.2 м/с2, один двигатель даёт 25.5
//   300 м/с на 3000 м -> нужно 24.8,      один на пределе
//   200 м/с на 2000 м -> нужно 19.8,      одного хватает
//
// Настоящий Falcon на тяжёлых возвратах так и садится: сначала три
// двигателя, потом один. Число двигателей теперь задаёт профиль: выше
// точки перехода - три, ниже - один. F9ThreeAt оставлен как допуск по
// скорости в точке перехода: пришли быстрее профиля больше чем на эту
// долю - держим три, пока скорость не войдёт в профиль.
set F9ThreeAt to 1.15.

// Переход обратно на один двигатель.
//
// Порога по дросселю больше нет: решение принимает единый закон по
// ПОТРЕБНОЙ тяге (см. фазу 6). Осталась только выдержка.
set F9ThreeDownHold to 0.2.        // секунд подряд, чтобы не дёргаться
set F9ThreeDownT0 to 0.

function F9BurnEngines {
    if ship:mass <= 0 return 1.
    if F9H() > F9SwitchAlt return 3.
    // Имя spd, а не v: голая v в kOS - встроенный конструктор вектора,
    // и присваивание в неё запрещено (CLOBBERBUILTINS). То же с r и q.
    local spd is ship:velocity:surface:mag.
    if spd > F9SwitchV() * F9ThreeAt return 3.
    return 1.
}

// ---------------------------------------------------------------------
// Разворот, boostback и полёт по инерции нужны только тем, кто пришёл
// сюда сверху. При подхвате ниже точки входа ступень уже падает, гасить
// горизонтальную скорость поздно и незачем - сразу к рулям и спуску.
// ---------------------------------------------------------------------
if (F9OnPad or ship:altitude > F9EntryAlt) and F9Mode = "rtls" {

    // ---------------------------------------------------------------------
    // ФАЗА 1. Разворот на импульс возврата.
    // ---------------------------------------------------------------------
    // Разворачиваться в потоке бессмысленно: холодный газ на порядок слабее
    // аэродинамического момента, ступень будет висеть боком и жечь газ
    // впустую. Ждём, пока напор упадёт, и только тогда крутим.
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

    // Ограничение по времени - чтобы не висеть вечно, если холодного газа мало.
    // Зажигаемся, КАК ТОЛЬКО грубо смотрим куда надо, а не по идеалу.
    //
    // Раньше порог был 12 градусов, и ступень честно доворачивалась 20 секунд,
    // упираясь ровно в него - в логе так и стоит "ошибка 12 град". Это чистая
    // потеря: руль во время работы двигателя никуда не девается, F9BBDir
    // пересчитывается каждый тик, и остаток ошибки добирается уже на тяге.
    // Косинус 25 градусов - это девять процентов импульса мимо, а двадцать
    // секунд ожидания стоят дороже.
    set F9FlipDt to F9PitchFlip(F9FlipErr, 40, { return F9BBDir. }).
    print "  aligned in " + round(F9FlipDt, 1) + " s, error " +
          round(vAng(ship:facing:forevector, F9BBDir), 1) + " deg".
    rcs off.
    lock steering to lookdirup(F9BBDir, ship:facing:topvector).

    // ---------------------------------------------------------------------
    // ФАЗА 2. Boostback.
    // ---------------------------------------------------------------------
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

    // ---------------------------------------------------------------------
    // ФАЗА 3. Полёт по инерции соплами вперёд. Рули раскрываем заранее: у KRE
    // они спавнятся сложенными, в плотном потоке раскрываться будут неохотно.
    // ---------------------------------------------------------------------
    print "--- coast ---".
    set F9Phase to "coast".
    lock steering to F9PitchOnly(-ship:velocity:surface).
    // Рули - сразу после boostback, вместе с началом разворота (21.09).
    set F9FinsTook to F9GridFinsDeploy(true).
    print "  grid fins that took the command: " + F9FinsTook +
          " of " + F9GridFins:length + ", state [" + F9GridFinsState() + "]".
    if F9FinsTook = 0 print "  grid fin events: " + F9GridFinsEvents().
    set F9FlipDt to F9PitchFlip(F9CoastFlipErr, 60, { return -ship:velocity:surface. }).
    print "  engines-first in " + round(F9FlipDt, 1) + " s".
    // Крен 0 (верх к небу, как heading(..., 0) на подъёме). Флип идёт
    // только по тангажу, крен доворачиваем после него газом по всем осям.
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

    // Холодный газ - единственное, чем ступень может рулить в вакууме:
    // реактивные колёса против её момента инерции почти ничего не значат, и
    // без газа она просто болтается боком всю дорогу до атмосферы.
    lock steering to F9PitchOnly(-ship:velocity:surface).
    // Рули - вместе с началом разворота на ретроград (21.09, по Егору).
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


// ---------------------------------------------------------------------
// ФАЗА 4. Тормозной импульс входа.
//
// Гасим не "до высоты", а ДО СКОРОСТИ. Смысл импульса в том, чтобы убрать
// лишнюю характеристическую скорость до прихода в плотные слои, и мерить
// его надо в тех же единицах: при ручных посадках рабочая цифра - около
// 600 м/с на входе. Высота остаётся только нижней границей, чтобы импульс
// не тянулся до земли, если тяги не хватает.
// ---------------------------------------------------------------------

// Отдельной "подготовки к entry burn" больше нет. Она была рудиментом от
// схемы, где ступень сначала летела как попало, а потом разворачивалась под
// импульс. Сейчас положение под импульс задано сразу после разделения и
// держится всю дорогу - разворачиваться не из чего, и в прошлом прогоне это
// было видно: рули раскрылись на 56 км, "подготовка" началась на 49.6 и
// сразу отрапортовала ошибку 4.9 градуса. Двух фаз ради четырёх градусов.
//
// Осталось только дождаться высоты и доложить, с какой ошибкой пришли.
wait until ship:altitude < F9EntryAlt.

// Копоть. Включаем здесь, а не после посадки: обгорает ступень именно на
// входе, и видно это должно быть уже на спуске.
set F9SootTook to F9SootOn().
print " ".
print "  soot: " + F9SootTook + " of " + F9SootParts():length + " parts".
if F9SootTook = 0 print "  soot events: " + F9SootEvents().

print "  attitude error at ignition " +
      round(vAng(ship:facing:forevector, -ship:velocity:surface:normalized), 1) +
      " deg".
// Последний шанс перенести прицел: пока ступень летела, баржа дошла до
// точки и доложилась. Дальше начинается торможение, и цель менять поздно.
if F9AsdsRefresh() {
    print "  barge: " + round(F9Pad:lat, 4) + " / " + round(F9Pad:lng, 4) +
          ", deck " + round(F9AsdsDeck, 1) + " m".
}

// Доворот импульса входа НА ЦЕЛЬ.
//
// Импульс входа - единственное место, где промах закрывается дёшево: тяга
// тут в разы больше аэродинамики, а до земли ещё полста километров. У
// земли то же самое стоит наклона в тридцать градусов и посадки набок -
// прогон 16.09 вечером сел с промахом 1815 м и наклоном 38 градусов, хотя
// в entry на закрытие этих полутора километров хватило бы пары градусов.
//
// Знак не вывожу, а выбираю: считаю оба поворота и беру тот, что
// действительно ведёт тягу к цели. Тот же приём, что в F9AeroSide.
// Пределы подняты после прогона 16.09 ночью: доворота не хватало. При
// четырёх градусах на километр промах в двести метров давал 0.8 градуса -
// то есть ничего. Восемь градусов на километр и потолок двадцать: impulse
// входа порядка 600 м/с, наклон в два градуса - это 20 м/с вдоль трассы,
// чего при оставшемся времени падения хватает на пару километров точки.
// Контур замкнут через Trajectories и пересчитывается каждый такт, так что
// усиление здесь безопаснее, чем недобор.
set F9EntryTiltMax to 20.          // градусов от ретрограда
set F9EntryTiltPerKm to 8.         // градусов на километр промаха
set F9EntryMissDead to 50.         // метров, ближе не доворачиваем

// Entry по дальности (21.09 17:10). Подробно - F9-KARTA.md, "Entry по дальности".
// Направление тяги - между "вверх" и "назад по горизонтали". Вверх гасит
// вертикаль, ступень дольше летит и падает ДАЛЬШЕ; назад гасит горизонталь -
// БЛИЖЕ. Чистый ретроград между ними. Угол от вертикали = угол ретрограда +
// F9EntryTiltPerKm на км продольного промаха, не дальше F9EntryTiltMax от
// ретрограда. Боковой промах - наклоном вбок.
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
// Нижняя граница запаса. Именно она, а не цель по скорости, и заканчивает
// импульс входа: в прогонах 16.09 ступень выходила из entry на 660 м/с при
// цели 600, потому что упиралась в этот порог. Он же определяет, с чем
// ступень придёт к посадочному импульсу.
//
// 350 не хватало: посадка по профилю стоит около 340, и в прогоне 16.09
// двигатель встал на высоте 1.7 м с остатком ноль. 420 - те же 340 плюс
// запас на снос и на неточность оценки сухой массы.
//
// 480 после перехода на зажигание с двух километров: растянутый импульс
// стоит около 436 м/с (измеренные 371 плюс 65 тяжести за лишние семь
// секунд горения), и 420 его уже не покрывают.
//
// 450 после прогона 16.09 ночью. Порог тут работает в обе стороны: чем
// раньше кончается entry, тем быстрее ступень приходит вниз, а цена
// посадки растёт по квадрату этой скорости. Дешевле дожечь в entry.
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

// ---------------------------------------------------------------------
// ФАЗА 5. Аэродинамический спуск. Решётчатые рули - обычные плоскости
// управления и слушаются того же steering, отдельных команд им не нужно.
// ---------------------------------------------------------------------
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

// Переключаемся на посадочный режим ЗДЕСЬ, до расчёта тормозного пути.
//
// Это была причина крушения: F9StopDist берёт ship:availablethrust, и пока
// стоял режим Three Landing, путь считался по 1706 кН, а тормозили потом
// одним двигателем на 764. В логе h=661 при "пути" 631 - на одном двигателе
// с 206 м/с нужно было около 1290 м, вдвое больше высоты.
F9SetEngineMode(1).
print "  landing mode: " + F9EngineCount() + " eng. [" + F9ModeName() + "]".

// Текущий угол атаки. Трапеция по окну напора: плавно набираем на первой
// четверти окна, держим, плавно убираем к концу. Плавно - чтобы ступень не
// дёргало на границах, резкая смена команды в потоке стоит дороже угла.
function F9AoA {
    local qq is ship:q.
    if qq <= F9AoAqLo return 0.

    // Набор по напору: чем плотнее воздух, тем больше угол - и тем больше
    // от него пользы. Выше F9AoAqFull держим полный.
    local kin is min(1, (qq - F9AoAqLo) / (F9AoAqFull - F9AoAqLo)).

    // Снятие по высоте, перед посадочным импульсом.
    local h is F9AltAbovePad().
    local kout is min(1, max(0, (h - F9AoAOffLo) / (F9AoAOffHi - F9AoAOffLo))).

    local want is F9AoAMax * min(kin, kout).

    // Ограничение по факту: не просим больше, чем рули уже отработали, плюс
    // небольшой запас. Угол так подкрадывается к своему пределу снизу и не
    // загоняет регулятор в насыщение. Пол в 6 градусов нужен, чтобы схема
    // могла тронуться с места: в начале спуска факт равен нулю.
    local act is vAng(ship:facing:forevector, -ship:velocity:surface:normalized).
    return min(want, max(6, act + F9AoALead)).
}

// --- Наведение в планировании ---
//
// Раскладка ошибки как в booster.ks: не по вектору скорости, а по ВЕКТОРУ
// ПОДХОДА - горизонтальному направлению от ступени к площадке. Разница
// важна у самой цели: вектор скорости там разворачивается, и раскладка по
// нему начинает путать продольное с боковым.
function F9ApproachVec {
    local a is vxcl(up:vector, F9Pad:position).
    if a:mag < 1 return vxcl(up:vector, ship:velocity:surface):normalized.
    return a:normalized.
}

// Вектор ошибки: от площадки к предсказанной точке падения.
// У Superheavy это ровно ADDONS:TR:IMPACTPOS:POSITION - landingzone:POSITION.
function F9ErrorVec {
    if addons:tr:available and addons:tr:hasimpact {
        return vxcl(up:vector, addons:tr:impactpos:position - F9Pad:position).
    }
    // Запасной вариант без мода - баллистика по плоской земле.
    local tf is max(1, F9FallTime()).
    return vxcl(up:vector, ship:velocity:surface) * tf - F9ToPad().
}

// Продольная ошибка: больше нуля - перелёт вдоль подхода.
function F9MissLong {
    return vdot(F9ApproachVec(), F9ErrorVec()).
}

// Боковая ошибка.
function F9MissLat {
    return vdot(vcrs(up:vector, F9ApproachVec()), F9ErrorVec()).
}

// Поперечная аэродинамическая сила при заданном положении носа.
//
// Модель простая - поперечная составляющая набегающего потока относительно
// оси корпуса. Для тупого тела вроде ступени она верна. Нужна, чтобы НЕ
// ГАДАТЬ со знаками поворотов: вместо вывода знака считаем оба варианта и
// берём тот, чья сила направлена куда надо.
function F9AeroSide {
    parameter nose.
    local u is -ship:velocity:surface.
    return u - vdot(u, nose) * nose.
}

// Куда смотрит нос на спуске: ретроградное, ПОВЁРНУТОЕ вокруг поперечной
// оси на угол атаки и вокруг вертикали на боковой доворот. Формулировка
// booster.ks:
//
//   -velocity:surface * AngleAxis(-Factor*LngCtrl, ...:starvector)
//                     * AngleAxis(LatCtrl, up:vector)
//
// Угол теперь ВЫХОД ПИД-РЕГУЛЯТОРА, а не функция от промаха. Это и есть та
// разница, из-за которой у Superheavy этих проблем нет: интеграл убирает
// установившуюся ошибку, а пропорциональная схема на ней замирает.
//
// F9AoA() остаётся ПОТОЛКОМ: она знает про напор (в вакууме угол держать
// нечем) и про снятие угла перед посадочным импульсом. Регулятор рулит
// внутри этого потолка.
function F9GlideDir {
    local retro is -ship:velocity:surface:normalized.
    local cap is F9AoA().

    local ang is cap.
    local lat is 0.
    if F9Guided() {
        local eLng is F9MissLong() - F9LngBias.
        local eLat is F9MissLat().

        // Пределы РАСТУТ ВМЕСТЕ С ОШИБКОЙ - это из booster.ks
        // (LngCtrlPID:maxoutput = abs(ошибка)/PIDFactor, ограниченное
        // сверху maxAoA и снизу небольшим числом). Без этого регулятор с
        // Kp = 0.35 на метр упирается в потолок при первой же сотне метров:
        // в прогоне "lat-12" стояло с первой строки спуска при боковой
        // ошибке всего 100 метров. Насыщенный регулятор ошибку не сводит,
        // он вокруг неё колеблется.
        set F9LngPID:maxoutput to min(cap, max(abs(eLng) / 100, 5)).
        set F9LngPID:minoutput to -F9LngPID:maxoutput.
        set F9LatPID:maxoutput to min(F9LatMax, max(abs(eLat) / 50, 2.5)).
        set F9LatPID:minoutput to -F9LatPID:maxoutput.

        // БЕЗ минуса. У booster.ks стоит "set LngCtrl to -PID:UPDATE(...)",
        // но там минус компенсируется вторым минусом в самом повороте
        // (AngleAxis(-Factor*LngCtrl, ...)). Я поворот выбираю по силе, а не
        // по знаку угла, второго минуса нет - и первый оказался лишним.
        //
        // Цена ошибки видна в логе: промах -4.4 км, то есть НЕДОЛЁТ, а
        // команда шла в минус, то есть прижимала. Промах за спуск вырос до
        // -5.3 км. kOS считает ошибку как setpoint минус вход, так что при
        // недолёте выход уже положительный - подъёмная сила, что и нужно.
        set F9AoAOut to F9LngPID:update(time:seconds, eLng) * F9GlideFactor.
        set F9LatOut to F9LatPID:update(time:seconds, eLat).

        set ang to min(cap, abs(F9AoAOut)).
        set lat to abs(F9LatOut).
    }
    else set F9AoAOut to cap.

    if ang < 0.5 return retro.

    // У самой земли ступень падает почти отвесно, ретроградное совпадает с
    // вертикалью, и поперечная ось вырождается - lookdirup от параллельных
    // векторов даёт мусор.
    local tilt is vAng(retro, up:vector).
    if tilt < 5 or tilt > 175 return retro.

    // Тангаж. Знак поворота в kOS не вывожу - считаю оба и выбираю по силе:
    // регулятор просит плюс (недолёт) - нужна подъёмная сила, минус
    // (перелёт) - прижимающая.
    local star is lookdirup(retro, up:vector):starvector.
    local a is retro * angleaxis(ang, star).
    local b is retro * angleaxis(-ang, star).
    local wantUp is 1.
    if F9AoAOut < 0 set wantUp to -1.
    local nose is a.
    if wantUp * vdot(F9AeroSide(b), up:vector) >
       wantUp * vdot(F9AeroSide(a), up:vector) set nose to b.

    // Боковой доворот: из двух берём тот, чья сила направлена ОТ
    // предсказанной точки падения К площадке.
    if lat > 0.2 {
        local want is (-F9ErrorVec()):normalized.
        local c is nose * angleaxis(lat, up:vector).
        local d is nose * angleaxis(-lat, up:vector).
        set nose to c.
        if vdot(F9AeroSide(d), want) > vdot(F9AeroSide(c), want) set nose to d.
    }
    return nose.
}

// Опорное направление "верха" для lookdirup.
//
// Раньше сюда шёл ship:facing:topvector - то есть регулятор читал СОБСТВЕННЫЙ
// выход. Такая петля не имеет устойчивой точки, и крен от неё гуляет. У
// booster.ks для этого есть отдельный ApproachVector; здесь его роль играет
// направление на площадку, а в splashdown - направление полёта. Оба
// горизонтальны, оба заведомо не параллельны носу, оба не зависят от текущей
// ориентации.
// RTLS (21.09 19:20, F9-KARTA "Крен у земли"): ближе 100 м последнее
// направление на точку держится до касания. ASDS не трогаем.
set F9TopLatch to V(0, 0, 0).
function F9TopRef {
    if F9Guided() {
        local tp is F9ToPad().
        // 24.09 01:1x: и для баржи. Доводка стала приводить в 0-3 м от
        // центра, опора крена уходила на горизонтальную скорость 0.6-2 м/с
        // (разворачивается) и на up (параллельна оси) - ступень крутило
        // по крену, наклон уходил не туда, гор у палубы 0.6 -> 2.1.
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

// Отдаём площадку самому моду: он покажет промах в своём окне, и цифру
// можно сверить с тем, что печатает скрипт.
F9AsdsRefresh().
if F9Guided() and addons:tr:available and kuniverse:activevessel = ship addons:tr:settarget(F9Pad).

// Отдельного поднятого потолка для тяжёлой посадки БОЛЬШЕ НЕТ.
//
// Я поднял его до 9.6 км, рассуждая "быстрый приход надо гасить выше". Это
// оказалось лишним и вредным: с тремя двигателями тормозной путь и так
// короткий, и потолок ни разу не был ограничителем - зато импульс начинался
// там, где до него было ещё далеко.
//
//   масса 40 т, 515 м/с: три двигателя останавливают за 3.4 км
//   масса 40 т, 700 м/с: за 6.3 км
//
// В прогоне это дало старт на семи километрах и пережог: ступень села за
// 615 м до площадки, имея в баке 582 м/с - пятую часть всего запаса возврата.
// Момент включения считает тормозной путь, потолок только страхует.

lock F9AeroDir to F9GlideDir().
lock steering to lookdirup(F9AeroDir, F9TopRef()).

// Момент зажигания - высота, на которой профиль разрешает текущую скорость,
// плюс упреждение на задержку самого цикла. В прошлом прогоне проверка
// стояла в одном проходе с печатью, проход занимал около секунды, и при
// 226 м/с двигатель включался на 180 метров ниже расчёта.
//
// Ниже F9FastAlt цикл становится коротким: ни F9KeepS2 с его ожиданиями,
// ни печати. Вторая ступень к этому времени либо на орбите, либо далеко.
set F9FastAlt to 3000 * F9Scale.

// Прицел с упреждением (19.09). Импульс - hoverslam: ступень стоит прямо,
// горизонталь гасят воздух и тяга, и путь по горизонтали после зажигания
// ~F9LeadK * гор (замер 5 посадок, 4.98-5.41). Баллистика же после той же
// точки прошла бы гор * h/|vv|. Разницу отдаём в прицел за площадку, чтобы
// импульс кончался над ней. Точку зажигания берём по тому же правилу, что
// цикл ниже, при текущей скорости. Прогон 19.09 23:08: 188 * (4193/473 -
// 5.19) = 690 м при недолёте 489 - F9LeadGain подстраивать по логу.
// Прицел меняется не быстрее F9LeadRate м/с, чтобы не дёргать PID.
// Барже упреждение нужно НЕ МЕНЬШЕ, чем площадке. 20.09 02:10 заход на
// баржу шёл с гор 220 на зажигании (вдвое быстрее обычных 115), прицел
// стоял мёртвой константой 220 м, до цели на зажигании осталось 1742 м
// при 5.19 * 220 = 1145 достижимых. Масштаб профиля упёрся в потолок
// 1.35, недобор 197 м, промах 252 м и топливо в ноль. Формула на тех же
// числах дала бы 236 * (4253/441 - 5.19) = 1050 м.
set F9LeadOn to F9Guided().

// Пробег импульса - НЕ константа в скоростях, а доля баллистического
// пробега от той же точки. Три захода дают одно и то же отношение:
//   h1807 vv261 гор116 - пробег 601 из 807   = 0.745
//   h4253 vv421 гор220 - пробег 1490 из 2226 = 0.669
//   h4246 vv393 гор198 - пробег 1508 из 2139 = 0.705
// Сам же коэффициент в скоростях при этом гуляет от 5.2 до 7.6, и
// зашитые 5.19 (замер только низких заходов) на заходе с четырёх
// километров врут в полтора раза. 02:21 это стоило прицела 1500 при
// потребных 630 и перелёта 1140 м.
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
// 24.09 00:4x: глайд снимает угол к ~4.5 км, не досведя промах: последний
// "пром" семи полётов -54 -95 -21 -103 -63 -49 -30. Импульс по потоку этот
// недолёт доносит до палубы (прогон на зажигании -41, факт -40; прошлый
// -24 / -39). Одномоторное удержание закрывает ~25 м - касание в 13-15 м от
// центра, опора на краю палубы. Цель глайда дальше на столько.
set F9LeadAdd to 40.
set F9LeadT to time:seconds.

// Прицел не трогаем, пока оценка высоты зажигания скачет. F9IgnAlt считает
// её из ТЕКУЩЕЙ скорости и про торможение воздухом не знает: 20.09 11:56
// на 15 км при 690 м/с она дала 10182 м, а зажигание вышло на 1940. Прицел
// шёл за ней с потолка 1500 вниз до 220, утащил ступень вперёд, и глайд уже
// не отыграл - aoa весь участок стоял на упоре -6, пром уехал с 0 на +375,
// на зажигании до баржи осталось 53 м вместо потребных 520. Перелёт 568.
// Пока |d(hi)/dt| выше F9LeadHiRate, держим базовый прицел: в том заходе
// оценка успокаивается за пять секунд до зажигания, на 96 м/с.
set F9LeadHiRate to 150.
set F9LeadHiPrev to -1.

function F9AimLead {
    local spd is ship:velocity:surface:mag.
    local vv is max(20, -ship:verticalspeed).
    local hi is F9IgnAlt() + spd * F9IgnLead.
    local gh is vxcl(up:vector, ship:velocity:surface):mag.
    return max(0, min(F9LeadMax, F9LeadGain * gh * (hi / vv - F9TravelK(hi, vv)))).
}

// ---------------------------------------------------------------------
// Упреждение прогоном (21.09). Подробно - F9-KARTA.md, "Упреждение прогоном".
// c = D*m/(rho*v^2) меряется в глайде по числу Маха и копится в F9DragFile.
// ---------------------------------------------------------------------
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

// ---------------------------------------------------------------------
// Прогноз пробега посадочного импульса (24.09, F9-KARTA "Новая посадка").
// Импульс идёт носом строго против потока, газ - по вертикальному профилю
// тем же законом, что в цикле импульса (tau, ProfDot, косинус наклона).
// Тогда тяга и воздух оба вдоль скорости, и форма траектории задаётся
// вертикальным профилем, а не воздухом: офлайн-проверка на 11 полётах по
// ретрограду дала ошибку -11..+30 м (одна -46), от сопротивления почти не
// зависит. Полёты, где закон уводил нос с потока, ушли на 200-500 м.
// Константы свои: прогон зовётся в глайде, до строк, где задаются
// потолки наклона импульса.
// ---------------------------------------------------------------------
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

// Горизонтальный пробег от состояния (h над площадкой, vz < 0, vh, масса m)
// до остановки. off - высота площадки над уровнем моря, для воздуха.
// Прогон разбит на шаги (F9BjStep) над общими переменными F9Bj*: глайд
// гонит его целиком, импульс - по несколько шагов за такт (F9BjRun), иначе
// 1-2 с прогона останавливают управление (24.09 00:2x).
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

// Прогон в импульсе: F9BjSteps шагов за вызов, по окончании - результат и
// новый старт с текущего состояния. Пробег строго пропорционален vh (по
// прогонам от 100 м до 4 км: x(1.2vh)/x = 1.20-1.25), поэтому "пробег на
// 1 м/с горизонтали" F9BjK = x/vh - тоже из модели, для любого режима.
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
        // Второе условие - то же, что у настоящего зажигания (F9LandMaxAlt).
        // Без него в RTLS (быстрый крутой спуск) прогон зажигался на 16 км
        // вместо 4.2, прицел брался оттуда и замерзал (21.09, F9-KARTA "RTLS").
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
    // Было (x - x0) - F9TravelRatio * ball: пробег импульса долей
    // баллистики, 0.705 по трём полётам. Теперь - прогоном F9BurnSim.
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

// ---------------------------------------------------------------------
// ФАЗА 6. Посадочный импульс. ЕДИНЫЙ ЗАКОН.
//
// Раньше здесь работали четыре независимых регулятора: F9WantV с газом по
// коэффициенту (вертикаль), F9LandDir с наклоном (горизонталь), отдельные
// F9ProfMargin1/3 и F9ThrGain1/3 под число двигателей и отдельное окно
// подлёта F9DivertHi/Lo. Они не знали друг о друге, и каждая подгонка
// одного ломала другой - отсюда и болтанка газа, и остаточный недолёт в
// сотню метров: вертикальный профиль про промах не знал вовсе, а боковой
// доводчик был задушен до 15 м/с, чтобы не превращаться в висение.
//
// Теперь регулятор ОДИН и работает с векторами, а не с двумя проекциями:
//
//   1. желаемая скорость - вектор: вниз по профилю торможения, вбок к
//      площадке ровно с той скоростью, чтобы дойти за оставшееся время;
//   2. потребное ускорение - из разницы желаемой и текущей скорости,
//      плюс компенсация тяжести и собственного замедления профиля;
//   3. из этого вектора разом берутся И направление (куда смотреть),
//      И газ (какой длины вектор).
//
// Промах гасится тем же наклоном, что и высота, потому что это одна и та
// же команда. Число двигателей больше не требует своих коэффициентов: газ
// считается делением потребного ускорения на доступное, а доступное само
// знает, сколько двигателей работает.
// ---------------------------------------------------------------------
// Сколько горизонтальной дальности проходит посадочный импульс, считает
// F9TravelK по высоте и вертикальной скорости зажигания. Прежняя зашитая
// константа 5.19 (замер пяти низких заходов: 4.98, 5.11, 5.25, 5.21,
// 5.41) годилась только для них.

// Масштаб профиля горизонтали. Единица - профиль как был. Считается на
// зажигании, границы держат его в пределах, где хватает наклона и топлива.
set F9LandKappa to 1.
set F9KappaMin to 0.75.
set F9KappaMax to 1.35.

// Объявлены ЗДЕСЬ, а не в общем блоке ручек ниже: kOS выполняет set
// сверху вниз, а масштаб нужен уже в этой строке. Функции всплывают,
// переменные нет - на этом и упал прогон 23:07.
set F9BurnMode to F9BurnEngines().
F9SetEngineMode(F9BurnMode).
print "--- landing burn (" + F9BurnMode + " eng.) ---".
F9Mark("lburn").
set F9Phase to "landing".

// Масштаб профиля горизонтали - ОДИН раз, по фактическому состоянию на
// зажигании. Дальше он не трогается: пересчёт в полёте сделал бы из него
// обратную связь у палубы, то есть ровно ту доводку наклоном, от которой
// уходим.
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

// 24.09 00:2x: здесь стоял F9BurnSim для лога - прогон идёт 1-2 с, газ
// ещё не поднят, и зажигание ушло с 2446 м (прогноз глайда) на 1835.
// Прогон на борту - только в глайде; "симзаж" - где глайд ждал зажигание.
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

// --- Ручки единого закона. Их теперь семь вместо двадцати. ---

// Профиль торможения задан выше по файлу (F9ProfV): он же определяет и
// момент зажигания, и число двигателей. Здесь остаётся только жёсткость.

// Постоянная времени. За сколько секунд закон намерен закрыть отклонение
// от желаемой скорости. Больше - мягче и медленнее, меньше - резче.
// Это единственная ручка "жёсткости" во всём импульсе.
set F9Tau to 2.

// Потолок подлёта к площадке и его сужение у земли.
//
// Отдельного окна F9DivertHi/F9DivertLo больше нет. Вместо двух высот -
// одна пропорция: разрешённая горизонтальная скорость не больше
// F9LandVPerM метров в секунду на каждый метр высоты. На 200 метрах это
// 60 м/с (то есть работает общий потолок), на 80 - 24, на десяти - три.
// Висение у земли невозможно по построению, а высоко подлёт не задушен.
set F9LandVMax to 40.

// 0.15, а не 0.3. С тремя десятыми на восьмидесяти метрах разрешено 24 м/с
// вбок - и ступень их туда и несла: в прогоне 16.09 вечером горизонтальная
// держалась 23-25 м/с до тридцати метров, а гасить их пришлось наклоном,
// из которого ступень к касанию уже не выпрямилась (наклон 38 градусов при
// команде 4). Гимбал Merlin два градуса, инерция большая - выпрямление
// стоит секунд, которых у земли нет.
//
// Промах закрывает не наклон у земли, а доворот в entry burn.
set F9LandVPerM to 0.15.

set F9MaxTilt to 25.               // градусов от вертикали
set F9MinThrottle to 0.4.          // минимальный дроссель Merlin, доля

// ДОВОДКА ПРОМАХА НА ПОСАДОЧНОМ ИМПУЛЬСЕ.
//
// Если у земли точку начало уводить, садиться в стороне бессмысленно -
// палуба не подвинется. Ступень на одном двигателе тягу к весу имеет 1.2,
// то есть подняться она может, и это единственный момент, когда лишние
// секунды покупаются дёшево: высота ещё разрешает наклон.
//
// Поэтому: промах больше F9DivertMiss и высота в окне - прекращаем
// снижение и идём вверх F9DivertUp, пока промах не закрыт. Окно жёсткое со
// всех сторон, иначе это превращается в то самое зависание, на котором уже
// теряли ступень:
//   - ниже F9DivertMin поздно, там уже касание;
//   - выше F9DivertAlt рано, промах закроется сам по дороге;
//   - запас меньше F9DivertKeep - роскошествовать нечем, садимся как есть;
//   - дольше F9DivertMax секунд не тянем ни при каких условиях.
set F9DivertAlt to 150 * F9Scale.
set F9DivertMin to 12 * F9Scale.
set F9DivertMiss to 40.
set F9DivertUp to 3.
set F9DivertKeep to 140.
set F9DivertMax to 12.
set F9DivertT0 to 0.

// ВЫКЛЮЧЕНА. Проверено 16.09 ночью: тянуть ступень вверх у палубы уже не
// помогает - промах к этому моменту закрывать нечем, а секунды висения
// стоят топлива и заканчиваются сносом. Промах закрывается ПРИЦЕЛОМ
// (F9AsdsOffAlong) и доворотом в entry burn, то есть заранее.
// Код оставлен: если появится ступень с запасом, включать здесь.
set F9DivertUse to false.
set F9DivertOn to false.

// Решение считается один раз за такт (в цикле), а закон только читает
// готовый флаг: внутри F9DvLeft перебор деталей, и звать его из каждой
// функции команды - тот же перерасход тактов, из-за которого F9ACmd уже
// сведён к одному вызову.
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

// Желаемая ВЕРТИКАЛЬНАЯ скорость - тот самый профиль, по которому выбран
// момент зажигания. F9MinDesc поднимается сторожем зависания ниже по циклу.
function F9WantVV {
    if F9DivertOn return F9DivertUp.
    if F9TransOn return -F9TransVV.
    return -max(F9ProfV(F9H()), F9MinDesc).
}

// СОБСТВЕННОЕ замедление профиля - то, с каким он сам гасит скорость.
//
// Без этого члена закон отставал бы от профиля постоянно: чтобы ИДТИ по
// тормозящему профилю, мало компенсировать тяжесть, надо ещё и тормозить.
// Отставание было бы F9Tau умножить на это ускорение - при tau 2 и профиле
// 15 м/с2 ступень шла бы на тридцать метров в секунду быстрее профиля всю
// дорогу.
//
// С ним ошибка в установившемся режиме нулевая, и F9Tau отвечает только за
// возмущения - за то, ради чего обратная связь и нужна.
function F9ProfDot {
    if F9DivertOn return 0.
    if F9TransOn return 0.
    return F9ProfAccAt(F9H()).
}

// Сколько осталось лететь. Считается по тому же профилю, что и скорость,
// так что горизонтальный подлёт и вертикальное снижение говорят об одном
// и том же времени, а не о двух разных.
// Время по профилю ограничено временем ПО ФАКТУ - высота, делённая на
// текущую вертикальную скорость.
//
// Без этого ограничения закон верил профилю даже тогда, когда ступень от
// него отстала: на 47 метрах профиль говорил "лететь ещё шесть секунд",
// потому что по профилю там положено -9 м/с, а ступень шла -49 и до воды
// ей оставалась секунда. Постоянная времени оставалась мягкой, отставание
// закрывать было нечем, и остаток долга уходил прямо в касание.
function F9TGo {
    return max(0.5, min(F9TGoH(F9H()), F9H() / max(0.5, abs(ship:verticalspeed)))).
}

// Время по профилю с высоты h до касания, без поправки на факт.
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

// Боковое торможение, по которому строится горизонтальный профиль.
//
// Наклон в F9MaxTilt даёт боковое ускорение g*tg(25) = 4.6 м/с2. Берём
// вдвое меньше: профиль должен оставлять запас, которым регулятор добирает
// ошибку, иначе он упирается в потолок наклона и перестаёт быть профилем.
set F9LatAcc to 2.3.

// Потолок ИСПОЛНЕНИЯ, отдельный от потолка ПЛАНИРОВАНИЯ.
//
// F9LatAcc = 2.3 стоит в профиле: на него закладывается тормозной путь, и
// занижать его безопасно - это запас. Но тем же числом был ограничен и
// регулятор, а это уже не запас, а потеря управления.
//
// 16.09 23:56, промах 34 м. Ступень прошла ТОЧНО над баржей ("до цели 3")
// на высоте 210 метров с горизонтальной 12.3 м/с и дальше девять секунд
// ехала вбок. Снос считается ровно как гор^2/(2*a): 12.3^2/4.6 = 33 метра
// при факте 31-34. Прошлая посадка, та что в 6.5 м: над баржей на 39
// метрах с 4.9 м/с, 4.9^2/4.6 = 5.2 метра при факте 6. Обе сходятся.
//
// Наклон на двухстах метрах разрешён все 25 градусов, это 4.3 м/с². То
// есть половина доступного торможения не использовалась.
//
// ОТКАЧЕНО 18.09. С 4.3 при том же старте (h1816 гор115 цель503, масштаб
// 0.839 против 0.848) ступень прошла над баржей на 390 метрах с гор 27.6
// вместо 210 с 12.3 и легла в воду в 77 м. Лишний потолок регулятор тратил
// не на торможение у цели, а на то, чтобы раньше до неё доехать: на 450 м
// "до цели" было 13 против 58, а гор выше. Формула сноса описывала хвост
// верно, вывод из неё - нет. Возвращено поведение с 34 метрами.
set F9LatAccMax to 2.3.

// Но обещать можно только то, что разрешает наклон.
//
// Корневой профиль sqrt(2*a*d) верен ровно настолько, насколько ступень
// способна выдать это самое a. У земли потолок наклона четыре градуса, а
// это g*tg(4) = 0.64 м/с2, втрое меньше заложенных 2.3. Профиль обещал
// торможение, которого нет, ступень проходила точку насквозь и уезжала
// дальше - в прогоне 16.09 ночью "до цели" падало до 135 м и снова росло
// до 216, пока она шла мимо на десятке метров в секунду.
//
// Плюс нижний предел скорости подхода: ноль в потолке означает "стоять где
// стоишь", а стоять надо НАД ЦЕЛЬЮ, иначе последние метры промаха не
// закрываются ничем.
set F9LandVMin to 2.
set F9AimDead to 15.

// 60, а не 25. На двадцати пяти метрах ступень ещё стояла с наклоном 27
// градусов, набранным выше, и выпрямиться до касания не успевала - вся
// горизонталь, что она при этом набирала, уходила прямо в посадку
// (гор 20.2 м/с на касании). Шестьдесят метров - это около четырёх секунд
// на одномоторном профиле, за них наклон успевает уйти в потолок.
set F9AimFreeze to 60 * F9Scale.

function F9LatAccNow {
    return max(0.3, min(F9LatAcc, F9GLocal() * tan(F9TiltCap()))).
}

function F9LatAccCmd {
    return max(0.3, min(F9LatAccMax, F9GLocal() * tan(F9TiltCap()))).
}

// Горизонталь по времени прибытия (19.09). Старый закон держал не больше
// F9LandVMax 40 м/с при любом расстоянии: с зажигания на 4.2 км за 1525 м
// при гор 188 он сбросил горизонталь и сел в 489 м не долетая. Теперь
// желаемая горизонталь 2*d/t: равномерное торможение, которое гасит её
// в ноль ровно НАД точкой к высоте F9AimFreeze, а не у земли. t - время по
// профилю до F9AimFreeze. Ниже - как было, строго вниз.
// ОТКЛЮЧЁН в тот же вечер: импульс - hoverslam, ступень прямо и только
// подруливает двигателем, точку задаёт прицел планирования (F9AimLead).
// "tgo" - включить.
//
// ВКЛЮЧЁН ОБРАТНО 20.09. Ставка на один прицел не сыграла: три захода
// подряд с высокого зажигания - недолёт 252, перелёт 1140, и оба раза
// горизонталь снесена высоко. Корневой закон на 4191 м при остатке 337 м
// разрешает 29.7 м/с (боковое ускорение всего 2.33 м/с2), то есть велит
// гасить 196 м/с немедленно и тем убивает баллистическую дальность.
// Закон по времени прибытия на тех же числах даёт 2*337/5.6 = 120 м/с:
// горизонталь держится и гасится у самой точки.
set F9HLaw to "tgo".

function F9TArr {
    return max(1, F9TGo() - F9TGoH(F9AimFreeze)).
}

// ---------------------------------------------------------------------
// Горизонталь импульса (21.09). Подробно - F9-KARTA.md, "ZEM/ZEV и доводка".
// Выше F9TransH - ZEM/ZEV: прийти в точку к высоте F9TransH с нулевой
// горизонталью, a = 6d/t^2 - 4v/t. Ниже - доводка стоя (F9TransStep):
// почти висение и перемещение по PD с наклоном до F9TransTilt.
// ---------------------------------------------------------------------
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

// 23.09 22:21 (F9-KARTA "Над центром до перехода на один"). ZEM вёл к 60 м,
// но ниже F9SwitchAlt один двигатель и боковое 2.3 вместо 8: над баржей
// прошла на 250 м с гор 18, перелёт 25 м, рывок доводкой на 15 м. Теперь
// горизонталь гасится над центром к F9ZemEndH, пока работают три.
// Ниже - удержание над центром до касания, доводки у палубы нет.
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
            // 23.09 23:34: руль отстаёт на 1-2 с. Гасили по текущей гор, а
            // ступень ещё стояла с наклоном и продолжала давить: гор прошла
            // через 0 и выросла до 13.9 в обратную сторону. Гасим по гор
            // через F9HoldLead с, с учётом тяги, которая сейчас по горизонтали.
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

// Желаемая скорость ЦЕЛИКОМ, одним вектором.
function F9WantVel {
    local hv is V(0, 0, 0).
    if F9Guided() {
        local d is F9ToPad().
        if d:mag > 1 {
            // ГОРИЗОНТАЛЬ - ТОРМОЗНОЙ ПРОФИЛЬ, а не перехват "дойти за
            // оставшееся время".
            //
            // Было d / tGo, и это оказалось неверно по сути. Такой закон
            // приводит ступень к площадке НА СКОРОСТИ: когда и расстояние,
            // и время идут к нулю, их отношение остаётся конечным. В логе
            // это видно прямо - "до цели" падает 58 -> 21, а "гор" при этом
            // РАСТЁТ 4.1 -> 11.9, и ступень касается площадки боком. Она и
            // легла.
            //
            // Правильный вид - тот же, что у вертикали: корневой профиль,
            // который сам сходит в ноль на цели. sqrt(2*a*d) - это ровно
            // "скорость, которую я успею погасить к моменту прибытия".
            //
            // Потолок по высоте остаётся, но уже как страховка на случай
            // "низко и далеко": если промах всё равно не закрыть, лучше
            // сесть стоя в стороне, чем лечь на площадке.
            // Масштаб профиля. Пять прогонов дали жёсткий факт: посадочный
            // импульс проходит по горизонту K=5.19 горизонтальной скорости
            // на зажигании, разброс всего 4.98-5.41. А геометрия требует
            // d/гор, и ЭТО гуляет от 4.78 до 5.97. Промах - ровно разница
            // между требуемым и выданным, умноженная на горизонталь: +50,
            // -25, -55, +27, -115 против фактических +24, -36, -47, +29,
            // -84. Поэтому и не помогала подгонка прицела: она двигала d, а
            // отношение оставалось чужим.
            //
            // F9LandKappa считается ОДИН РАЗ на зажигании как отношение
            // нужного d/гор к выданному K и растягивает весь профиль
            // горизонтали. Это заранее и высоко - ровно там, где наклон
            // дёшев, а не доводка у палубы.
            if F9HLaw = "tgo" {
                local cap is max(F9LandVMin, F9H() * F9LandVPerM).
                set hv to d:normalized * min(cap, 2 * d:mag / F9TArr()).
            } else {
                local cap is min(F9LandVMax, max(F9LandVMin, F9H() * F9LandVPerM)).
                set hv to d:normalized *
                          min(cap, F9LandKappa * sqrt(2 * F9LatAccNow() * d:mag)).
            }
            // Ниже F9AimFreeze прицел ОТКЛЮЧАЕТСЯ СОВСЕМ: последние метры
            // ступень идёт строго вниз. Гоняться там за остатком промаха -
            // значит держать наклон тогда, когда ступень обязана стоять
            // прямо, и садиться боком ради двадцати метров. Точность даёт
            // прицел (F9AsdsOffAlong) и доворот в entry, а не рывок у
            // палубы. Мёртвая зона по расстоянию - о том же, но для тех
            // случаев, когда ступень уже пришла куда надо.
            if F9H() < F9AimFreeze or d:mag < F9AimDead set hv to V(0, 0, 0).
        }
    }
    return up:vector * F9WantVV() + hv.
}

// Постоянная времени - не константа, а доля ОСТАВШЕГОСЯ времени.
//
// С жёсткими двумя секундами закон физически не успевал у земли: на четырёх
// метрах ступень шла -4.3 при цели -0.9, то есть на 3.4 м/с быстрее, а до
// касания оставалась одна секунда. Регулятор, который намерен закрыть
// отклонение за две секунды, за одну его не закроет - отсюда касание -3.37
// вместо -0.5, при том что газ стоял на 55% и запас тяги был.
//
// Теперь: высоко - мягкие две секунды, у земли - столько, сколько времени
// реально осталось. Заодно жёстче добивается остаточная горизонталь.
// Пол - секунда, а не полсекунды.
//
// Полсекунды я поставил зря: за это время ступень с гимбалом Merlin в 2
// градуса просто не разворачивается. Команда начинала качаться быстрее,
// чем руль успевал её отрабатывать, и получалось "резко меняет положение".
// Регулятор не может быть жёстче того, чем он рулит.
function F9TauNow {
    return max(1, min(F9Tau, F9TGo() * 0.4)).
}

// Потребное ускорение. Отсюда берётся и руль, и газ.
// Горизонтальная часть команды ОГРАНИЧЕНА ТЕМ, ЧТО РАЗРЕШАЕТ НАКЛОН.
//
// Это и есть причина, по которой ступень уезжала боком. Закон видел ошибку
// в пару метров в секунду, делил её на tau около секунды и заказывал
// боковое ускорение, которое отрабатывается наклоном в 25-29 градусов.
// Ступень поворачивается туда две секунды, за это время ошибка давно
// закрыта, а наклон остаётся - и дальше он же разгоняет её мимо цели. В
// логе 16.09 ночью видно дважды: гор 1.2 на 31 метре -> 17.5 на десяти,
// "до цели" 83 -> 199, и ступень уходит от палубы, а не к ней.
//
// Ограничение ставим на само ускорение: больше g*tg(потолок наклона)
// ступень всё равно не выдаст, а заказывать невыполнимое - значит копить
// наклон, который потом некому убрать.
function F9ACmd {
    local vh is vxcl(up:vector, ship:velocity:surface).
    set F9AccHV to F9AccH(vh).
    local ev is up:vector * (F9WantVV() - ship:verticalspeed).
    return F9AccHV + ev / F9TauNow() + up:vector * (F9GLocal() + F9ProfDot()).
}

// Куда смотреть: вдоль потребного ускорения, но не заваливаясь больше
// F9MaxTilt от вертикали. Подрезаем поворотом вертикали В СТОРОНУ команды,
// а не обнулением - азимут наклона при этом сохраняется.
//
// Вектор передаётся ПАРАМЕТРОМ, а не берётся заново: команда считается
// один раз за такт (см. ниже), и руль с газом обязаны прийти из одного и
// того же вектора. Если каждый посчитает свой, они разойдутся на такт - а
// это ровно то рассогласование, из-за которого и заводится болтанка.
// Потолок наклона у земли СУЖАЕТСЯ.
//
// Двадцать пять градусов на сотне метров - нормально, там есть время
// вернуться в вертикаль. На двадцати метрах это уже гарантированное
// падение набок: выпрямиться ступень не успеет. Обе прошлые посадки
// закончились лёжа именно так.
//
// Falcon садится вертикально - значит к земле наклон обязан идти в ноль,
// чего бы это ни стоило по промаху. Промах закрывают прицелом.
set F9TiltPerM to 0.3.             // градусов наклона на метр высоты
set F9TiltMin to 4.                // но не меньше этого, иначе рулить нечем

function F9TiltCap {
    if F9TransOn return F9TransTilt.
    return max(F9TiltMin, min(F9MaxTilt, F9H() * F9TiltPerM)).
}

// 24.09 (F9-KARTA "Новая посадка"). Выше F9ZemEndH нос СТРОГО против
// потока (с тем же потолком наклона, что в прогнозе F9BurnSim), команда
// горизонтали не используется. В плотном воздухе любой увод носа с потока
// тормозит - и к цели, и от цели (23:34, 23:55, GT 20:43: недолёт 190-280).
// Точку прибытия задаёт прицел глайда через F9BurnSim, импульс её только
// исполняет.
// 24.09 00:5x: и ниже F9ZemEndH тоже по потоку, до касания. Удержание на
// 190 м застало гор 10.6 в 16 м от центра, из-за отставания руля (команда
// 8, факт 1-3) пропустило центр на 5.5 м/с и увело на 15 м за него.
// Прогноз по потоку с тех же состояний: 17.7 м при 16 до центра, с
// зажигания 816 при 826 - ступень села бы в центр. F9BurnSim и считает
// по потоку до земли, так что теперь полёт совпадает с прогнозом.
// Удержание остаётся только когда ступень не снижается.
set F9BurnRetroVV to 1.

// 24.09 01:0x: доводка внизу. Импульс по потоку точен (прогноз на 206 м
// +17, факт +16), но точку приносит глайд с разбросом +-15 м - касание
// то у одного края палубы, то у другого. Точка остановки по потоку -
// прогоном модели (F9BjRun, свежий каждые ~0.5-1 с): промах =
// F9BjHv * F9BjK - F9BjD на момент старта прогона. Поправка горизонтали
// -промах / F9BjK за F9DivTau, боковой составляющей тяги: отклонение от
// потока не больше F9DivAng и только при скорости ниже F9DivV, где воздух
// слабый (на 150 м/с напор вчетверо меньше, чем на 300). Выше - чистый
// поток, как было.
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
        // 24.09 01:2x: ниже F9DivMinH по потоку нельзя: гор около нуля,
        // направление потока перескакивает на другую сторону, руль на одном
        // двигателе отстаёт ~1.5 с - факт 6 в старую сторону при команде 4 в
        // новую, гор 0 -> 3 к касанию, подскоки. Здесь - гашение гор
        // с упреждением через F9HoldLead (боковая тяга текущего наклона),
        // команда проходит через ноль плавно. Центр к этой высоте уже 1-3 м.
        // 24.09 01:5x: гашение работает (касание гор 0.2), но центр уплывал
        // 0 -> 3 м: закон держал только скорость. Добавлена желаемая скорость
        // к центру d * F9TermW (до F9TermVMax). Упреждение F9TermLead 1.5 с -
        // отставание руля на одном двигателе: при 1 с на 24 м команда 1,
        // факт 4 - наклон с высоты 30 м перелетел, гор ушла в другую сторону.
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

// Газ: обеспечиваем ВЕРТИКАЛЬНУЮ составляющую команды с поправкой на
// текущий наклон.
//
// Раньше здесь была проекция команды на ось ступени - vdot(a, forevector).
// Логика казалась честной: тяга идёт вдоль носа, значит и брать надо то,
// что вдоль носа. На деле это регулятор с положительной обратной связью, и
// прошлый прогон его показал целиком:
//
//   h=16  vv=-2.8 (цель -3.0)  thr=44
//   h=12  vv=-3.6 (цель -2.6)  thr=41
//   h=9   vv=-4.9 (цель -2.2)  thr=38
//   h=3   vv=-8.1 (цель -1.0)  thr=38      касание -8.86
//
// Ошибка по вертикали растёт, а газ ПАДАЕТ. Потому что при отставании руля
// нос уходит от команды, косинус между ними падает, проекция вместе с ним -
// и тяга снимается ровно в тот момент, когда она нужнее всего. Ступень
// проваливается, ошибка растёт, команда качается сильнее, довернуться ещё
// труднее. Дальше AoA -43 градуса и скольжение 83, что и было в панели.
//
// Правильно наоборот: наклон - дело РУЛЯ, а газ обязан удержать вертикаль
// при любом наклоне. Поэтому делим на косинус, а не умножаем на него:
// завалились на 20 градусов - дайте на 6% больше тяги, а не на 6% меньше.
//
// Ниже F9ThrCosMin ступень лежит настолько, что вертикали от тяги не
// добиться никаким газом - там честнее ноль, чем полная тяга вбок.
set F9ThrCosMin to 0.35.

// Потребная ТЯГА в килоньютонах. Одно определение - и для газа, и для
// решения, сколько двигателей держать. Раньше это были две разные формулы,
// и они расходились.
// Газ и под горизонталь (21.09 18:50, F9-KARTA "Газ под горизонталь").
// Газ считался только по вертикали, горизонталь шла довеском tg(наклона).
// В RTLS вертикаль идёт с опережением профиля (-258 при -298), газ 0.26,
// наклон упёрт в 25 - боковых 5.5 м/с2 при команде 8, ступень проходит
// над точкой на 45 м/с и садится в 106 м. Выше F9SwitchAlt газ - максимум
// из вертикальной и горизонтальной потребности (по фактическому наклону в
// сторону команды). Вертикаль при этом уходит медленнее профиля - это
// безопасная сторона, закон сам снимет газ, когда горизонталь погашена.
set F9ThrHSinMin to 0.1.           // sin наклона, ниже которого не считаем
set F9ThrHVvK to 0.5.              // не тянуть, если снижаемся медленнее половины профиля

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

// Страховка от края. Регулятор мягкий по построению, и у него нет права
// решать судьбу посадки: если даже полной тяги едва хватает остановиться,
// газ идёт в единицу мимо всякого профиля.
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

// Команда считается ОДИН раз за проход цикла и кладётся в переменные, а
// локи только читают готовое. Раньше lock steering и lock throttle звали
// F9ACmd каждый свой раз, плюс третий раз печать - четыре прохода по всей
// цепочке (площадка, профиль, время до касания) на каждый такт физики.
// У kOS бюджет инструкций на такт конечный, и переполнить его означает
// растянуть управление на несколько тактов.
set F9ACmdV to up:vector * F9GLocal().
set F9SteerV to up:vector.
set F9ThrV to 0.

lock throttle to F9ThrV.
lock steering to lookdirup(F9SteerV, F9TopRef()).

set F9GearDone to false.
set F9HoverT0 to 0.
set F9NextPrint to 0.
// Выход по РАДИОВЫСОТЕ, а не только по высоте над площадкой.
//
// F9AltAbovePad меряет от terrainheight точки прицеливания, а над океаном
// это ДНО: у баржи в точке 33.5/-74.9 оно на несколько километров ниже
// уровня моря, и условие "<1" не выполнялось никогда. Прогон 16.09 вечером
// ровно на этом и погиб: ступень дошла до воды с запасом 167 м/с, цикл не
// кончился, она провисела пятнадцать секунд, выжгла всё до нуля и упала с
// вертикальной -15.3.
until ship:status = "LANDED" or ship:status = "SPLASHED"
      or F9H() < 0.5 or F9AltAbovePad() < 1 {
    // F9KeepS2 здесь СОЗНАТЕЛЬНО не зовётся. Внутри восемь wait 0.001, а
    // каждый wait в kOS отдаёт минимум такт - это около 0.16 с замершего
    // управления на каждый вызов. В планировании это терпимо, в посадочном
    // импульсе такая пауза каждые пять секунд - потеря управления. К этому
    // моменту вторая ступень либо уже на орбите, либо далеко.
    // "такт" в логе - самый долгий проход цикла за полсекунды.
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

    // Переход с трёх двигателей на один - ПО ПРОФИЛЮ.
    //
    // Три двигателя здесь не режим посадки, а способ не разбиться: при
    // минимальном дросселе они дают тягу к весу 3.7, и у самой земли ими
    // рулить нечем, можно только выключать. Один Merlin на минимуме даёт
    // 1.2 - он умеет и тормозить, и придержать, и именно на нём ступень
    // закрывает последние метры.
    //
    // Поэтому число двигателей задаёт профиль: выше точки перехода - три,
    // ниже - один, и переключаемся сразу, как только скорость вошла в
    // одномоторный профиль. Раньше решение принималось по потребной тяге и
    // ступень доходила до воды на трёх.
    if F9BurnMode = 3 and ship:mass > 0 {
        if F9BurnEngines() = 1 {
            if F9ThreeDownT0 = 0 set F9ThreeDownT0 to time:seconds.
        }
        else set F9ThreeDownT0 to 0.

        if F9ThreeDownT0 > 0 and time:seconds - F9ThreeDownT0 > F9ThreeDownHold {
            F9SetEngineMode(1).
            set F9BurnMode to 1.
            // 24.09 00:2x: на одном двигателе при mst 4 ступень перелетала
            // команду (команда 3, факт 13 назад) и сползла от центра на
            // 4.4 м/с. Хоппер на одном двигателе с mst 1 садился в 0.8 м.
            // На трёх и больших наклонах mst 1 отставал - там остаётся 4.
            set steeringmanager:maxstoppingtime to 1.
            print "  switching to 1 engine, h=" +
                  round(F9H(), 0) + " v=" +
                  round(ship:velocity:surface:mag, 0).
            F9LandLog("TO 1 ENG h" + round(F9H()) +
                      " v" + round(ship:velocity:surface:mag) +
                      " profile" + round(F9SwitchV())).
        }
    }

    // Сторож зависания. Если ступень почти не снижается и при этом не
    // села - значит профиль считает, что он уже на нуле, а он не на нуле.
    // Ровно так был потерян прошлый бустер: висел на 38% тяги восемнадцать
    // метров над землёй, пока бак не опустел.
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
        // Принудительное снижение не помогло, а земля рядом - значит мы уже
        // на ней, и профиль этого не видит. Дальше висеть нельзя: топливо
        // кончится, и падать будем с нуля тяги.
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

// Глушим по-настоящему.
//
// Раньше здесь было "lock throttle to 0" и сразу "unlock throttle" - и
// двигатель продолжал работать уже на воде. UNLOCK возвращает управление
// газом игроку, а у игрока в рычаге осталось то значение, что стояло до
// старта скрипта. Ноль, заданный перед этим, вместе с блокировкой и
// снимается.
//
// Поэтому: сначала обнуляем РУЧНОЙ рычаг, потом отпускаем блокировку, и
// отдельно гасим сами двигатели - это уже независимо от любого газа.
lock throttle to 0.
F9Mark("land").
set F9Phase to "landed".
// "недолёт" > 0 - центр ещё впереди по линии подхода, "вбок" - поперёк.
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

// Замер настоящей высоты палубы. Ступень стоит, радиовысотомер меряет до
// ВОДЫ (баржа для него не рельеф), значит высота настила это ровно
// alt:radar минус вылет опор. Другого способа узнать её нет: размеров баржи
// у нас не было, а автозамер на борту баржи меряет мачту.
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
// Промах со ЗНАКОМ, разложенный по вектору подхода.
//
// Голая величина ничего не говорит о том, куда крутить: три посадки подряд
// дали 1.1, 29.2 и 57.8 метра, и по этим числам не понять, недолёт это или
// перелёт. А ручка ровно одна и прямо в метрах - F9LngBias, смещение точки
// прицеливания. Продольный минус - недолёт, значит смещение увеличить.
if F9Guided() {
    // Раскладку берём по КУРСУ ПУСКА, а не по F9ApproachVec.
    //
    // F9ApproachVec смотрит из ступени на площадку ПРЯМО СЕЙЧАС. Пока
    // ступень не долетела, он совпадает с направлением подхода, но стоит
    // проскочить площадку - разворачивается на 180 градусов, и перелёт
    // читается как недолёт. Прогон 22:48 сел на 29 метров ЗА баржу, а
    // терминал напечатал "вдоль -43.2", то есть недолёт. По этому знаку
    // самонастройка увеличила бы прицел и увела ступень ещё дальше.
    // Курс пуска не разворачивается никогда.
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
// Высота в момент касания. Если она заметно отличается от F9GearHeight,
// профиль весь спуск считал не от той земли - править надо эту ручку, а не
// коэффициенты. Мерить на глаз по интервалу печати больше не придётся.
print "  touchdown: above pad " + round(F9AltAbovePad(), 1) +
      ", radar " + round(alt:radar, 1) +
      " (F9GearRadar " + round(F9GearRadar, 1) + ")".
print "  vertical " + round(ship:verticalspeed, 2) + " m/s".
print "  remaining " + round(F9DvLeft()) + " m/s (" + round(F9FuelPct(), 1) + "% tank)".

// Фактическая точка касания - в общий файл баржи. Это и есть калибровка:
// прогноз для следующего пуска строится по прошлым полётам, а не по модели
// атмосферы. Профиль повторяем: три прогона 16.09 дали 214.3, 214.5 и 216.4
// км от стола при одном и том же курсе и грузе.
//
// Пишем ЛЮБОЙ режим, не только asds: приводнение - такая же точка.
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
