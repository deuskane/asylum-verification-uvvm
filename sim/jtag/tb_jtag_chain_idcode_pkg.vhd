-------------------------------------------------------------------------------
-- Title      : tb_jtag_chain_idcode_pkg
-- Project    : asylum-verification-uvvm
-------------------------------------------------------------------------------
-- File       : tb_jtag_chain_idcode_pkg.vhd
-- Author     : Mathieu Rosiere
-- Company    :
-- Created    : 2026-11-23
-- Platform   :
-- Standard   : VHDL'08
-------------------------------------------------------------------------------
-- Description:
--  Scenario chain_idcode of tb_jtag (MODEL "chain") : IDCODE of every TAP
--  after the reset, in one DR scan of the whole chain ; then each TAP in turn
--  as the target of the BFM (head / tail bits) : every TAP in BYPASS, IDCODE
--  written to the target only (the others stay in BYPASS), its IDCODE read
--  with jtag_check_dr and jtag_scan_dr.
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

package tb_jtag_chain_idcode_pkg is

  -- IDCODE of each TAP of the chain, the others in BYPASS
  procedure run(
    signal   jtag_if     : inout t_jtag_if;
    signal   tap_state   : in    tap_state_t;
    signal   tap_ir      : in    integer_vector;
    constant config      : in    t_jtag_bfm_config
    );

end package tb_jtag_chain_idcode_pkg;

package body tb_jtag_chain_idcode_pkg is

  procedure run(
    signal   jtag_if     : inout t_jtag_if;
    signal   tap_state   : in    tap_state_t;
    signal   tap_ir      : in    integer_vector;
    constant config      : in    t_jtag_bfm_config
    ) is
    constant C_WHOLE     : t_jtag_bfm_config := chain_whole_config(config);
    variable v_config    : t_jtag_bfm_config;
    variable v_zero      : std_logic_vector(32*C_CHAIN_NB_TAP-1 downto 0) := (others => '0');
    variable v_idcodes   : std_logic_vector(32*C_CHAIN_NB_TAP-1 downto 0);
    variable v_data      : std_logic_vector(32-1 downto 0);
  begin
    -- IDCODE of every TAP after the reset : TAP 0 (TDI side) in the MSB
    for tap in 0 to C_CHAIN_NB_TAP-1 loop
      v_idcodes(32*(C_CHAIN_NB_TAP-tap)-1 downto 32*(C_CHAIN_NB_TAP-1-tap)) := C_CHAIN_IDCODE(tap);
    end loop;
    tb_reset("Reset", jtag_if, tap_state, C_WHOLE);
    tb_check_dr(v_zero, v_idcodes, "IDCODE of every TAP after the reset", jtag_if, tap_state, C_WHOLE);

    for tap in 0 to C_CHAIN_NB_TAP-1 loop
      v_config := chain_config(config, tap);
      tb_write_ir(ir_bypass(C_WHOLE), "Every TAP in BYPASS", jtag_if, tap_state, C_WHOLE);
      tb_write_ir(C_IR_IDCODE, "IDCODE of TAP " & to_string(tap), jtag_if, tap_state, v_config);
      check_chain_ir(tap_ir, tap, C_IR_IDCODE, "IDCODE of TAP " & to_string(tap));
      tb_check_dr(x"00000000", C_CHAIN_IDCODE(tap), "IDCODE of TAP " & to_string(tap), jtag_if, tap_state, v_config);
      tb_scan_dr(x"FFFFFFFF", v_data, "IDCODE of TAP " & to_string(tap), jtag_if, tap_state, v_config);
      check_value(v_data, C_CHAIN_IDCODE(tap), ERROR, "jtag_scan_dr of the IDCODE of TAP " & to_string(tap), C_TB_SCOPE);
    end loop;
  end procedure run;

end package body tb_jtag_chain_idcode_pkg;
