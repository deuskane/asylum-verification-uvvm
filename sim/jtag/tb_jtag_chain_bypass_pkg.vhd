-------------------------------------------------------------------------------
-- Title      : tb_jtag_chain_bypass_pkg
-- Project    : asylum-verification-uvvm
-------------------------------------------------------------------------------
-- File       : tb_jtag_chain_bypass_pkg.vhd
-- Author     : Mathieu Rosiere
-- Company    :
-- Created    : 2026-11-23
-- Platform   :
-- Standard   : VHDL'08
-------------------------------------------------------------------------------
-- Description:
--  Scenario chain_bypass of tb_jtag (MODEL "chain") : every TAP in BYPASS,
--  the chain is a shift register of one bit per TAP (capture 0) ; then each
--  TAP in turn as the target of the BFM, in BYPASS : every TAP in IDCODE, the
--  BYPASS opcode written to the target (all ones in every TAP), one bit
--  scan (capture 0), 8-bit scan delayed by one bit per TAP of the chain.
-------------------------------------------------------------------------------
-- Copyright (c) 2026
-------------------------------------------------------------------------------
-- Revisions  :
-- Date        Version  Author   Description
-- 2026-11-23  1.0      mrosiere Created
-------------------------------------------------------------------------------

library ieee;
use     ieee.std_logic_1164.all;
use     ieee.numeric_std.all;

library uvvm_util;
context uvvm_util.uvvm_util_context;

library asylum_uvvm;
use     asylum_uvvm.jtag_bfm_pkg.all;

use     work.tb_jtag_bfm_pkg.all;

package tb_jtag_chain_bypass_pkg is

  -- BYPASS of the whole chain and of each target
  procedure run(
    signal   jtag_if     : inout t_jtag_if;
    signal   tap_state   : in    tap_state_t;
    signal   tap_ir      : in    integer_vector;
    constant config      : in    t_jtag_bfm_config
    );

end package tb_jtag_chain_bypass_pkg;

package body tb_jtag_chain_bypass_pkg is

  procedure run(
    signal   jtag_if     : inout t_jtag_if;
    signal   tap_state   : in    tap_state_t;
    signal   tap_ir      : in    integer_vector;
    constant config      : in    t_jtag_bfm_config
    ) is
    constant C_WHOLE     : t_jtag_bfm_config := chain_whole_config(config);
    constant C_DATA      : std_logic_vector(8-1 downto 0) := x"B5";
    -- Captured zeros, then the data delayed by one bit per TAP
    constant C_DELAYED   : std_logic_vector(8-1 downto 0) := std_logic_vector(shift_left(unsigned(C_DATA), C_CHAIN_NB_TAP));
    variable v_config    : t_jtag_bfm_config;
  begin
    tb_reset("Reset", jtag_if, tap_state, C_WHOLE);

    -- Every TAP in BYPASS
    tb_write_ir(ir_bypass(C_WHOLE), "Every TAP in BYPASS", jtag_if, tap_state, C_WHOLE);
    check_chain_ir(tap_ir, 0, ir_bypass(chain_config(config, 0)), "every TAP in BYPASS");
    tb_check_dr(C_DATA, C_DELAYED, "8 bits through the chain in BYPASS", jtag_if, tap_state, C_WHOLE);

    -- Each TAP as the target, in BYPASS
    for tap in 0 to C_CHAIN_NB_TAP-1 loop
      v_config := chain_config(config, tap);
      tb_write_ir(chain_opcode(C_IR_IDCODE), "Every TAP in IDCODE", jtag_if, tap_state, C_WHOLE);
      tb_write_ir(ir_bypass(v_config), "BYPASS of TAP " & to_string(tap), jtag_if, tap_state, v_config);
      check_chain_ir(tap_ir, tap, ir_bypass(v_config), "BYPASS of TAP " & to_string(tap));
      tb_check_dr("1", "0", "BYPASS of TAP " & to_string(tap) & " : capture 0", jtag_if, tap_state, v_config);
      tb_check_dr(C_DATA, C_DELAYED, "BYPASS of TAP " & to_string(tap) & " : 8 bits delayed by the chain", jtag_if, tap_state, v_config);
    end loop;
  end procedure run;

end package body tb_jtag_chain_bypass_pkg;
