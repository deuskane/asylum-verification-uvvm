-------------------------------------------------------------------------------
-- Title      : tb_jtag_trst_pkg
-- Project    : asylum-verification-uvvm
-------------------------------------------------------------------------------
-- File       : tb_jtag_trst_pkg.vhd
-- Author     : Mathieu Rosiere
-- Company    :
-- Created    : 2026-11-22
-- Platform   :
-- Standard   : VHDL'08
-------------------------------------------------------------------------------
-- Description:
--  Scenario trst of tb_jtag : jtag_trst alone, a TRST* pulse of 2 periods
--  without TCK edge (TCK low, TMS = 1) : Test-Logic-Reset, IDCODE selected.
--  Without TRST* (config.trst_enable false) : one TB_ERROR, no pulse.
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

package tb_jtag_trst_pkg is

  -- TRST* pulse alone
  procedure run(
    signal   jtag_if     : inout t_jtag_if;
    signal   tap_state   : in    tap_state_t;
    signal   trst_cnt    : in    natural;
    signal   tck_cnt     : in    natural;
    constant config      : in    t_jtag_bfm_config
    );

end package tb_jtag_trst_pkg;

package body tb_jtag_trst_pkg is

  procedure run(
    signal   jtag_if     : inout t_jtag_if;
    signal   tap_state   : in    tap_state_t;
    signal   trst_cnt    : in    natural;
    signal   tck_cnt     : in    natural;
    constant config      : in    t_jtag_bfm_config
    ) is
    variable v_config    : t_jtag_bfm_config := config;
    variable v_trst      : natural;
    variable v_tck       : natural;
    variable v_start     : time;
    variable v_tb_errors : natural;
  begin
    v_config.trst_enable := true;
    tb_reset("Reset", jtag_if, tap_state, v_config);
    tb_write_ir(ir_bypass(v_config), "BYPASS", jtag_if, tap_state, v_config);

    -- TRST* pulse alone : 2 periods, no TCK edge, TCK low and TMS = 1
    v_trst  := trst_cnt;
    v_tck   := tck_cnt;
    v_start := now;
    tb_trst("TRST pulse", jtag_if, tap_state, v_config);
    check_value(now - v_start, 2*v_config.tck_period, ERROR, "jtag_trst : 2 periods", C_TB_SCOPE);
    check_value(trst_cnt, v_trst+1, ERROR, "One TRST pulse", C_TB_SCOPE);
    check_value(tck_cnt, v_tck, ERROR, "No TCK edge", C_TB_SCOPE);
    check_value(jtag_if.trst_b, '1', ERROR, "TRST released", C_TB_SCOPE);
    check_value(jtag_if.tck, '0', ERROR, "TCK low", C_TB_SCOPE);
    check_value(jtag_if.tms, '1', ERROR, "TMS = 1", C_TB_SCOPE);

    -- Test-Logic-Reset : IDCODE selected
    tb_idle(1, "Run-Test/Idle", jtag_if, tap_state, v_config);
    tb_check_dr(x"00000000", C_IDCODE, "IDCODE selected after the TRST pulse", jtag_if, tap_state, v_config);

    -- DUT without TRST* : one TB_ERROR, no pulse, TAP still in Run-Test/Idle
    v_config.trst_enable := false;
    increment_expected_alerts_and_stop_limit(TB_ERROR, 1, "jtag_trst without TRST*", C_TB_SCOPE);
    v_tb_errors := get_alert_counter(TB_ERROR);
    v_trst      := trst_cnt;
    tb_trst("No TRST*", jtag_if, tap_state, v_config);
    check_value(get_alert_counter(TB_ERROR), v_tb_errors+1, ERROR, "One TB_ERROR of jtag_trst without TRST*", C_TB_SCOPE);
    check_value(trst_cnt, v_trst, ERROR, "No TRST pulse without TRST*", C_TB_SCOPE);
    check_value(tap_state = RUN_TEST_IDLE, ERROR, "TAP still in Run-Test/Idle", C_TB_SCOPE);
  end procedure run;

end package body tb_jtag_trst_pkg;
