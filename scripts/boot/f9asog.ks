// =====================================================================
// boot/f9asog.ks - загрузчик баржи ASDS.
//
// Ставится в VAB: правый клик по kOSProcessor баржи -> Boot File.
//
// Схема та же, что у boot/f9s2.ks: сверяем ДВА исходника (f9asog и f9lib),
// при расхождении пересобираем на борт и перезагружаемся. f9asog первой же
// строкой делает "run once f9lib" - без библиотеки он не стартует.
//
// Баржа висит на воде месяцами игрового времени и почти всегда вне
// физической дальности. Поэтому скрипт стартует сам и сам же ждёт точку в
// общем файле: подойти к барже и запустить её руками перед каждым пуском
// не выйдет.
// =====================================================================

wait until ship:unpacked.

clearscreen.
print "=== F9 boot: ASDS barge ===".

if homeconnection:isconnected {
    switch to 0.
    set F9Fresh to false.
    if exists("1:f9asog.ksm") and exists("1:f9lib.ksm")
       and exists("1:/boot/f9asog.ks") and exists("1:/boot/f9lib.ks") {
        if open("0:f9asog.ks"):readall:string = open("1:/boot/f9asog.ks"):readall:string {
            if open("0:f9lib.ks"):readall:string = open("1:/boot/f9lib.ks"):readall:string {
                set F9Fresh to true.
            }
            else print "f9lib changed - rebuilding.".
        }
        else print "f9asog changed - rebuilding.".
    }
    else print "no local build - first build.".

    if not F9Fresh {
        compile "0:/f9lib.ks" to "1:/f9lib.ksm".
        compile "0:/f9asog.ks" to "1:/f9asog.ksm".
        copypath("0:f9asog.ks", "1:/boot/").
        copypath("0:f9lib.ks", "1:/boot/").
        copypath("0:f9lib.ks", "1:").
        set core:bootfilename to "f9asog.ksm".
        print "  built, rebooting...".
        reboot.
    }
    print "build on board is up to date.".
}
else print "no link to KSC - cannot update the build.".

switch to 1.
if exists("1:f9asog.ksm") and exists("1:f9lib.ksm") {
    runpath("1:f9asog.ksm").
}
else if exists("0:/f9asog.ks") {
    print "no local build - running from the Archive.".
    switch to 0.
    runpath("0:/f9asog.ks").
}
else print "f9asog NOT FOUND ON BOARD OR IN THE ARCHIVE.".
