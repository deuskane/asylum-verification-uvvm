#!/bin/bash
#-----------------------------------------------------------------------------
# Title      : Hooks of the OpenOCD co-simulations
# Project    : Asylum
#-----------------------------------------------------------------------------
# File       : cosim.sh
# Author     : mrosiere
#-----------------------------------------------------------------------------
# Description: Hooks of a co-simulation target (cwd = work root, kit files
#              in rbb/, copied by the core asylum:verification:openocd) :
#                build                        : pre_build, ./librbb.so
#                                               (rbb/rbb_server.c)
#                start <openocd.cfg> [<gdb.py>] : pre_run, in the background :
#                    wait for the remote_bitbang port of the simulation, then
#                    without a GDB script : OpenOCD with <openocd.cfg>, which
#                    runs the checks and ends with shutdown (openocd.log) ;
#                    with a GDB script : OpenOCD (openocd.log), then
#                    gdb-multiarch -x <gdb.py> on its GDB port (gdb.log), then
#                    OpenOCD shutdown on its TCL port.
#                    OpenOCD quits : the simulation ends.
#                check                        : post_run, prints the logs,
#                    fails unless the last log (gdb.log, else openocd.log) has
#                    the line $COSIM_PASS
#              ./cosim.cfg (VAR=value lines, written by the testbench) is
#              exported to OpenOCD and GDB.
#              Environment : RBB_PORT (9824, also read by rbb_server.c),
#              GDB_PORT (3333) and TCL_PORT (6666) of the .cfg, COSIM_PASS
#              ("SCENARIO PASS"), COSIM_TIMEOUT (1800 s for OpenOCD / GDB).
#              Needs gcc, openocd and gdb-multiarch (with Python).
#-----------------------------------------------------------------------------
# Copyright (c) 2026
#-----------------------------------------------------------------------------
# Revisions  :
# Date        Version  Author   Description
# 2026-11-24  1.0      mrosiere Created from the cosim.sh of
#                               asylum-debug-jtag and of
#                               asylum-processor-WardRV
#-----------------------------------------------------------------------------

RBB_PORT=${RBB_PORT:-9824}
GDB_PORT=${GDB_PORT:-3333}
TCL_PORT=${TCL_PORT:-6666}
COSIM_PASS=${COSIM_PASS:-SCENARIO PASS}
COSIM_TIMEOUT=${COSIM_TIMEOUT:-1800}

# True when the TCP port is listening
listening() {
    awk -v p=$(printf ':%04X' $1) '$2 ~ p"$" && $4 == "0A" {f = 1} END {exit !f}' /proc/net/tcp
}

# Wait (seconds) until the port $1 listens or the process $2 ends
wait_port() {
    for t in $(seq 1 900); do
        listening $1 && return 0
        kill -0 $2 2>/dev/null || return 1
        sleep 1
    done
    return 1
}

# $1 : process of the simulation, $2 : OpenOCD configuration, $3 : GDB script
background() {
    wait_port $RBB_PORT $1 || { echo "FAIL : no simulation" > result; return; }
    if [ -f cosim.cfg ]; then
        set -a; . ./cosim.cfg; set +a
    fi
    if [ -z "$3" ]; then
        timeout $COSIM_TIMEOUT openocd -f $2 > openocd.log 2>&1
        log=openocd.log
    else
        openocd -f $2 > openocd.log 2>&1 &
        if wait_port $GDB_PORT $!; then
            timeout $COSIM_TIMEOUT gdb-multiarch -nx -batch -x $3 > gdb.log 2>&1
        else
            echo "OpenOCD not ready" > gdb.log
        fi
        # TCL command shutdown : OpenOCD quits, the simulation ends
        printf 'shutdown\032' > /dev/tcp/127.0.0.1/$TCL_PORT
        wait
        log=gdb.log
    fi
    grep -qx "$COSIM_PASS" $log && echo PASS > result || echo "FAIL : see $log" > result
}

case $1 in
    build)
        gcc -shared -fPIC -O2 -Wall -o librbb.so rbb/rbb_server.c ;;
    start)
        rm -f result openocd.log gdb.log
        setsid bash $0 background $PPID "$2" "$3" < /dev/null > cosim.log 2>&1 &
        echo "cosim.sh : OpenOCD started in the background" ;;
    background)
        background $2 "$3" "$4" ;;
    check)
        for t in $(seq 1 60); do [ -s result ] && break; sleep 1; done
        for f in openocd.log gdb.log; do [ -f $f ] && { echo "===== $f"; cat $f; }; done
        echo "===== co-simulation : $(cat result)"
        [ "$(cat result)" = PASS ] ;;
    *)
        echo "Usage : $0 build | start <openocd.cfg> [<gdb script>] | check"
        exit 1 ;;
esac
