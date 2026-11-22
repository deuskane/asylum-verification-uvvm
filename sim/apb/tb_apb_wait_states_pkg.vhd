-------------------------------------------------------------------------------
-- Title      : tb_apb_wait_states_pkg
-- Project    : asylum-verification-uvvm
-------------------------------------------------------------------------------
-- File       : tb_apb_wait_states_pkg.vhd
-- Author     : Mathieu Rosiere
-- Company    :
-- Created    : 2026-11-22
-- Platform   :
-- Standard   : VHDL'08
-------------------------------------------------------------------------------
-- Description:
--  Scenario wait_states of tb_apb : the slave holds pready low during
--  1, 3 and max_wait_cycles (no timeout) cycles of the access phase : the
--  transfer lasts 2 + wait states cycles, data written and read back.
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

package tb_apb_wait_states_pkg is

  -- Wait states : pready low during 1, 3 and max_wait_cycles cycles
  procedure run(
    signal   clk         : in    std_logic;
    signal   apb_if      : inout t_apb_if;
    signal   wait_states : out   natural
    );

end package tb_apb_wait_states_pkg;

package body tb_apb_wait_states_pkg is

  procedure run(
    signal   clk         : in    std_logic;
    signal   apb_if      : inout t_apb_if;
    signal   wait_states : out   natural
    ) is
    constant C_WAITS     : integer_vector := (1, 3, C_APB_BFM_CONFIG_DEFAULT.max_wait_cycles);
    variable v_start     : time;
  begin
    -- The first transfer aligns on the clock
    tb_write(16#30#, x"00000000", "Alignment", clk, apb_if);

    for i in C_WAITS'range loop
      wait_states <= C_WAITS(i);
      v_start     := now;
      tb_write(16#31#+i, not mem_reset_value(16#31#+i), to_string(C_WAITS(i)) & " wait states", clk, apb_if);
      tb_check(16#31#+i, not mem_reset_value(16#31#+i), to_string(C_WAITS(i)) & " wait states", clk, apb_if);
      check_value(now - v_start, 2*(2+C_WAITS(i))*C_CLK_PERIOD, ERROR, "Write and read with " & to_string(C_WAITS(i)) & " wait states", C_TB_SCOPE);
    end loop;
    wait_states <= 0;
  end procedure run;

end package body tb_apb_wait_states_pkg;
