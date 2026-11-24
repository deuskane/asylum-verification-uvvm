-------------------------------------------------------------------------------
-- Title      : rbb_pkg
-- Project    : asylum-verification-uvvm
-------------------------------------------------------------------------------
-- File       : rbb_pkg.vhd
-- Author     : Mathieu Rosiere
-- Company    :
-- Created    : 2026-11-24
-- Platform   :
-- Standard   : VHDL'08
-------------------------------------------------------------------------------
-- Description:
--  GHDL VHPIDIRECT binding of rbb_server.c (OpenOCD remote_bitbang server,
--  built as ./librbb.so in the simulation directory by "cosim.sh build",
--  pre_build hook of the co-simulation targets), library asylum_uvvm :
--  BYTE mode (rbb_recv, rbb_send : the DUT decodes the bytes) and PIN mode
--  (rbb_tick : JTAG pins). rbb_axis and rbb_jtag wrap them as testbench
--  entities.
-------------------------------------------------------------------------------
-- Copyright (c) 2026
-------------------------------------------------------------------------------
-- Revisions  :
-- Date        Version  Author   Description
-- 2026-11-24  1.0      mrosiere Created from the rbb_pkg of
--                               asylum-debug-jtag and of
--                               asylum-processor-WardRV
-------------------------------------------------------------------------------

package rbb_pkg is

  -----------------------------------------------------------------------------
  -- BYTE mode
  -----------------------------------------------------------------------------
  -- Values of rbb_recv that are not a byte
  constant RBB_NONE   : integer := -1;                            -- No byte yet
  constant RBB_CLOSED : integer := -2;                            -- OpenOCD closed the connection (or never came)

  -- Next byte sent by OpenOCD (the first call waits for OpenOCD)
  impure function rbb_recv return integer;
  attribute foreign of rbb_recv : function is "VHPIDIRECT ./librbb.so rbb_recv";

  -- One byte to OpenOCD
  procedure rbb_send(c : integer);
  attribute foreign of rbb_send : procedure is "VHPIDIRECT ./librbb.so rbb_send";

  -----------------------------------------------------------------------------
  -- PIN mode
  -----------------------------------------------------------------------------
  -- Bits of the value returned by rbb_tick (TRST, SRST : 1 asserted)
  constant RBB_TCK    : natural := 0;
  constant RBB_TMS    : natural := 1;
  constant RBB_TDI    : natural := 2;
  constant RBB_QUIT   : natural := 3;                             -- OpenOCD quit
  constant RBB_TRST   : natural := 4;
  constant RBB_SRST   : natural := 5;

  -- Commands of OpenOCD up to the next pin change ('R' answered with tdo :
  -- 0 / 1), returns the pins (the first call waits for OpenOCD)
  impure function rbb_tick(tdo : integer) return integer;
  attribute foreign of rbb_tick : function is "VHPIDIRECT ./librbb.so rbb_tick";

end package rbb_pkg;

package body rbb_pkg is

  impure function rbb_recv return integer is
  begin
    report "rbb_recv : VHPIDIRECT function not bound (./librbb.so)" severity failure;
    return RBB_CLOSED;
  end function rbb_recv;

  procedure rbb_send(c : integer) is
  begin
    report "rbb_send : VHPIDIRECT procedure not bound (./librbb.so)" severity failure;
  end procedure rbb_send;

  impure function rbb_tick(tdo : integer) return integer is
  begin
    report "rbb_tick : VHPIDIRECT function not bound (./librbb.so)" severity failure;
    return 2**RBB_QUIT;
  end function rbb_tick;

end package body rbb_pkg;
