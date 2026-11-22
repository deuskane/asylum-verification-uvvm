-------------------------------------------------------------------------------
-- Title      : tb_apb_back_to_back_pkg
-- Project    : asylum-verification-uvvm
-------------------------------------------------------------------------------
-- File       : tb_apb_back_to_back_pkg.vhd
-- Author     : Mathieu Rosiere
-- Company    :
-- Created    : 2026-11-22
-- Platform   :
-- Standard   : VHDL'08
-------------------------------------------------------------------------------
-- Description:
--  Scenario back_to_back of tb_apb : 4 writes then 4 reads back to back
--  without wait state : 2 cycles per transfer (setup, access), data read
--  back.
-------------------------------------------------------------------------------
-- Copyright (c) 2026
-------------------------------------------------------------------------------
-- Revisions  :
-- Date        Version  Author   Description
-- 2026-11-22  1.0      mrosiere Created
-------------------------------------------------------------------------------

library ieee;
use     ieee.std_logic_1164.all;
use     ieee.numeric_std.all;

library uvvm_util;
context uvvm_util.uvvm_util_context;

library asylum_uvvm;
use     asylum_uvvm.apb_bfm_pkg.all;

use     work.tb_apb_bfm_pkg.all;

package tb_apb_back_to_back_pkg is

  -- Back to back writes and reads, 2 cycles per transfer
  procedure run(
    signal   clk         : in    std_logic;
    signal   apb_if      : inout t_apb_if;
    signal   wait_states : out   natural
    );

end package tb_apb_back_to_back_pkg;

package body tb_apb_back_to_back_pkg is

  procedure run(
    signal   clk         : in    std_logic;
    signal   apb_if      : inout t_apb_if;
    signal   wait_states : out   natural
    ) is
    variable v_start     : time;
  begin
    -- The first transfer aligns on the clock
    tb_write(16#20#, not mem_reset_value(16#20#), "Alignment", clk, apb_if);

    v_start := now;
    for i in 1 to 4 loop
      tb_write(16#20#+i, not mem_reset_value(16#20#+i), "Back to back write " & to_string(i), clk, apb_if);
    end loop;
    check_value(now - v_start, 4*2*C_CLK_PERIOD, ERROR, "4 back to back writes, 2 cycles each", C_TB_SCOPE);

    v_start := now;
    for i in 1 to 4 loop
      tb_check(16#20#+i, not mem_reset_value(16#20#+i), "Back to back read " & to_string(i), clk, apb_if);
    end loop;
    check_value(now - v_start, 4*2*C_CLK_PERIOD, ERROR, "4 back to back reads, 2 cycles each", C_TB_SCOPE);
  end procedure run;

end package body tb_apb_back_to_back_pkg;
