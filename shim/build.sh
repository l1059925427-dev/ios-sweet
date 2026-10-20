#!/bin/bash
# Build the shim and wrap it in a boot image.
#   PLATFORM=sweet (default): boot.img v2 mirroring the stock PixelOS header
#   PLATFORM=haydn:           boot.img v3 like the stock MIUI boot_a.img
# $1 (optional) is an xnu payload from tools/mkpayload.py to use as ramdisk.
set -euo pipefail
cd "$(dirname "$0")"
PLATFORM=${PLATFORM:-sweet}
case "$PLATFORM" in
	sweet) PLAT_CFLAGS=-DPLATFORM_SWEET ;;
	haydn) PLAT_CFLAGS=-DPLATFORM_HAYDN ;;
	*) echo "error: unknown PLATFORM=$PLATFORM" >&2; exit 1 ;;
esac
CC=aarch64-linux-gnu-gcc
OBJCOPY=aarch64-linux-gnu-objcopy
CFLAGS="-O2 -ffreestanding -nostdlib -fno-pic -mgeneral-regs-only -mstrict-align -fno-stack-protector -Wall -Wextra $PLAT_CFLAGS"
mkdir -p out
for f in start.S shim.c console.c mmu.c fdt.c loader.c ufs.c; do
	$CC $CFLAGS -c $f -o out/${f%.*}.o
done
# The image runs wherever ABL puts it with no relocation pass: only the
# header's image_size (start.o, linked at 0) may be an absolute address.
abs=$(aarch64-linux-gnu-readelf -r out/shim.o out/console.o out/mmu.o out/fdt.o out/loader.o out/ufs.o | grep -c ABS64 || true)
[ "$abs" = 0 ] || { echo "error: $abs absolute relocations in C objects" >&2; exit 1; }
$CC $CFLAGS -static -T shim.ld -Wl,--build-id=none -Wl,--no-warn-rwx-segments -Wl,-N \
	out/start.o out/shim.o out/console.o out/mmu.o out/fdt.o out/loader.o out/ufs.o -o out/shim.elf
$OBJCOPY -O binary out/shim.elf out/Image
# ABL copies the file; pad to image_size so .bss/stacks exist as zeroed bytes.
size=$(aarch64-linux-gnu-nm out/shim.elf | awk '$3=="_end"{print strtonum("0x"$1)}')
truncate -s "$size" out/Image
# Ramdisk: an empty newc cpio (ABL dislikes a zero-size ramdisk). The xnu
# payload ($1) is appended to our own kernel image on haydn (MIUI ABL v3 does
# not deliver the boot ramdisk where its FDT claims); on sweet it stays the
# boot ramdisk as before.
(cd out && rm -rf rd && mkdir rd && cd rd && find . | cpio -o -H newc --quiet | gzip -9 > ../ramdisk.bin)
if [ -n "${1:-}" ]; then
	if [ "$PLATFORM" = haydn ]; then
		sz=$(stat -c%s out/Image)
		pad=$(( (8 - sz % 8) % 8 ))
		[ "$pad" = 0 ] || dd if=/dev/zero bs=1 count="$pad" >> out/Image 2>/dev/null
		cat "$1" >> out/Image
	else
		cp "$1" out/ramdisk.bin
	fi
fi
if [ "$PLATFORM" = haydn ]; then
	# Stock boot_a.img is header v3 (kernel 48.8 MiB, os 13.0.0 / 2025-02, empty
	# cmdline). v3 drops all address fields; ABL places the kernel itself
	# (0xa0080000 on lahaina) and passes the merged DTB in x0.
	mkbootimg --header_version 3 --kernel out/Image --ramdisk out/ramdisk.bin \
		--pagesize 4096 --os_version 13.0.0 --os_patch_level 2025-02 \
		--cmdline "console=null" -o out/shim-boot-haydn.img
else
	mkbootimg --header_version 2 --kernel out/Image --ramdisk out/ramdisk.bin \
		--dtb ../dtb/boot_unpacked/dtb --base 0 --kernel_offset 0x8000 --ramdisk_offset 0x1000000 \
		--tags_offset 0x100 --dtb_offset 0x1f00000 --pagesize 4096 \
		--os_version 17.0.0 --os_patch_level 2035-06 \
		--cmdline "console=null" -o out/shim-boot.img
fi
# Host render of the console layout.
gcc -O1 -Wall -o out/host_test console.c host_test.c && ./out/host_test
ls -l out/Image out/shim-boot*.img
