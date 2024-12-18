#!/bin/bash
qemu-system-i386 -fda build/main_floppy.img -daemonize -pidfile qemu.pid
vncviewer localhost:5900
./stop.sh