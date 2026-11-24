-------------------------------------------------------------------------------
-- Title      : tb_rbb_tms_pkg
-- Project    : asylum-verification-uvvm
-------------------------------------------------------------------------------
-- File       : tb_rbb_tms_pkg.vhd
-- Author     : Mathieu Rosiere
-- Company    :
-- Created    : 2026-11-24
-- Platform   :
-- Standard   : VHDL'08
-------------------------------------------------------------------------------
-- Description:
--  Scenario tms of tb_rbb : TMS moves (rbb_tms), reset of the TAPs
--  (rbb_reset without and with TRST*), idle cycles (rbb_idle) ; after each
--  procedure, the state of the TAPs, the number of commands (2 per TCK cycle,
--  plus one, as bitbang_state_move of OpenOCD ; 't' and 'r' for TRST*), the
--  number of TCK cycles, TCK low, the TRST* pulses.
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

package tb_rbb_tms_pkg is

  procedure run(
    signal   clk         : in    std_logic;
    signal   rbb_if      : inout t_rbb_if;
    signal   answers     : in    t_rbb_answers;
    signal   ctrl        : out   tb_ctrl_t;
    signal   obs         : in    tb_obs_t
    );

end package tb_rbb_tms_pkg;

package body tb_rbb_tms_pkg is

  procedure run(
    signal   clk         : in    std_logic;
    signal   rbb_if      : inout t_rbb_if;
    signal   answers     : in    t_rbb_answers;
    signal   ctrl        : out   tb_ctrl_t;
    signal   obs         : in    tb_obs_t
    ) is
    variable v_cmd       : natural;
    variable v_tck       : natural;
    variable v_jtag      : t_jtag_bfm_config := C_JTAG_BASE;

    -- State of the TAPs, commands and TCK cycles since the previous step,
    -- TCK low
    procedure check_step(state : tap_state_t; cmds, tcks : natural; msg : string) is
    begin
      wait until falling_edge(clk);
      check_value(obs.tap_state = state  , ERROR, "TAP in " & tap_state_t'image(state) & " after " & msg, C_RBB_SCOPE);
      check_value(obs.cmd_cnt - v_cmd, cmds, ERROR, "Commands of " & msg, C_RBB_SCOPE);
      check_value(obs.tck_cnt - v_tck, tcks, ERROR, "TCK cycles of " & msg, C_RBB_SCOPE);
      check_value(obs.pins(2), '0', ERROR, "TCK low after " & msg, C_RBB_SCOPE);
      v_cmd := obs.cmd_cnt;
      v_tck := obs.tck_cnt;
    end procedure check_step;
  begin
    v_cmd := obs.cmd_cnt;
    v_tck := obs.tck_cnt;

    -- From Test-Logic-Reset (reset of the TAP models)
    rbb_tms("0", "Run-Test/Idle", clk, rbb_if, C_RBB_SCOPE, shared_msg_id_panel, C_RBB_AXIS);
    check_step(RUN_TEST_IDLE , 3, 1, "rbb_tms(""0"")");
    rbb_tms("100", "Shift-DR", clk, rbb_if, C_RBB_SCOPE, shared_msg_id_panel, C_RBB_AXIS);
    check_step(SHIFT_DR      , 7, 3, "rbb_tms(""100"")");
    rbb_tms("1111", "Select-IR-Scan", clk, rbb_if, C_RBB_SCOPE, shared_msg_id_panel, C_RBB_AXIS);
    check_step(SELECT_IR_SCAN, 9, 4, "rbb_tms(""1111"")");

    -- Reset without TRST* : 5 TCK with TMS = 1, then Run-Test/Idle
    rbb_reset("Reset without TRST*", clk, rbb_if, C_RBB_SCOPE, shared_msg_id_panel, C_RBB_AXIS, v_jtag);
    check_step(RUN_TEST_IDLE , 13, 6, "rbb_reset without TRST*");
    check_value(obs.trst_cnt, 0, ERROR, "No TRST* pulse when trst_enable is false", C_RBB_SCOPE);

    -- Reset with TRST* from Shift-IR : 't', 'r', then the TMS sequence
    rbb_tms("1100", "Shift-IR", clk, rbb_if, C_RBB_SCOPE, shared_msg_id_panel, C_RBB_AXIS);
    check_step(SHIFT_IR      , 9, 4, "rbb_tms(""1100"")");
    v_jtag.trst_enable := true;
    rbb_reset("Reset with TRST*", clk, rbb_if, C_RBB_SCOPE, shared_msg_id_panel, C_RBB_AXIS, v_jtag);
    check_step(RUN_TEST_IDLE , 15, 6, "rbb_reset with TRST*");
    check_value(obs.trst_cnt, 1, ERROR, "One TRST* pulse when trst_enable is true", C_RBB_SCOPE);
    check_value(obs.trst_b, '1', ERROR, "TRST* released after rbb_reset", C_RBB_SCOPE);

    -- Idle cycles
    rbb_idle(4, "Run-Test/Idle", clk, rbb_if, C_RBB_SCOPE, shared_msg_id_panel, C_RBB_AXIS);
    check_step(RUN_TEST_IDLE , 9, 4, "rbb_idle(4)");
    rbb_idle(0, "Nothing", clk, rbb_if, C_RBB_SCOPE, shared_msg_id_panel, C_RBB_AXIS);
    check_step(RUN_TEST_IDLE , 0, 0, "rbb_idle(0)");
  end procedure run;

end package body tb_rbb_tms_pkg;
