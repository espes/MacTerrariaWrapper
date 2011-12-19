export AS="as -arch i386"
export CC="cc -arch i386 -mmacosx-version-min=10.5 -no_compact_linkedit -framework CoreFoundation -liconv"

$CC -o relaunch -lobjc -framework Cocoa relaunch.m 

for src in steam_api User32 winmm rlimit; do
    $CC -fno-common -c $src.c
    $CC -dynamiclib -o $src.dylib -dylib $src.o
    rm $src.o
done