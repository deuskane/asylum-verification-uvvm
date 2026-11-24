-------------------------------------------------------------------------------
-- Title      : tb_rbb_errors_pkg
-- Project    : asylum-verification-uvvm
-------------------------------------------------------------------------------
-- File       : tb_rbb_errors_pkg.vhd
-- Author     : Mathieu Rosiere
-- Company    :
-- Created    : 2026-11-24
-- Platform   :
-- Standard   : VHDL'08
-------------------------------------------------------------------------------
-- Description:
--  Scenario errors of tb_rbb : alerts of the BFM. A mismatch of
--  rbb_check_dr (alert_level WARNING) and its don't care bits ; 'R' not
--  answered by the decoder (mute) : alert of rbb_read (TDO 'X') and of
--  rbb_scan_dr (data 'X'), then the answers again ; a command not taken
--  (s_axis_tready held low) : alert of rbb_command ; head_ir one bit too
--  large : alert of the Capture-IR check of rbb_write_ir. The expected
--  alerts of severity ERROR are counted with TB_ERROR checks.
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

package tb_rbb_errors_pkg is

  procedure run(
    signal   clk         : in    std_logic;
    signal   rbb_if      : inout t_rbb_if;
    signal   answers     : in    t_rbb_answers;
    signal   ctrl        : out   tb_ctrl_t;
    signal   obs         : in    tb_obs_t
    );

end package tb_rbb_errors_pkg;

package body tb_rbb_errors_pkg is

  procedure run(
    signal   clk         : in    std_logic;
    signal   rbb_if      : inout t_rbb_if;
    signal   answers     : in    t_rbb_answers;
    signal   ctrl        : out   tb_ctrl_t;
    signal   obs         : in    tb_obs_t
    ) is
    constant C_WHOLE     : t_jtag_bfm_config := chain_whole_config(C_JTAG_BASE);
    constant C_IDCODES   : std_logic_vector(32*C_CHAIN_NB_TAP-1 downto 0) := chain_idcodes;
    constant C_ZERO      : std_logic_vector(32*C_CHAIN_NB_TAP-1 downto 0) := (others => '0');
    constant C_UNKNOWN   : std_logic_vector(32*C_CHAIN_NB_TAP-1 downto 0) := (others => 'X');
    variable v_config    : t_jtag_bfm_config;
    variable v_tdo       : std_logic;
    variable v_data      : std_logic_vector(32*C_CHAIN_NB_TAP-1 downto 0);
    variable v_alerts    : natural;
    variable v_cmd       : natural;
  begin
    tb_reset("Reset", clk, rbb_if, obs, C_RBB_AXIS, C_WHOLE);

    -- Mismatch of rbb_check_dr : one alert ; don't care bits
    increment_expected_alerts(WARNING, 1, "Mismatch of rbb_check_dr", C_RBB_SCOPE);
    v_alerts := get_alert_counter(WARNING);
    tb_check_dr(C_ZERO, not C_IDCODES, "Mismatch expected", clk, rbb_if, answers, obs, C_RBB_AXIS, C_WHOLE, WARNING);
    check_value(get_alert_counter(WARNING), v_alerts+1, ERROR, "One alert of rbb_check_dr on a mismatch", C_RBB_SCOPE);
    tb_check_dr(C_ZERO, C_IDCODES(C_IDCODES'high downto 12) & "------------", "Don't care on the 12 LSB", clk, rbb_if, answers, obs, C_RBB_AXIS, C_WHOLE);

    -- 'R' not answered
    ctrl <= (uart => false, mute => '1', stall => '0');
    increment_expected_alerts_and_stop_limit(ERROR, 1, "rbb_read without answer", C_RBB_SCOPE);
    v_alerts := get_alert_counter(ERROR);
    rbb_read(v_tdo, "No answer expected", clk, rbb_if, answers, C_RBB_SCOPE, shared_msg_id_panel, C_RBB_AXIS);
    check_value(get_alert_counter(ERROR), v_alerts+1, TB_ERROR, "One alert of rbb_read without answer", C_RBB_SCOPE);
    check_value(v_tdo = 'X', TB_ERROR, "rbb_read without answer : TDO unknown ('X')", C_RBB_SCOPE);

    increment_expected_alerts_and_stop_limit(ERROR, 1, "rbb_scan_dr without answer", C_RBB_SCOPE);
    v_alerts := get_alert_counter(ERROR);
    rbb_scan_dr(C_ZERO, v_data, "No answer expected", clk, rbb_if, answers, C_RBB_SCOPE, shared_msg_id_panel, C_RBB_AXIS, C_WHOLE);
    check_value(get_alert_counter(ERROR), v_alerts+1, TB_ERROR, "One alert of rbb_scan_dr without answer", C_RBB_SCOPE);
    check_value(v_data = C_UNKNOWN, TB_ERROR, "rbb_scan_dr without answer : data unknown ('X')", C_RBB_SCOPE);

    ctrl <= C_TB_CTRL_IDLE;
    tb_check_dr(C_ZERO, C_IDCODES, "Answers again", clk, rbb_if, answers, obs, C_RBB_AXIS, C_WHOLE);

    -- Command not taken
    ctrl <= (uart => false, mute => '0', stall => '1');
    increment_expected_alerts_and_stop_limit(ERROR, 1, "rbb_command not taken", C_RBB_SCOPE);
    v_alerts := get_alert_counter(ERROR);
    v_cmd    := obs.cmd_cnt;
    rbb_command(rbb_blink_cmd('1'), "Not taken expected", clk, rbb_if, C_RBB_SCOPE, shared_msg_id_panel, C_RBB_AXIS);
    check_value(get_alert_counter(ERROR), v_alerts+1, TB_ERROR, "One alert of rbb_command when tready stays low", C_RBB_SCOPE);
    ctrl <= C_TB_CTRL_IDLE;
    wait until falling_edge(clk);
    check_value(obs.cmd_cnt, v_cmd, ERROR, "Command not taken while tready is low, not offered after the alert", C_RBB_SCOPE);

    -- Capture-IR of the target not found : head_ir one bit too large
    v_config         := chain_config(C_JTAG_BASE, 1);
    v_config.head_ir := v_config.head_ir + 1;
    increment_expected_alerts_and_stop_limit(ERROR, 1, "head_ir one bit too large", C_RBB_SCOPE);
    v_alerts := get_alert_counter(ERROR);
    rbb_write_ir(std_logic_vector(to_unsigned(C_IR_IDCODE, v_config.ir_width)), "Wrong head_ir", clk, rbb_if, answers, C_RBB_SCOPE, shared_msg_id_panel, C_RBB_AXIS, v_config);
    check_value(get_alert_counter(ERROR), v_alerts+1, TB_ERROR, "One alert of rbb_write_ir on the Capture-IR value", C_RBB_SCOPE);
  end procedure run;

end package body tb_rbb_errors_pkg;
