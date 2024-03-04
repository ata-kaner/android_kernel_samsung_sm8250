# AnyKernel3 Ramdisk Mod Script
# osm0sis @ xda-developers

## AnyKernel setup
# begin properties
properties() { '
kernel.string=Kernel for S20 FE (Snapdragon) by pascua28 @ xda-developers
do.devicecheck=1
do.modules=0
do.systemless=1
do.cleanup=1
do.cleanuponabort=0
device.name1=r8q
device.name2=r8qxx
device.name3=r8qxxx
device.name4=
device.name5=
supported.versions=
supported.patchlevels=
'; } # end properties

# shell variables
block=/dev/block/platform/soc/1d84000.ufshc/by-name/boot;
is_slot_device=0;
ramdisk_compression=auto;


## AnyKernel methods (DO NOT CHANGE)
# import patching functions/variables - see for reference
. tools/ak3-core.sh;


## AnyKernel file attributes
# set permissions/ownership for included ramdisk files
set_perm_recursive 0 0 755 644 $ramdisk/*;
set_perm_recursive 0 0 750 750 $ramdisk/init* $ramdisk/sbin;

## AnyKernel boot install
dump_boot;

case "$ZIPFILE" in
   *-perf*)
    ui_print " • Flashing performance device tree blob • "
    mv $home/kona-perf.dtb $home/dtb
    ;;
   *)
    mv $home/kona.dtb $home/dtb
    ;;
esac

# begin ramdisk changes

# end ramdisk changes

oneui=$(file_getprop /system/build.prop ro.build.version.oneui);
unica=$(file_getprop /system/build.prop ro.unica.version);

if [ -z "$unica" ] && [ "$oneui" == "60000" ]; then
   ui_print ""
   ui_print "OneUI 6.0 detected! Patching selinux"
   patch_cmdline "androidboot.selinux" "androidboot.selinux=permissive";
fi

write_boot;
## end boot install
