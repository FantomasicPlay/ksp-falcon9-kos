// =====================================================================
// boot/f9s1.ks - загрузчик первая ступень Falcon 9.
//
// Ставится в VAB: правый клик по kOSProcessor в Interstage -> Boot File.
//
// Схема и формат путей взяты у рабочего boot/booster.ks: собрать .ksm,
// положить исходник в 1:/boot/ для сверки, назначить BOOTFILENAME,
// перезагрузиться. Дальше скрипт стартует сам.
//
// Два отличия от booster, оба вынужденные:
//
// 1. Сверяем ДВА исходника - полётный и f9lib. Раньше сравнивался только
//    полётный, и правки библиотеки на борт не попадали: копия считалась
//    свежей, пересборки не было, в полёт уходила прошлая версия. Скрипт при
//    этом честно работал, просто не тот, и ловилось это тяжело.
//
// 2. Печатаем каждый шаг. Когда сборка молча не проходит, отличить её от
//    успешной невозможно, а в полёте это стоит дорого.
// =====================================================================

wait until ship:unpacked.

function F9Norm {
    parameter pth.
    return open(pth):readall:string:replace(char(65279), ""):replace(char(13), "").
}

clearscreen.
print "=== F9 boot: first stage ===".

if not core:part:name:contains("Interstage") {
    print "WARNING: processor is in " + core:part:name + ",".
    print "the boot files seem swapped.".
}

