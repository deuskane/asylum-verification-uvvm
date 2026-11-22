-------------------------------------------------------------------------------
-- Title      : tb_jtag_idle_pkg
-- Project    : asylum-verification-uvvm
-------------------------------------------------------------------------------
-- File       : tb_jtag_idle_pkg.vhd
-- Author     : Mathieu Rosiere
-- Company    :
-- Created    : 2026-11-22
-- Platform   :
-- Standard   : VHDL'08
-------------------------------------------------------------------------------
-- Description:
--  Scenario idle of tb_jtag : duration of each procedure in
--  TCK periods : jtag_idle, IR and DR scans (path from and to
--  Run-Test/Idle), with config.idle_cycles = 3, jtag_reset with and without
--  TRST pulse.
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

package tb_jtag_idle_pkg is

  -- Number of TCK cycles of each procedure, idle cycles
  procedure run(
    signal   jtag_if     : inout t_jtag_if;
    signal   tap_state   : in    tap_state_t;
    signal   trst_cnt    : in    natural;
    constant config      : in    t_jtag_bfm_config;
    constant dr_width    : in    positive
    );

end package tb_jtag_idle_pkg;

package body tb_jtag_idle_pkg is

  procedure run(
    signal   jtag_if     : inout t_jtag_if;
    signal   tap_state   : in    tap_state_t;
    signal   trst_cnt    : in    natural;
    constant config      : in    t_jtag_bfm_config;
    constant dr_width    : in    positive
    ) is
    variable v_config    : t_jtag_bfm_config := config;
    variable v_data      : std_logic_vector(dr_width-1 downto 0);
    variable v_start     : time;
  begin
    tb_reset("Reset", jtag_if, tap_state, v_config);

    v_start := now;
    tb_idle(7, "7 cycles", jtag_if, tap_state, v_config);
    check_value(now - v_start, 7*v_config.tck_period, ERROR, "jtag_idle(7) : 7 TCK", C_TB_SCOPE);

    -- Run-Test/Idle, Select-DR, (Select-IR), Capture, Shift, Exit1, Update, Run-Test/Idle
    v_start := now;
    tb_write_ir(C_IR_USER, "USER", jtag_if, tap_state, v_config);
    check_value(now - v_start, (v_config.ir_width+6)*v_config.tck_period, ERROR, "IR scan : ir_width+6 TCK", C_TB_SCOPE);
    v_start := now;
    tb_scan_dr((dr_width-1 downto 0 => '1'), v_data, "DR scan", jtag_if, tap_state, v_config);
    check_value(now - v_start, (dr_width+5)*v_config.tck_period, ERROR, "DR scan : dr_width+5 TCK", C_TB_SCOPE);

    -- idle_cycles more TCK in Run-Test/Idle after each scan
    v_config.idle_cycles := 3;
    v_start := now;
    tb_write_ir(C_IR_USER, "USER, 3 idle cycles", jtag_if, tap_state, v_config);
    check_value(now - v_start, (v_config.ir_width+6+3)*v_config.tck_period, ERROR, "IR scan, 3 idle cycles : ir_width+9 TCK", C_TB_SCOPE);
    v_start := now;
    tb_scan_dr((dr_width-1 downto 0 => '0'), v_data, "DR scan, 3 idle cycles", jtag_if, tap_state, v_config);
    check_value(now - v_start, (dr_width+5+3)*v_config.tck_period, ERROR, "DR scan, 3 idle cycles : dr_width+8 TCK", C_TB_SCOPE);

    -- Reset : TRST pulse (2 periods), 5 TCK with TMS = 1, 1 TCK to Run-Test/Idle
    v_config.trst_enable := true;
    v_start := now;
    tb_reset("TRST and TMS", jtag_if, tap_state, v_config);
    check_value(now - v_start, (2+6)*v_config.tck_period, ERROR, "jtag_reset with TRST : 2 periods and 6 TCK", C_TB_SCOPE);
    v_config.trst_enable := false;
    v_start := now;
    tb_reset("TMS only", jtag_if, tap_state, v_config);
    check_value(now - v_start, 6*v_config.tck_period, ERROR, "jtag_reset without TRST : 6 TCK", C_TB_SCOPE);
  end procedure run;

end package body tb_jtag_idle_pkg;
