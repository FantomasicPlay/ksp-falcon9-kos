wait until ship:unpacked.

clearscreen.
print "=== F9 boot: Dragon ===".

if homeconnection:isconnected {
    switch to 0.
    set F9Fresh to false.
    if exists("1:f9dragon.ksm") and exists("1:/boot/f9dragon.ks") {
        if open("0:f9dragon.ks"):readall:string = open("1:/boot/f9dragon.ks"):readall:string set F9Fresh to true.
        else print "f9dragon changed - rebuilding.".
    }
    else print "no local build - first build.".

    if not F9Fresh {
        compile "0:/f9dragon.ks" to "1:/f9dragon.ksm".
        copypath("0:f9dragon.ks", "1:/boot/").
        set core:bootfilename to "f9dragon.ksm".
        print "  built, rebooting...".
        reboot.
    }
    print "build on board is up to date.".
}
else print "no link to KSC - cannot update the build.".

switch to 1.
if exists("1:f9dragon.ksm") runpath("1:f9dragon.ksm").
else if exists("0:/f9dragon.ks") {
    switch to 0.
    runpath("0:/f9dragon.ks").
}
else print "f9dragon NOT FOUND ON BOARD OR IN THE ARCHIVE.".