// Пересобираем ВСЕГДА, когда есть связь с КЦ - в том числе в полёте.
//
// Раньше здесь стояла проверка на FLYING/SUB_ORBITAL: мол, в полёте код
// менять нельзя. На практике это значит, что исправленный скрипт не может
// попасть на судно, которое уже летит, - а работа идёт именно так, откатом
// к разделению через FMRS. Свежая правка при этом молча не применялась, и
// ступень крутила сборку с уже найденной ошибкой.
//
// Пересборка сама по себе безопасна: сверка идёт по исходникам, и если они
// не менялись, ничего не происходит. А если менялись - перезагрузка, и
// скрипт подхватывает полёт с текущей фазы, он это умеет.
if homeconnection:isconnected {
        switch to 0.

        set F9Fresh to false.
        // Проверяем наличие ИМЕННО тех файлов, которые понадобятся в полёте.
        // Прошлая версия смотрела на 1:/boot/f9lib.ks - копию для сверки, -
        // а полётный скрипт первой же строкой делает "run once f9lib" и
        // ищет 1:/f9lib. Стоило рабочей копии пропасть из корня, и сборка
        // считалась свежей, пересборки не было, а запуск падал на
        // "Can't find file '1:/f9lib'" уже на столе.
        // 23.09: копии исходников для сверки лежат в 1:/src/, а не в
        // 1:/boot/. Раньше копия f9s1.ks затирала сам загрузчик
        // (1:/boot/f9s1.ks), поэтому bootfilename переставлялся на
        // f9s1.ksm - и при каждой следующей загрузке (FMRS, откат, reboot)
        // процессор сразу запускал старую сборку, сверка не шла вовсе.
        // Теперь загрузчиком всегда остаётся этот файл, и он сверяет
        // исходники на каждой загрузке. Сравнение - без BOM и CR, как в f9s2.
        // 23.09 21:10: копия исходника (230 КБ) на бортовой диск не влезает -
        // свободно 43 КБ, copypath молча не сработал. Копия для сверки
        // лежит в АРХИВЕ, в папке этого процессора (uid детали): архив
        // безразмерный, а папка своя у каждого процессора.
        local bd is "0:/f9build/" + core:part:uid + "/".
        if exists("1:/src") deletepath("1:/src").
        // 23.09 22:45: архив при откате к сохранению не откатывается, а борт
        // откатывается. Борт вернулся со старым .ksm, копия в архиве уже
        // новая - сверка прошла, полетела старая сборка. Метка сборки лежит
        // в обоих местах: не совпала - борт не от этой сборки.
        local stOk is exists("1:/f9stamp") and exists(bd + "stamp").
        if stOk set stOk to open("1:/f9stamp"):readall:string = open(bd + "stamp"):readall:string.
        if not stOk print "build stamp on board does not match (revert?) - rebuilding.".
        if stOk and exists("1:f9s1.ksm") and exists("1:f9lib.ksm")
           and exists(bd + "f9s1.ks") and exists(bd + "f9lib.ks") {
            if F9Norm("0:f9s1.ks") = F9Norm(bd + "f9s1.ks") {
                if F9Norm("0:f9lib.ks") = F9Norm(bd + "f9lib.ks") {
                    set F9Fresh to true.
                }
                else print "f9lib changed - rebuilding.".
            }
            else print "f9s1 changed - rebuilding.".
        }
        else {
            // Какого именно файла нет - печатаем: 23.09 без этого была
            // бесконечная пересборка без единой подсказки.
            print "no local build - building.".
            for f in list("1:/f9s1.ksm", "1:/f9lib.ksm", bd + "f9s1.ks", bd + "f9lib.ks") {
                if not exists(f) print "  missing " + f.
            }
            print "  free on board " + round(volume(1):freespace / 1024) + " KB".
        }

        // Сторож петли: пересобрали, перезагрузились, а сборка опять "не
        // свежая" - второй раз не пересобираем, запускаем то, что есть.
        if not F9Fresh and exists("1:/rebuilt.flag") {
            deletepath("1:/rebuilt.flag").
            print "!!! CHECK FAILED AGAIN AFTER REBUILD - running as is.".
            hudtext("F9 boot: check failed after rebuild", 15, 2, 24, red, false).
            set F9Fresh to true.
        }
        else if F9Fresh and exists("1:/rebuilt.flag") deletepath("1:/rebuilt.flag").

        if not F9Fresh {
            // Компилируем СРАЗУ НА БОРТ, а не в архив.
            //
            // Раньше .ksm ложились рядом с исходниками в архиве, и это один
            // раз уже стоило разбирательства: "run once f9lib" из f9check
            // подхватывал старый f9lib.ksm вместо только что правленого
            // f9lib.ks, отчего скрипт падал на функции, которая в исходнике
            // есть. В архиве должны лежать только исходники.
            compile "0:/f9lib.ks" to "1:/f9lib.ksm".
            compile "0:/f9s1.ks" to "1:/f9s1.ksm".
            print "  compiled".

            if exists(bd) deletepath(bd).
            createdir(bd).
            copypath("0:f9s1.ks", bd + "f9s1.ks").
            copypath("0:f9lib.ks", bd + "f9lib.ks").
            local st is "" + round(time:seconds * 1000) + "-" + round(random() * 1000000).
            if exists("1:/f9stamp") deletepath("1:/f9stamp").
            create("1:/f9stamp"):write(st).
            create(bd + "stamp"):write(st).
            copypath("0:f9lib.ks", "1:").
            if exists("1:/boot/f9s1.ks") deletepath("1:/boot/f9s1.ks").
            if exists("1:/boot/f9lib.ks") deletepath("1:/boot/f9lib.ks").
            copypath("0:/boot/f9s1.ks", "1:/boot/f9s1.ks").
            print "  copied on board".
            create("1:/rebuilt.flag").

            set core:bootfilename to "/boot/f9s1.ks".
            print "  rebooting...".
            reboot.
        }

        print "build on board is up to date.".
}
else print "no link to KSC - cannot update the build.".

// Сюда попадаем, когда пересборка не нужна: запускаем то, что лежит на борту.
// С борта запускаемся только если на борту есть И полётный скрипт, И
// библиотека: без неё f9s1 падает на первой же строке.
switch to 1.
if exists("1:f9s1.ksm") and exists("1:f9lib.ksm") {
    runpath("1:f9s1.ksm").
}
else if exists("0:/f9s1.ks") {
    // Из архива - только переключившись на него: иначе "run once f9lib"
    // будет искать библиотеку на бортовом диске, где её и нет.
    print "no local build - running from the Archive.".
    switch to 0.
    runpath("0:/f9s1.ks").
}
else print "f9s1 NOT FOUND ON BOARD OR IN THE ARCHIVE.".
