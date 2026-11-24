-------------------------------------------------------------------------------
-- Title      : tb_rbb_user_dr_pkg
-- Project    : asylum-verification-uvvm
-------------------------------------------------------------------------------
-- File       : tb_rbb_user_dr_pkg.vhd
-- Author     : Mathieu Rosiere
-- Company    :
-- Created    : 2026-11-24
-- Platform   :
-- Standard   : VHDL'08
-------------------------------------------------------------------------------
-- Description:
--  Scenario user_dr of tb_rbb : user data register of each TAP of the chain
--  (a different width per TAP) as the target of the BFM, with 2 idle cycles
--  after each scan : power-on value 0 captured and a pattern written, the
--  pattern read back and its complement written (number of TCK cycles of the
--  scan) ; then USER in every TAP, one DR scan of the whole chain (no head /
--  tail bits) reads every complement at its place.
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

package tb_rbb_user_dr_pkg is

  procedure run(
    signal   clk         : in    std_logic;
    signal   rbb_if      : inout t_rbb_if;
    signal   answers     : in    t_rbb_answers;
    signal   ctrl        : out   tb_ctrl_t;
    signal   obs         : in    tb_obs_t
    );

end package tb_rbb_user_dr_pkg;

package body tb_rbb_user_dr_pkg is

  -- Pattern of the TAP tap : "...110110", shifted by tap
  function pattern(tap : natural) return std_logic_vector is
    variable v_data : std_logic_vector(C_CHAIN_DR_WIDTH(tap)-1 downto 0);
  begin
    for i in v_data'range loop
      v_data(i) := '0' when ((i + tap) mod 3) = 0 else '1';
    end loop;
    return v_data;
  end function pattern;

  -- Complement of every pattern, TAP 0 (TDI side) in the MSB
  function complements return std_logic_vector is
    constant C_WIDTH : natural := C_CHAIN_DR_WIDTH(0) + C_CHAIN_DR_WIDTH(1) + C_CHAIN_DR_WIDTH(2);
    variable v_data  : std_logic_vector(C_WIDTH-1 downto 0);
    variable v_low   : natural := 0;
  begin
    for tap in C_CHAIN_NB_TAP-1 downto 0 loop
      v_data(v_low+C_CHAIN_DR_WIDTH(tap)-1 downto v_low) := not pattern(tap);
      v_low := v_low + C_CHAIN_DR_WIDTH(tap);
    end loop;
    return v_data;
  end function complements;

  procedure run(
    signal   clk         : in    std_logic;
    signal   rbb_if      : inout t_rbb_if;
    signal   answers     : in    t_rbb_answers;
    signal   ctrl        : out   tb_ctrl_t;
    signal   obs         : in    tb_obs_t
    ) is
    constant C_IDLE      : natural := 2;
    constant C_WHOLE     : t_jtag_bfm_config := chain_whole_config(C_JTAG_BASE);
    constant C_EXP       : std_logic_vector := complements;
    constant C_ZERO      : std_logic_vector(C_EXP'range) := (others => '0');
    variable v_config    : t_jtag_bfm_config;
    variable v_tck       : natural;
  begin
    tb_reset("Reset", clk, rbb_if, obs, C_RBB_AXIS, C_WHOLE);

    for tap in 0 to C_CHAIN_NB_TAP-1 loop
      v_config := chain_config(C_JTAG_BASE, tap);
      v_config.idle_cycles := C_IDLE;
      tb_write_ir(C_IR_USER, "USER of TAP " & to_string(tap), clk, rbb_if, answers, obs, C_RBB_AXIS, v_config);
      check_chain_ir(obs.tap_ir, tap, C_IR_USER, "USER of TAP " & to_string(tap));
      tb_check_dr(pattern(tap), C_ZERO(C_CHAIN_DR_WIDTH(tap)-1 downto 0), "Power-on value of TAP " & to_string(tap), clk, rbb_if, answers, obs, C_RBB_AXIS, v_config);
      v_tck := obs.tck_cnt;
      tb_check_dr(not pattern(tap), pattern(tap), "Pattern of TAP " & to_string(tap), clk, rbb_if, answers, obs, C_RBB_AXIS, v_config);
      -- Select-DR, Capture-DR, Shift-DR ; the bits of the chain ; Update-DR,
      -- Run-Test/Idle ; idle cycles
      check_value(obs.tck_cnt - v_tck, 3 + C_CHAIN_NB_TAP-1 + C_CHAIN_DR_WIDTH(tap) + 2 + C_IDLE, ERROR, "TCK cycles of the DR scan of TAP " & to_string(tap), C_RBB_SCOPE);
    end loop;

    -- USER in every TAP, the whole chain in one DR scan
    tb_write_ir(chain_opcode(C_IR_USER), "USER in every TAP", clk, rbb_if, answers, obs, C_RBB_AXIS, C_WHOLE);
    tb_check_dr(C_ZERO, C_EXP, "Complement of each pattern, whole chain", clk, rbb_if, answers, obs, C_RBB_AXIS, C_WHOLE);
  end procedure run;

end package body tb_rbb_user_dr_pkg;
