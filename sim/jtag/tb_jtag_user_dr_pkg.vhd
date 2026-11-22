-------------------------------------------------------------------------------
-- Title      : tb_jtag_user_dr_pkg
-- Project    : asylum-verification-uvvm
-------------------------------------------------------------------------------
-- File       : tb_jtag_user_dr_pkg.vhd
-- Author     : Mathieu Rosiere
-- Company    :
-- Created    : 2026-11-22
-- Platform   :
-- Standard   : VHDL'08
-------------------------------------------------------------------------------
-- Description:
--  Scenario user_dr of tb_jtag : user data register of dr_width
--  bits : each scan captures the value of the previous one (power-on value
--  0 first), patterns that toggle every bit ; IR then DR scans, the user
--  register is kept while IDCODE is selected.
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

package tb_jtag_user_dr_pkg is

  -- Wide user data register, IR then DR scans
  procedure run(
    signal   jtag_if     : inout t_jtag_if;
    signal   tap_state   : in    tap_state_t;
    signal   trst_cnt    : in    natural;
    constant config      : in    t_jtag_bfm_config;
    constant dr_width    : in    positive
    );

end package tb_jtag_user_dr_pkg;

package body tb_jtag_user_dr_pkg is

  procedure run(
    signal   jtag_if     : inout t_jtag_if;
    signal   tap_state   : in    tap_state_t;
    signal   trst_cnt    : in    natural;
    constant config      : in    t_jtag_bfm_config;
    constant dr_width    : in    positive
    ) is
    variable v_zero      : std_logic_vector(dr_width-1 downto 0) := (others => '0');
    variable v_p1        : std_logic_vector(dr_width-1 downto 0);
    variable v_p2        : std_logic_vector(dr_width-1 downto 0);
    variable v_p3        : std_logic_vector(dr_width-1 downto 0);
    variable v_data      : std_logic_vector(dr_width-1 downto 0);
  begin
    -- "...1100" (not symmetric), its complement, "...1010"
    for i in v_p1'range loop
      v_p1(i) := '1' when (i mod 4) < 2 else '0';
      v_p3(i) := '1' when (i mod 2) = 1 else '0';
    end loop;
    v_p2 := not v_p1;

    tb_reset("Reset", jtag_if, tap_state, config);
    tb_write_ir(C_IR_USER, "USER", jtag_if, tap_state, config);
    tb_check_dr(v_p1, v_zero, "Power-on value captured", jtag_if, tap_state, config);
    tb_check_dr(v_p2, v_p1  , "Previous value captured", jtag_if, tap_state, config);

    -- IDCODE, then USER again : the user register is kept
    tb_write_ir(C_IR_IDCODE, "IDCODE", jtag_if, tap_state, config);
    tb_check_dr(x"00000000", C_IDCODE, "IDCODE between two USER scans", jtag_if, tap_state, config);
    tb_write_ir(C_IR_USER, "USER", jtag_if, tap_state, config);
    tb_check_dr(v_p3, v_p2  , "User register kept", jtag_if, tap_state, config);
    tb_scan_dr(v_p1, v_data, "Previous value captured", jtag_if, tap_state, config);
    check_value(v_data, v_p3, ERROR, "jtag_scan_dr of the user register", C_TB_SCOPE);
  end procedure run;

end package body tb_jtag_user_dr_pkg;
