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
--  BFM, each one followed by a check of the state of the TAP (Run-Test/Idle,
--  Test-Logic-Reset after jtag_trst), TCK cycles with a given TMS sequence.
--  Chain of TAPs (MODEL "chain") : TAPs of the chain, BFM configuration
--  with one TAP as target, check of the instruction of every TAP.
-------------------------------------------------------------------------------
-- Copyright (c) 2026
-------------------------------------------------------------------------------
-- Revisions  :
-- Date        Version  Author   Description
-- 2026-11-22  1.0      mrosiere Created
-- 2026-11-22  1.1      mrosiere tb_trst, tb_tms
-- 2026-11-23  1.2      mrosiere Chain of TAPs
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

  -- Chain of tb_jtag (MODEL "chain") : TDI -> TAP 0 -> TAP 1 -> TAP 2 -> TDO,
  -- an IR width, an IDCODE and a user data register width per TAP. The
  -- Capture-IR monitor of the target TAP checks C_CHAIN_MONITOR_TAP
  constant C_CHAIN_NB_TAP      : positive := 3;
  constant C_CHAIN_IR_WIDTH    : integer_vector(0 to C_CHAIN_NB_TAP-1) := (8, 5, 4);
  constant C_CHAIN_DR_WIDTH    : integer_vector(0 to C_CHAIN_NB_TAP-1) := (12, 33, 3);
  type     idcode_array_t is array (natural range <>) of std_logic_vector(32-1 downto 0);
  constant C_CHAIN_IDCODE      : idcode_array_t(0 to C_CHAIN_NB_TAP-1) := (x"1A2B3C4D", x"2C4E6A8B", x"3E5D7C9F");
  constant C_CHAIN_MONITOR_TAP : natural  := 1;

  -- Opcode of BYPASS (all ones)
  function ir_bypass(config : t_jtag_bfm_config) return natural;

  -- Configuration of the BFM with the TAP tap of the chain as target : head
  -- = the TAPs after it (TDO side), tail = the TAPs before it (TDI side)
  function chain_config(config : t_jtag_bfm_config; tap : natural) return t_jtag_bfm_config;

  -- Configuration of the BFM with the whole chain as one TAP (IR of
  -- C_CHAIN_IR_WIDTH bits per TAP, no head / tail bits)
  function chain_whole_config(config : t_jtag_bfm_config) return t_jtag_bfm_config;

  -- Value of the whole chain IR with opcode in every TAP (TAP 0 in the MSB)
  function chain_opcode(opcode : natural) return natural;

  -- Capture-IR value of the whole chain ("0...01" per TAP, TAP 0 in the MSB)
  function chain_ir_capture return std_logic_vector;

  -- Instruction of every TAP of the chain : opcode for the target, BYPASS
  -- (all ones) for the others
  procedure check_chain_ir(
    signal   tap_ir       : in    integer_vector;
    constant target       : in    natural;
    constant opcode       : in    natural;
    constant msg          : in    string
    );

  -- JTAG procedures through the BFM, then a check of the state of the TAP
  -- (Run-Test/Idle)
  procedure tb_reset(
    constant msg          : in    string;
    signal   jtag_if      : inout t_jtag_if;
    signal   tap_state    : in    tap_state_t;
    constant config       : in    t_jtag_bfm_config
    );

  -- TRST* pulse alone : Test-Logic-Reset (state unchanged without TRST*,
  -- config.trst_enable false)
  procedure tb_trst(
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

  -- One TCK cycle per value of tms (left to right), TDI = 0, timed as the
  -- BFM : moves the TAP outside the procedures of the BFM (no check)
  procedure tb_tms(
    constant tms          : in    std_logic_vector;
    signal   jtag_if      : inout t_jtag_if;
    constant config       : in    t_jtag_bfm_config
    );

end package tb_jtag_bfm_pkg;

package body tb_jtag_bfm_pkg is

  function ir_bypass(config : t_jtag_bfm_config) return natural is
  begin
    return 2**config.ir_width-1;
  end function ir_bypass;

  function chain_config(config : t_jtag_bfm_config; tap : natural) return t_jtag_bfm_config is
    variable v_config : t_jtag_bfm_config := config;
  begin
    v_config.ir_width := C_CHAIN_IR_WIDTH(tap);
    v_config.head_ir  := 0;
    v_config.tail_ir  := 0;
    for i in 0 to C_CHAIN_NB_TAP-1 loop
      if i > tap
      then
        v_config.head_ir := v_config.head_ir + C_CHAIN_IR_WIDTH(i);
      elsif i < tap
      then
        v_config.tail_ir := v_config.tail_ir + C_CHAIN_IR_WIDTH(i);
      end if;
    end loop;
    v_config.head_dr  := C_CHAIN_NB_TAP-1-tap;
    v_config.tail_dr  := tap;
    return v_config;
  end function chain_config;

  function chain_whole_config(config : t_jtag_bfm_config) return t_jtag_bfm_config is
    variable v_config : t_jtag_bfm_config := chain_config(config, 0);
  begin
    v_config.ir_width := v_config.ir_width + v_config.head_ir;
    v_config.head_ir  := 0;
    v_config.head_dr  := 0;
    return v_config;
  end function chain_whole_config;

  function chain_opcode(opcode : natural) return natural is
    variable v_opcode : natural := 0;
  begin
    for i in 0 to C_CHAIN_NB_TAP-1 loop
      v_opcode := v_opcode * 2**C_CHAIN_IR_WIDTH(i) + opcode;
    end loop;
    return v_opcode;
  end function chain_opcode;

  function chain_ir_capture return std_logic_vector is
    constant C_WIDTH : natural := chain_whole_config(C_JTAG_BFM_CONFIG_DEFAULT).ir_width;
  begin
    return std_logic_vector(to_unsigned(chain_opcode(1), C_WIDTH));
  end function chain_ir_capture;

  procedure check_chain_ir(
    signal   tap_ir       : in    integer_vector;
    constant target       : in    natural;
    constant opcode       : in    natural;
    constant msg          : in    string
    ) is
  begin
    for i in 0 to C_CHAIN_NB_TAP-1 loop
      if i = target
      then
        check_value(tap_ir(i), opcode, ERROR, "IR of TAP " & to_string(i) & " (target) after " & msg, C_TB_SCOPE);
      else
        check_value(tap_ir(i), 2**C_CHAIN_IR_WIDTH(i)-1, ERROR, "IR of TAP " & to_string(i) & " (BYPASS) after " & msg, C_TB_SCOPE);
      end if;
    end loop;
  end procedure check_chain_ir;

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

  procedure tb_trst(
    constant msg          : in    string;
    signal   jtag_if      : inout t_jtag_if;
    signal   tap_state    : in    tap_state_t;
    constant config       : in    t_jtag_bfm_config
    ) is
  begin
    jtag_trst    (msg          => msg,
                  jtag_if      => jtag_if,
                  scope        => C_TB_SCOPE,
                  config       => config);
    if config.trst_enable
    then
      check_value(tap_state = TEST_LOGIC_RESET, ERROR, "TAP in Test-Logic-Reset after " & msg, C_TB_SCOPE);
    end if;
  end procedure tb_trst;

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

  procedure tb_tms(
    constant tms          : in    std_logic_vector;
    signal   jtag_if      : inout t_jtag_if;
    constant config       : in    t_jtag_bfm_config
    ) is
  begin
    for i in tms'range loop
      jtag_if.tck <= '0';
      jtag_if.tms <= tms(i);
      jtag_if.tdi <= '0';
      wait for config.tck_period/2;
      jtag_if.tck <= '1';
      wait for config.tck_period/2;
    end loop;
  end procedure tb_tms;

end package body tb_jtag_bfm_pkg;
