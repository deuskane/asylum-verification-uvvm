-------------------------------------------------------------------------------
-- Title      : tb_jtag_ir_capture_error_pkg
-- Project    : asylum-verification-uvvm
-------------------------------------------------------------------------------
-- File       : tb_jtag_ir_capture_error_pkg.vhd
-- Author     : Mathieu Rosiere
-- Company    :
-- Created    : 2026-11-22
-- Platform   :
-- Standard   : VHDL'08
-------------------------------------------------------------------------------
-- Description:
--  Scenario ir_capture_error of tb_jtag : alerts of jtag_ir_capture_monitor
--  (instance of tb_jtag), expected and counted : the TAP model captures a
--  wrong value (MSB set, LSB "01" : jtag_write_ir does not see it), then
--  a correct IR scan, then an IR scan shorter than ir_width (after a
--  correct one : bits left from the previous scan would hide it). The
--  monitor alerts
--  with severity ERROR (concurrent, its level does not change with the
--  scenario) : each count is checked with TB_ERROR, so that a missing alert
--  fails. Needs IR_WIDTH >= 3.
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

package tb_jtag_ir_capture_error_pkg is

  -- Wrong Capture-IR value, IR scan too short : one alert each
  procedure run(
    signal   jtag_if       : inout t_jtag_if;
    signal   tap_state     : in    tap_state_t;
    signal   capture_err   : out   std_logic;
    constant config        : in    t_jtag_bfm_config
    );

end package tb_jtag_ir_capture_error_pkg;

package body tb_jtag_ir_capture_error_pkg is

  procedure run(
    signal   jtag_if       : inout t_jtag_if;
    signal   tap_state     : in    tap_state_t;
    signal   capture_err   : out   std_logic;
    constant config        : in    t_jtag_bfm_config
    ) is
    variable v_short       : t_jtag_bfm_config := config;
    variable v_errors      : natural;
  begin
    if config.ir_width < 3
    then
      alert(TB_ERROR, "ir_capture_error needs IR_WIDTH >= 3", C_TB_SCOPE);
    end if;
    tb_reset("Reset", jtag_if, tap_state, config);

    -- Capture-IR loads "10...01" : one alert of the monitor
    capture_err <= '1';
    increment_expected_alerts_and_stop_limit(ERROR, 1, "Wrong Capture-IR value", C_TB_SCOPE);
    v_errors := get_alert_counter(ERROR);
    tb_write_ir(C_IR_IDCODE, "Wrong Capture-IR value", jtag_if, tap_state, config);
    check_value(get_alert_counter(ERROR), v_errors+1, TB_ERROR, "One alert of the monitor on a wrong Capture-IR value", C_TB_SCOPE);
    capture_err <= '0';

    -- Correct value again : no alert
    tb_write_ir(C_IR_IDCODE, "IDCODE", jtag_if, tap_state, config);

    -- IR scan of ir_width-1 bits : the MSB is not shifted out, one alert
    v_short.ir_width := config.ir_width - 1;
    increment_expected_alerts_and_stop_limit(ERROR, 1, "IR scan shorter than ir_width", C_TB_SCOPE);
    v_errors := get_alert_counter(ERROR);
    tb_write_ir(C_IR_IDCODE, "IR scan of ir_width-1 bits", jtag_if, tap_state, v_short);
    check_value(get_alert_counter(ERROR), v_errors+1, TB_ERROR, "One alert of the monitor on an IR scan shorter than ir_width", C_TB_SCOPE);
  end procedure run;

end package body tb_jtag_ir_capture_error_pkg;
