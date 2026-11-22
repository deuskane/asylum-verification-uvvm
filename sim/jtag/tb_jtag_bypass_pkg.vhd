-------------------------------------------------------------------------------
-- Title      : tb_jtag_bypass_pkg
-- Project    : asylum-verification-uvvm
-------------------------------------------------------------------------------
-- File       : tb_jtag_bypass_pkg.vhd
-- Author     : Mathieu Rosiere
-- Company    :
-- Created    : 2026-11-22
-- Platform   :
-- Standard   : VHDL'08
-------------------------------------------------------------------------------
-- Description:
--  Scenario bypass of tb_jtag : BYPASS (all ones) and an
--  undecoded opcode select the 1-bit BYPASS register : an 8-bit scan comes
--  out delayed by one bit after the captured 0, a 1-bit scan captures 0.
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
use     asylum_uvvm.jtag_bfm_pkg.all;

use     work.tb_jtag_bfm_pkg.all;

package tb_jtag_bypass_pkg is

  -- BYPASS and undecoded opcode : one bit delay, capture 0
  procedure run(
    signal   jtag_if     : inout t_jtag_if;
    signal   tap_state   : in    tap_state_t;
    signal   trst_cnt    : in    natural;
    constant config      : in    t_jtag_bfm_config;
    constant dr_width    : in    positive
    );

end package tb_jtag_bypass_pkg;

package body tb_jtag_bypass_pkg is

  procedure run(
    signal   jtag_if     : inout t_jtag_if;
    signal   tap_state   : in    tap_state_t;
    signal   trst_cnt    : in    natural;
    constant config      : in    t_jtag_bfm_config;
    constant dr_width    : in    positive
    ) is
    constant C_PATTERN   : std_logic_vector(8-1 downto 0) := x"A7";
    variable v_opcodes   : integer_vector(0 to 1);
  begin
    v_opcodes := (ir_bypass(config), C_IR_UNDECODED);
    tb_reset("Reset", jtag_if, tap_state, config);

    for i in v_opcodes'range loop
      tb_write_ir(v_opcodes(i), "Opcode " & to_string(v_opcodes(i)), jtag_if, tap_state, config);
      tb_check_dr(C_PATTERN, C_PATTERN(6 downto 0) & '0', "One bit delay, capture 0", jtag_if, tap_state, config);
      tb_check_dr("1", "0", "1-bit scan, capture 0", jtag_if, tap_state, config);
    end loop;
  end procedure run;

end package body tb_jtag_bypass_pkg;
