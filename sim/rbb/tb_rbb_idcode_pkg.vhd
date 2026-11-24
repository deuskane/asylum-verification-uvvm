-------------------------------------------------------------------------------
-- Title      : tb_rbb_idcode_pkg
-- Project    : asylum-verification-uvvm
-------------------------------------------------------------------------------
-- File       : tb_rbb_idcode_pkg.vhd
-- Author     : Mathieu Rosiere
-- Company    :
-- Created    : 2026-11-24
-- Platform   :
-- Standard   : VHDL'08
-------------------------------------------------------------------------------
-- Description:
--  Scenario idcode of tb_rbb : IDCODE of every TAP of the chain after the
--  reset, in one DR scan of the whole chain (rbb_check_dr) ; then each TAP in
--  turn as the target of the BFM (head / tail bits) : every TAP in BYPASS,
--  IDCODE written to the target only (the others stay in BYPASS), its IDCODE
--  read with rbb_check_dr and rbb_scan_dr ; then the target alone in BYPASS :
--  8 bits delayed by the 3 TAPs of the chain (the head bits reach TDO).
-------------------------------------------------------------------------------
-- Copyright (c) 2026
-------------------------------------------------------------------------------
-- Revisions  :
-- Date        Version  Author   Description
-- 2026-11-24  1.0      mrosiere Created
-------------------------------------------------------------------------------

library ieee;
use     ieee.std_logic_1164.all;
use     ieee.numeric_std.all;

library uvvm_util;
context uvvm_util.uvvm_util_context;

library asylum_uvvm;
use     asylum_uvvm.jtag_bfm_pkg.all;
use     asylum_uvvm.rbb_bfm_pkg.all;

use     work.tb_jtag_bfm_pkg.all;
use     work.tb_rbb_bfm_pkg.all;

package tb_rbb_idcode_pkg is

  procedure run(
    signal   clk         : in    std_logic;
    signal   rbb_if      : inout t_rbb_if;
    signal   answers     : in    t_rbb_answers;
    signal   ctrl        : out   tb_ctrl_t;
    signal   obs         : in    tb_obs_t
    );

end package tb_rbb_idcode_pkg;

package body tb_rbb_idcode_pkg is

  procedure run(
    signal   clk         : in    std_logic;
    signal   rbb_if      : inout t_rbb_if;
    signal   answers     : in    t_rbb_answers;
    signal   ctrl        : out   tb_ctrl_t;
    signal   obs         : in    tb_obs_t
    ) is
    constant C_WHOLE     : t_jtag_bfm_config := chain_whole_config(C_JTAG_BASE);
    constant C_ZERO      : std_logic_vector(32*C_CHAIN_NB_TAP-1 downto 0) := (others => '0');
    variable v_config    : t_jtag_bfm_config;
    variable v_data      : std_logic_vector(32-1 downto 0);
    -- Captured zeros, then the data delayed by one bit per TAP
    constant C_DATA      : std_logic_vector(8-1 downto 0) := x"B5";
    constant C_DELAYED   : std_logic_vector(8-1 downto 0) := std_logic_vector(shift_left(unsigned(C_DATA), C_CHAIN_NB_TAP));
  begin
    tb_reset("Reset", clk, rbb_if, obs, C_RBB_AXIS, C_WHOLE);
    tb_check_dr(C_ZERO, chain_idcodes, "IDCODE of every TAP after the reset", clk, rbb_if, answers, obs, C_RBB_AXIS, C_WHOLE);

    for tap in 0 to C_CHAIN_NB_TAP-1 loop
      v_config := chain_config(C_JTAG_BASE, tap);
      tb_write_ir(ir_bypass(C_WHOLE), "Every TAP in BYPASS", clk, rbb_if, answers, obs, C_RBB_AXIS, C_WHOLE);
      tb_write_ir(C_IR_IDCODE, "IDCODE of TAP " & to_string(tap), clk, rbb_if, answers, obs, C_RBB_AXIS, v_config);
      check_chain_ir(obs.tap_ir, tap, C_IR_IDCODE, "IDCODE of TAP " & to_string(tap));
      tb_check_dr(x"00000000", C_CHAIN_IDCODE(tap), "IDCODE of TAP " & to_string(tap), clk, rbb_if, answers, obs, C_RBB_AXIS, v_config);
      tb_scan_dr(x"FFFFFFFF", v_data, "IDCODE of TAP " & to_string(tap), clk, rbb_if, answers, obs, C_RBB_AXIS, v_config);
      check_value(v_data, C_CHAIN_IDCODE(tap), ERROR, "rbb_scan_dr of the IDCODE of TAP " & to_string(tap), C_RBB_SCOPE);
      tb_write_ir(ir_bypass(v_config), "BYPASS of TAP " & to_string(tap), clk, rbb_if, answers, obs, C_RBB_AXIS, v_config);
      tb_check_dr(C_DATA, C_DELAYED, "BYPASS of TAP " & to_string(tap) & " : 8 bits delayed by the chain", clk, rbb_if, answers, obs, C_RBB_AXIS, v_config);
    end loop;
  end procedure run;

end package body tb_rbb_idcode_pkg;
