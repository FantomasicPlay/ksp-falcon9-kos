// =====================================================================
// boot/f9s2.ks - загрузчик вторая ступень Falcon 9.
//
// Ставится в VAB: правый клик по kOSProcessor в TE.F9.Fairing.Adapter -> Boot File.
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

clearscreen.
print "=== F9 boot: second stage ===".

if core:part:name:contains("Interstage") {
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
        if exists("1:f9s2.ksm") and exists("1:f9lib.ksm")
           and exists("1:/boot/f9s2.ks") and exists("1:/boot/f9lib.ks") {
            if open("0:f9s2.ks"):readall:string = open("1:/boot/f9s2.ks"):readall:string {
                if open("0:f9lib.ks"):readall:string = open("1:/boot/f9lib.ks"):readall:string {
                    set F9Fresh to true.
                }
                else print "f9lib changed - rebuilding.".
            }
            else print "f9s2 changed - rebuilding.".
        }
        else print "no local build - first build.".

        if not F9Fresh {
            // Компилируем СРАЗУ НА БОРТ, а не в архив.
            //
            // Раньше .ksm ложились рядом с исходниками в архиве, и это один
            // раз уже стоило разбирательства: "run once f9lib" из f9check
            // подхватывал старый f9lib.ksm вместо только что правленого
            // f9lib.ks, отчего скрипт падал на функции, которая в исходнике
            // есть. В архиве должны лежать только исходники.
            compile "0:/f9lib.ks" to "1:/f9lib.ksm".
            compile "0:/f9s2.ks" to "1:/f9s2.ksm".
            print "  compiled".

            copypath("0:f9s2.ks", "1:/boot/").
            copypath("0:f9lib.ks", "1:/boot/").
            copypath("0:f9lib.ks", "1:").
            print "  copied on board".

            set core:bootfilename to "f9s2.ksm".
            print "  rebooting...".
            reboot.
        }

        print "build on board is up to date.".
}
else print "no link to KSC - cannot update the build.".

// Сюда попадаем, когда пересборка не нужна: запускаем то, что лежит на борту.
// С борта запускаемся только если на борту есть И полётный скрипт, И
// библиотека: без неё f9s2 падает на первой же строке.
switch to 1.
if exists("1:f9s2.ksm") and exists("1:f9lib.ksm") {
    runpath("1:f9s2.ksm").
}
else if exists("0:/f9s2.ks") {
    // Из архива - только переключившись на него: иначе "run once f9lib"
    // будет искать библиотеку на бортовом диске, где её и нет.
    print "no local build - running from the Archive.".
    switch to 0.
    runpath("0:/f9s2.ks").
}
else print "f9s2 NOT FOUND ON BOARD OR IN THE ARCHIVE.".
