#!/bin/sh
# Copyright (C) 2008  Henry Harrington
#
# This program is free software; you can redistribute it and/or
# modify it under the terms of the GNU General Public License
# version 2 as published by the Free Software Foundation.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with this program; if not, write to the Free Software
# Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston, MA  02110-1301, USA.

set -u
set -e

cleanup() {
	rm -Rf "iso_stage/"
}

trap cleanup INT TERM EXIT

rm -f "cdrom.iso"
rm -Rf "iso_stage/"
mkdir -p "iso_stage/"
mkdir -p "iso_stage/grub/"

# Copy important stuff
cp tools/stage2_eltorito "iso_stage/grub/"
#cp tools/kboot/cdkboot "iso_stage/"
#cp loader.cfg "iso_stage/"
#cp lispos.image "iso_stage/lispos.image"
cp lispos-warm.image "iso_stage/lispos.image"
#cp lispos-warm-blt.image "iso_stage/lispos.image"
#cp lispos-warm-asdf.image "iso_stage/lispos.image"
#cp lispos-warm-compiler.image "iso_stage/lispos.image"
#cp lispos-warm-swank.image "iso_stage/lispos.image"
#cp file.llf "iso_stage/"
#cp multiboot.llf "iso_stage/"
#cp edit/*.llf "iso_stage/"
cp init.llf "iso_stage/"
#cp peek.llf "iso_stage/"
cp file-compiler.llf "iso_stage/"

echo "default 0" >> "iso_stage/grub/menu.lst"
echo "timeout 0" >> "iso_stage/grub/menu.lst"

echo "title LispOS" >> "iso_stage/grub/menu.lst"
echo "kernel /lispos.image" >> "iso_stage/grub/menu.lst"
echo "module /init.llf" >> "iso_stage/grub/menu.lst"
echo "module /file-compiler.llf" >> "iso_stage/grub/menu.lst"

#echo "title LispOS (Bells & Whistles)" >> "iso_stage/grub/menu.lst"
#echo "kernel /lispos.image" >> "iso_stage/grub/menu.lst"
#echo "module /profiler.llf" >> "iso_stage/grub/menu.lst"
#echo "module /ethernet.llf" >> "iso_stage/grub/menu.lst"
#echo "module /rtl8139.llf" >> "iso_stage/grub/menu.lst"
#echo "module /file.llf" >> "iso_stage/grub/menu.lst"
#echo "module /irc.llf" >> "iso_stage/grub/menu.lst"
#echo "module /telnet.llf" >> "iso_stage/grub/menu.lst"
#echo "module /edit.llf" >> "iso_stage/grub/menu.lst"
#echo "module /buffer.llf" >> "iso_stage/grub/menu.lst"
#
#echo "title LispOS (Nothing)" >> "iso_stage/grub/menu.lst"
#echo "kernel /lispos.image" >> "iso_stage/grub/menu.lst"
#
#echo "title LispOS (Profiler only)" >> "iso_stage/grub/menu.lst"
#echo "kernel /lispos.image" >> "iso_stage/grub/menu.lst"
#echo "module /profiler.llf" >> "iso_stage/grub/menu.lst"
#
#echo "title LispOS (network and editor)" >> "iso_stage/grub/menu.lst"
#echo "kernel /lispos.image" >> "iso_stage/grub/menu.lst"
#echo "module /ethernet.llf" >> "iso_stage/grub/menu.lst"
#echo "module /file.llf" >> "iso_stage/grub/menu.lst"
#echo "module /edit.llf" >> "iso_stage/grub/menu.lst"
#echo "module /buffer.llf" >> "iso_stage/grub/menu.lst"

#mkisofs -JR -b cdkboot -no-emul-boot -boot-load-size 4 -boot-info-table -o "cdrom.iso" "iso_stage/"
mkisofs -R -b grub/stage2_eltorito -no-emul-boot -boot-load-size 4 -boot-info-table -o "cdrom.iso" "iso_stage/"