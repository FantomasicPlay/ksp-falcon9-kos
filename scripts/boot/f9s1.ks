
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

if homeconnection:isconnected {
        switch to 0.

        set F9Fresh to false.
        local bd is "0:/f9build/" + core:part:uid + "/".
        if exists("1:/src") deletepath("1:/src").
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
            print "no local build - building.".
            for f in list("1:/f9s1.ksm", "1:/f9lib.ksm", bd + "f9s1.ks", bd + "f9lib.ks") {
                if not exists(f) print "  missing " + f.
            }
            print "  free on board " + round(volume(1):freespace / 1024) + " KB".
        }

        if not F9Fresh and exists("1:/rebuilt.flag") {
            deletepath("1:/rebuilt.flag").
            print "!!! CHECK FAILED AGAIN AFTER REBUILD - running as is.".
            hudtext("F9 boot: check failed after rebuild", 15, 2, 24, red, false).
            set F9Fresh to true.
        }
        else if F9Fresh and exists("1:/rebuilt.flag") deletepath("1:/rebuilt.flag").

        if not F9Fresh {
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

switch to 1.
if exists("1:f9s1.ksm") and exists("1:f9lib.ksm") {
    runpath("1:f9s1.ksm").
}
else if exists("0:/f9s1.ks") {
    print "no local build - running from the Archive.".
    switch to 0.
    runpath("0:/f9s1.ks").
}
else print "f9s1 NOT FOUND ON BOARD OR IN THE ARCHIVE.".
