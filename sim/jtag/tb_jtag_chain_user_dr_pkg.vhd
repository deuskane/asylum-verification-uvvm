-------------------------------------------------------------------------------
-- Title      : tb_jtag_chain_user_dr_pkg
-- Project    : asylum-verification-uvvm
-------------------------------------------------------------------------------
-- File       : tb_jtag_chain_user_dr_pkg.vhd
-- Author     : Mathieu Rosiere
-- Company    :
-- Created    : 2026-11-23
-- Platform   :
-- Standard   : VHDL'08
-------------------------------------------------------------------------------
-- Description:
--  Scenario chain_user_dr of tb_jtag (MODEL "chain") : user data register of
--  each TAP (a different width per TAP) as the target of the BFM : power-on
--  value 0 captured and a pattern per TAP written ; each pattern read back
--  after the scans of the other TAPs (they went through its BYPASS register)
--  and its complement written ; then USER in every TAP, one DR scan of the
--  whole chain (no head / tail bits) reads every complement at its place.
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

package tb_jtag_chain_user_dr_pkg is

  -- User data register of each TAP of the chain, the others in BYPASS
  procedure run(
    signal   jtag_if     : inout t_jtag_if;
    signal   tap_state   : in    tap_state_t;
    signal   tap_ir      : in    integer_vector;
    constant config      : in    t_jtag_bfm_config
    );

end package tb_jtag_chain_user_dr_pkg;

package body tb_jtag_chain_user_dr_pkg is

  -- Pattern of the TAP tap : "...110110", shifted by tap
  function pattern(tap : natural) return std_logic_vector is
    variable v_data : std_logic_vector(C_CHAIN_DR_WIDTH(tap)-1 downto 0);
  begin
    for i in v_data'range loop
      v_data(i) := '0' when ((i + tap) mod 3) = 0 else '1';
    end loop;
    return v_data;
  end function pattern;

  -- Width of the user data registers of the chain
  function dr_width_sum return natural is
    variable v_sum  : natural := 0;
  begin
    for tap in 0 to C_CHAIN_NB_TAP-1 loop
      v_sum := v_sum + C_CHAIN_DR_WIDTH(tap);
    end loop;
    return v_sum;
  end function dr_width_sum;

  -- Complement of every pattern, TAP 0 (TDI side) in the MSB
  function complements return std_logic_vector is
    variable v_data : std_logic_vector(dr_width_sum-1 downto 0);
    variable v_low  : natural := 0;
  begin
    for tap in C_CHAIN_NB_TAP-1 downto 0 loop
      v_data(v_low+C_CHAIN_DR_WIDTH(tap)-1 downto v_low) := not pattern(tap);
      v_low := v_low + C_CHAIN_DR_WIDTH(tap);
    end loop;
    return v_data;
  end function complements;

  procedure run(
    signal   jtag_if     : inout t_jtag_if;
    signal   tap_state   : in    tap_state_t;
    signal   tap_ir      : in    integer_vector;
    constant config      : in    t_jtag_bfm_config
    ) is
    constant C_WHOLE     : t_jtag_bfm_config := chain_whole_config(config);
    constant C_EXP       : std_logic_vector := complements;
    constant C_ZERO      : std_logic_vector(C_EXP'range) := (others => '0');
    variable v_config    : t_jtag_bfm_config;
  begin
    tb_reset("Reset", jtag_if, tap_state, C_WHOLE);

    -- Power-on value, then the pattern of the TAP written
    for tap in 0 to C_CHAIN_NB_TAP-1 loop
      v_config := chain_config(config, tap);
      tb_write_ir(C_IR_USER, "USER of TAP " & to_string(tap), jtag_if, tap_state, v_config);
      check_chain_ir(tap_ir, tap, C_IR_USER, "USER of TAP " & to_string(tap));
      tb_check_dr(pattern(tap), C_ZERO(C_CHAIN_DR_WIDTH(tap)-1 downto 0), "Power-on value of TAP " & to_string(tap), jtag_if, tap_state, v_config);
    end loop;

    -- Pattern read back, its complement written
    for tap in 0 to C_CHAIN_NB_TAP-1 loop
      v_config := chain_config(config, tap);
      tb_write_ir(C_IR_USER, "USER of TAP " & to_string(tap), jtag_if, tap_state, v_config);
      tb_check_dr(not pattern(tap), pattern(tap), "Pattern of TAP " & to_string(tap) & " kept", jtag_if, tap_state, v_config);
    end loop;

    -- USER in every TAP, the whole chain in one DR scan
    tb_write_ir(chain_opcode(C_IR_USER), "USER in every TAP", jtag_if, tap_state, C_WHOLE);
    for tap in 0 to C_CHAIN_NB_TAP-1 loop
      check_value(tap_ir(tap), C_IR_USER, ERROR, "IR of TAP " & to_string(tap) & " after USER in every TAP", C_TB_SCOPE);
    end loop;
    tb_check_dr(C_ZERO, C_EXP, "Complement of each pattern, whole chain", jtag_if, tap_state, C_WHOLE);
  end procedure run;

end package body tb_jtag_chain_user_dr_pkg;
