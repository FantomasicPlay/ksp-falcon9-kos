
wait until ship:unpacked.

clearscreen.
print "=== F9 boot: second stage ===".

if core:part:name:contains("Interstage") {
    print "WARNING: processor is in " + core:part:name + ",".
    print "the boot files seem swapped.".
}

if homeconnection:isconnected {
        switch to 0.

        set F9Fresh to false.
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

switch to 1.
if exists("1:f9s2.ksm") and exists("1:f9lib.ksm") {
    runpath("1:f9s2.ksm").
}
else if exists("0:/f9s2.ks") {
    print "no local build - running from the Archive.".
    switch to 0.
    runpath("0:/f9s2.ks").
}
else print "f9s2 NOT FOUND ON BOARD OR IN THE ARCHIVE.".
