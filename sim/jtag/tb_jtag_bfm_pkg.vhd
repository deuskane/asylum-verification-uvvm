-------------------------------------------------------------------------------
-- Title      : tb_jtag_bfm_pkg
-- Project    : asylum-verification-uvvm
-------------------------------------------------------------------------------
-- File       : tb_jtag_bfm_pkg.vhd
-- Author     : Mathieu Rosiere
-- Company    :
-- Created    : 2026-11-22
-- Platform   :
-- Standard   : VHDL'08
-------------------------------------------------------------------------------
-- Description:
--  Constants and helpers shared by the scenarios of tb_jtag (test of
--  jtag_bfm_pkg against the TAP model tb_jtag_tap) : IDCODE and opcodes of
--  the TAP model, states of the TAP controller, JTAG procedures through the
--  BFM, each one followed by a check that the TAP is in Run-Test/Idle.
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

package tb_jtag_bfm_pkg is

  constant C_TB_SCOPE     : string  := "TB_JTAG";     -- Scope of the scenarios (C_SCOPE of uvvm_util is hidden by the C_SCOPE of the testbench)

  -- TAP model : IDCODE (bit 0 = 1, IEEE 1149.1) and opcodes, every other
  -- opcode (all ones included) selects BYPASS
  constant C_IDCODE       : std_logic_vector(32-1 downto 0) := x"5A7C3E1B";
  constant C_IR_IDCODE    : natural := 1;
  constant C_IR_USER      : natural := 2;
  constant C_IR_UNDECODED : natural := 3;

  -- States of the TAP controller (IEEE 1149.1)
  type tap_state_t is (TEST_LOGIC_RESET, RUN_TEST_IDLE,
                       SELECT_DR_SCAN, CAPTURE_DR, SHIFT_DR, EXIT1_DR, PAUSE_DR, EXIT2_DR, UPDATE_DR,
                       SELECT_IR_SCAN, CAPTURE_IR, SHIFT_IR, EXIT1_IR, PAUSE_IR, EXIT2_IR, UPDATE_IR);

  -- Opcode of BYPASS (all ones)
  function ir_bypass(config : t_jtag_bfm_config) return natural;

  -- JTAG procedures through the BFM, then a check of the state of the TAP
  -- (Run-Test/Idle)
  procedure tb_reset(
    constant msg          : in    string;
    signal   jtag_if      : inout t_jtag_if;
    signal   tap_state    : in    tap_state_t;
    constant config       : in    t_jtag_bfm_config
    );

  procedure tb_idle(
    constant num_cycles   : in    natural;
    constant msg          : in    string;
    signal   jtag_if      : inout t_jtag_if;
    signal   tap_state    : in    tap_state_t;
    constant config       : in    t_jtag_bfm_config
    );

  procedure tb_write_ir(
    constant opcode       : in    natural;
    constant msg          : in    string;
    signal   jtag_if      : inout t_jtag_if;
    signal   tap_state    : in    tap_state_t;
    constant config       : in    t_jtag_bfm_config
    );

  procedure tb_scan_dr(
    constant data         : in    std_logic_vector;
    variable data_out     : out   std_logic_vector;
    constant msg          : in    string;
    signal   jtag_if      : inout t_jtag_if;
    signal   tap_state    : in    tap_state_t;
    constant config       : in    t_jtag_bfm_config
    );

  procedure tb_check_dr(
    constant data         : in    std_logic_vector;
    constant data_exp     : in    std_logic_vector;
    constant msg          : in    string;
    signal   jtag_if      : inout t_jtag_if;
    signal   tap_state    : in    tap_state_t;
    constant config       : in    t_jtag_bfm_config;
    constant alert_level  : in    t_alert_level     := ERROR
    );

end package tb_jtag_bfm_pkg;

package body tb_jtag_bfm_pkg is

  function ir_bypass(config : t_jtag_bfm_config) return natural is
  begin
    return 2**config.ir_width-1;
  end function ir_bypass;

  procedure check_run_test_idle(
    constant msg          : in    string;
    signal   tap_state    : in    tap_state_t
    ) is
  begin
    check_value(tap_state = RUN_TEST_IDLE, ERROR, "TAP in Run-Test/Idle after " & msg, C_TB_SCOPE);
  end procedure check_run_test_idle;

  procedure tb_reset(
    constant msg          : in    string;
    signal   jtag_if      : inout t_jtag_if;
    signal   tap_state    : in    tap_state_t;
    constant config       : in    t_jtag_bfm_config
    ) is
  begin
    jtag_reset   (msg          => msg,
                  jtag_if      => jtag_if,
                  scope        => C_TB_SCOPE,
                  config       => config);
    check_run_test_idle(msg, tap_state);
  end procedure tb_reset;

  procedure tb_idle(
    constant num_cycles   : in    natural;
    constant msg          : in    string;
    signal   jtag_if      : inout t_jtag_if;
    signal   tap_state    : in    tap_state_t;
    constant config       : in    t_jtag_bfm_config
    ) is
  begin
    jtag_idle    (num_cycles   => num_cycles,
                  msg          => msg,
                  jtag_if      => jtag_if,
                  scope        => C_TB_SCOPE,
                  config       => config);
    check_run_test_idle(msg, tap_state);
  end procedure tb_idle;

  procedure tb_write_ir(
    constant opcode       : in    natural;
    constant msg          : in    string;
    signal   jtag_if      : inout t_jtag_if;
    signal   tap_state    : in    tap_state_t;
    constant config       : in    t_jtag_bfm_config
    ) is
  begin
    jtag_write_ir(ir_value     => std_logic_vector(to_unsigned(opcode, config.ir_width)),
                  msg          => msg,
                  jtag_if      => jtag_if,
                  scope        => C_TB_SCOPE,
                  config       => config);
    check_run_test_idle(msg, tap_state);
  end procedure tb_write_ir;

  procedure tb_scan_dr(
    constant data         : in    std_logic_vector;
    variable data_out     : out   std_logic_vector;
    constant msg          : in    string;
    signal   jtag_if      : inout t_jtag_if;
    signal   tap_state    : in    tap_state_t;
    constant config       : in    t_jtag_bfm_config
    ) is
  begin
    jtag_scan_dr (data_value   => data,
                  data_out     => data_out,
                  msg          => msg,
                  jtag_if      => jtag_if,
                  scope        => C_TB_SCOPE,
                  config       => config);
    check_run_test_idle(msg, tap_state);
  end procedure tb_scan_dr;

  procedure tb_check_dr(
    constant data         : in    std_logic_vector;
    constant data_exp     : in    std_logic_vector;
    constant msg          : in    string;
    signal   jtag_if      : inout t_jtag_if;
    signal   tap_state    : in    tap_state_t;
    constant config       : in    t_jtag_bfm_config;
    constant alert_level  : in    t_alert_level     := ERROR
    ) is
  begin
    jtag_check_dr(data_value   => data,
                  data_exp     => data_exp,
                  msg          => msg,
                  jtag_if      => jtag_if,
                  alert_level  => alert_level,
                  scope        => C_TB_SCOPE,
                  config       => config);
    check_run_test_idle(msg, tap_state);
  end procedure tb_check_dr;

end package body tb_jtag_bfm_pkg;
