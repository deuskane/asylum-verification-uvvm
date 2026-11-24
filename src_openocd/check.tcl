#-----------------------------------------------------------------------------
# Title      : Checks of the OpenOCD scripts of the co-simulations
# Project    : Asylum
#-----------------------------------------------------------------------------
# File       : check.tcl
# Author     : mrosiere
#-----------------------------------------------------------------------------
# Description: Sourced by the .cfg of a co-simulation without GDB script
#              (source rbb/check.tcl, cwd = work root) :
#                check <name> <got> <exp> : compares the hex result of a
#                    drscan (<got>, without 0x) with <exp>, prints
#                    "OK   : ..." or "FAIL : ..."
#                scenario_end             : prints "SCENARIO PASS" when
#                    every check passed, else "SCENARIO FAIL", then
#                    shutdown
#-----------------------------------------------------------------------------
# Copyright (c) 2026
#-----------------------------------------------------------------------------
# Revisions  :
# Date        Version  Author   Description
# 2026-11-24  1.0      mrosiere Created from tap.cfg of
#                               asylum-verification-uvvm and jtag.cfg of
#                               asylum-debug-jtag
#-----------------------------------------------------------------------------

set fail 0

proc check {name got exp} {
    global fail
    if {[expr {"0x$got" == $exp}]} {
        echo "OK   : $name : 0x$got"
    } else {
        echo "FAIL : $name : 0x$got instead of $exp"
        set fail 1
    }
}

proc scenario_end {} {
    global fail
    if {$fail} {
        echo "SCENARIO FAIL"
    } else {
        echo "SCENARIO PASS"
    }
    shutdown
}
