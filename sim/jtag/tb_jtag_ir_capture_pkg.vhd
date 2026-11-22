-------------------------------------------------------------------------------
-- Title      : tb_jtag_ir_capture_pkg
-- Project    : asylum-verification-uvvm
-------------------------------------------------------------------------------
-- File       : tb_jtag_ir_capture_pkg.vhd
-- Author     : Mathieu Rosiere
-- Company    :
-- Created    : 2026-11-22
-- Platform   :
-- Standard   : VHDL'08
-------------------------------------------------------------------------------
-- Description:
--  Scenario ir_capture of tb_jtag : jtag_ir_capture_monitor (instance of
--  tb_jtag) checks every IR scan (one => OK each) : IR scans of ir_width
--  bits, a TRST* pulse in Shift-IR (the monitor restarts from
--  Test-Logic-Reset), an IR scan longer than ir_width (first ir_width bits
--  checked).
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

package tb_jtag_ir_capture_pkg is

  -- IR scans checked by the Capture-IR monitor, no alert
  procedure run(
    signal   jtag_if     : inout t_jtag_if;
    signal   tap_state   : in    tap_state_t;
    constant config      : in    t_jtag_bfm_config
    );

end package tb_jtag_ir_capture_pkg;

package body tb_jtag_ir_capture_pkg is

  procedure run(
    signal   jtag_if     : inout t_jtag_if;
    signal   tap_state   : in    tap_state_t;
    constant config      : in    t_jtag_bfm_config
    ) is
    variable v_config    : t_jtag_bfm_config := config;
    variable v_long      : t_jtag_bfm_config := config;
  begin
    v_config.trst_enable := true;
    tb_reset("Reset", jtag_if, tap_state, v_config);
    tb_write_ir(C_IR_USER  , "USER"  , jtag_if, tap_state, v_config);
    tb_write_ir(C_IR_IDCODE, "IDCODE", jtag_if, tap_state, v_config);

    -- TRST* in Shift-IR, after 2 bits : the monitor restarts from
    -- Test-Logic-Reset and checks the next IR scan
    tb_tms("1100" & "00", jtag_if, v_config);
    check_value(tap_state = SHIFT_IR, ERROR, "TAP in Shift-IR", C_TB_SCOPE);
    tb_trst("TRST pulse in Shift-IR", jtag_if, tap_state, v_config);
    tb_idle(1, "Run-Test/Idle", jtag_if, tap_state, v_config);
    tb_write_ir(C_IR_USER, "USER after the TRST pulse", jtag_if, tap_state, v_config);

    -- IR scan of ir_width+3 bits : the first ir_width bits are checked
    v_long.ir_width := config.ir_width + 3;
    tb_write_ir(C_IR_IDCODE, "IR scan of ir_width+3 bits", jtag_if, tap_state, v_long);
  end procedure run;

end package body tb_jtag_ir_capture_pkg;
