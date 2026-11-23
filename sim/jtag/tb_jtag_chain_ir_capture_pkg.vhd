-------------------------------------------------------------------------------
-- Title      : tb_jtag_chain_ir_capture_pkg
-- Project    : asylum-verification-uvvm
-------------------------------------------------------------------------------
-- File       : tb_jtag_chain_ir_capture_pkg.vhd
-- Author     : Mathieu Rosiere
-- Company    :
-- Created    : 2026-11-23
-- Platform   :
-- Standard   : VHDL'08
-------------------------------------------------------------------------------
-- Description:
--  Scenario chain_ir_capture of tb_jtag (MODEL "chain") : alerts of the two
--  Capture-IR monitors of the chain (instances of tb_jtag), expected and
--  counted : the whole chain monitor checks every TAP, the target monitor
--  only TAP C_CHAIN_MONITOR_TAP, at its place (config.head_ir). A wrong
--  Capture-IR value of that TAP : one alert of each monitor ; of another TAP :
--  one alert of the whole chain monitor only ; a correct scan between two
--  wrong ones. Last, head_ir one bit too large (tail_ir one bit smaller, same
--  scan length) : jtag_write_ir checks the LSB "01" at the wrong place, one
--  alert. The alerts have severity ERROR : each count is checked with
--  TB_ERROR, so that a missing alert fails.
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

package tb_jtag_chain_ir_capture_pkg is

  -- Wrong Capture-IR value of each TAP, wrong head_ir : alerts counted
  procedure run(
    signal   jtag_if     : inout t_jtag_if;
    signal   tap_state   : in    tap_state_t;
    signal   capture_err : out   std_logic_vector;
    constant config      : in    t_jtag_bfm_config
    );

end package tb_jtag_chain_ir_capture_pkg;

package body tb_jtag_chain_ir_capture_pkg is

  procedure run(
    signal   jtag_if     : inout t_jtag_if;
    signal   tap_state   : in    tap_state_t;
    signal   capture_err : out   std_logic_vector;
    constant config      : in    t_jtag_bfm_config
    ) is
    constant C_TAP       : natural := C_CHAIN_MONITOR_TAP;
    constant C_CONFIG    : t_jtag_bfm_config := chain_config(config, C_TAP);
    variable v_wrong     : t_jtag_bfm_config := C_CONFIG;
    variable v_errors    : natural;
    variable v_nb        : natural;
  begin
    tb_reset("Reset", jtag_if, tap_state, C_CONFIG);

    -- Wrong value of each TAP, then a correct scan
    for tap in 0 to C_CHAIN_NB_TAP-1 loop
      v_nb := 2 when tap = C_TAP else 1;
      capture_err(tap) <= '1';
      increment_expected_alerts_and_stop_limit(ERROR, v_nb, "Wrong Capture-IR value of TAP " & to_string(tap), C_TB_SCOPE);
      v_errors := get_alert_counter(ERROR);
      tb_write_ir(C_IR_IDCODE, "Wrong Capture-IR value of TAP " & to_string(tap), jtag_if, tap_state, C_CONFIG);
      check_value(get_alert_counter(ERROR), v_errors+v_nb, TB_ERROR, "Alerts of the monitors on a wrong Capture-IR value of TAP " & to_string(tap), C_TB_SCOPE);
      capture_err(tap) <= '0';
      tb_write_ir(C_IR_IDCODE, "Correct Capture-IR value", jtag_if, tap_state, C_CONFIG);
    end loop;

    -- head_ir one bit too large : one alert of jtag_write_ir
    v_wrong.head_ir := C_CONFIG.head_ir + 1;
    v_wrong.tail_ir := C_CONFIG.tail_ir - 1;
    increment_expected_alerts_and_stop_limit(ERROR, 1, "head_ir one bit too large", C_TB_SCOPE);
    v_errors := get_alert_counter(ERROR);
    tb_write_ir(C_IR_IDCODE, "head_ir one bit too large", jtag_if, tap_state, v_wrong);
    check_value(get_alert_counter(ERROR), v_errors+1, TB_ERROR, "One alert of jtag_write_ir on a wrong head_ir", C_TB_SCOPE);
  end procedure run;

end package body tb_jtag_chain_ir_capture_pkg;
