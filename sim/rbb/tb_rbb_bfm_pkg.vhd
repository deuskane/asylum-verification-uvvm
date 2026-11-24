-------------------------------------------------------------------------------
-- Title      : tb_rbb_bfm_pkg
-- Project    : asylum-verification-uvvm
-------------------------------------------------------------------------------
-- File       : tb_rbb_bfm_pkg.vhd
-- Author     : Mathieu Rosiere
-- Company    :
-- Created    : 2026-11-24
-- Platform   :
-- Standard   : VHDL'08
-------------------------------------------------------------------------------
-- Description:
--  Constants, records and helpers shared by the scenarios of tb_rbb (test
--  of rbb_bfm_pkg : remote_bitbang decoder tb_rbb_decoder, chain of the TAP
--  models of tb_jtag, constants of tb_jtag_bfm_pkg) : BFM configurations
--  (AXI-Stream, UART), records between the scenarios and the testbench
--  (tb_ctrl_t : stimuli, tb_obs_t : outputs of the decoder, of the TAPs and
--  of the monitors), scans through the BFM followed by a check of the state
--  of the TAPs (Run-Test/Idle).
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

package tb_rbb_bfm_pkg is

  constant C_RBB_SCOPE    : string   := "TB_RBB";        -- Scope of the scenarios (C_SCOPE of uvvm_util is hidden by the C_SCOPE of the testbench)

  constant C_CLK_PERIOD   : time     := 10 ns;

  -- BFM : commands on the AXI-Stream (C_RBB_AXIS) or as UART frames of 16
  -- clock cycles per bit (C_RBB_UART), answers missing after C_TIMEOUT
  constant C_TIMEOUT      : time     := 20 us;
  constant C_UART_BIT     : time     := 16*C_CLK_PERIOD;
  constant C_RBB_AXIS     : t_rbb_bfm_config;
  constant C_RBB_UART     : t_rbb_bfm_config;

  -- Chain of TAPs of tb_jtag_bfm_pkg, without TRST* in the reset of the BFM
  constant C_JTAG_BASE    : t_jtag_bfm_config;

  -- Stimuli of the scenarios, besides the BFM
  type tb_ctrl_t is record
    uart            : boolean;                                      -- Commands and answers as UART frames
    mute            : std_logic;                                    -- The decoder does not answer 'R'
    stall           : std_logic;                                    -- The decoder holds s_axis_tready low
  end record tb_ctrl_t;

  constant C_TB_CTRL_IDLE : tb_ctrl_t := (uart  => false,
                                          mute  => '0',
                                          stall => '0');

  -- Outputs of the decoder, of the TAPs and of the monitors
  type tb_obs_t is record
    pins            : std_logic_vector(3-1 downto 0);               -- TCK, TMS, TDI
    trst_b          : std_logic;
    srst_b          : std_logic;
    blink           : std_logic;
    cmd_cnt         : natural;                                      -- Commands taken by the decoder since the reset
    tck_cnt         : natural;                                      -- Rising edges of TCK since the reset
    trst_cnt        : natural;                                      -- TRST* pulses since the reset
    tap_state       : tap_state_t;                                  -- State of TAP 0
    tap_ir          : integer_vector(0 to C_CHAIN_NB_TAP-1);        -- Instruction of each TAP
  end record tb_obs_t;

  -- IDCODE of every TAP after the reset, TAP 0 (TDI side) in the MSB
  function chain_idcodes return std_logic_vector;

  -- JTAG procedures through the BFM, then a check of the state of the TAPs
  -- (Run-Test/Idle)
  procedure tb_reset(
    constant msg          : in    string;
    signal   clk          : in    std_logic;
    signal   rbb_if       : inout t_rbb_if;
    signal   obs          : in    tb_obs_t;
    constant config       : in    t_rbb_bfm_config;
    constant jtag_config  : in    t_jtag_bfm_config
    );

  procedure tb_write_ir(
    constant opcode       : in    natural;
    constant msg          : in    string;
    signal   clk          : in    std_logic;
    signal   rbb_if       : inout t_rbb_if;
    signal   answers      : in    t_rbb_answers;
    signal   obs          : in    tb_obs_t;
    constant config       : in    t_rbb_bfm_config;
    constant jtag_config  : in    t_jtag_bfm_config
    );

  procedure tb_scan_dr(
    constant data         : in    std_logic_vector;
    variable data_out     : out   std_logic_vector;
    constant msg          : in    string;
    signal   clk          : in    std_logic;
    signal   rbb_if       : inout t_rbb_if;
    signal   answers      : in    t_rbb_answers;
    signal   obs          : in    tb_obs_t;
    constant config       : in    t_rbb_bfm_config;
    constant jtag_config  : in    t_jtag_bfm_config
    );

  procedure tb_check_dr(
    constant data         : in    std_logic_vector;
    constant data_exp     : in    std_logic_vector;
    constant msg          : in    string;
    signal   clk          : in    std_logic;
    signal   rbb_if       : inout t_rbb_if;
    signal   answers      : in    t_rbb_answers;
    signal   obs          : in    tb_obs_t;
    constant config       : in    t_rbb_bfm_config;
    constant jtag_config  : in    t_jtag_bfm_config;
    constant alert_level  : in    t_alert_level     := ERROR
    );

end package tb_rbb_bfm_pkg;

package body tb_rbb_bfm_pkg is

  function rbb_config(uart : boolean) return t_rbb_bfm_config is
    variable v_config : t_rbb_bfm_config := C_RBB_BFM_CONFIG_DEFAULT;
  begin
    v_config.uart                 := uart;
    v_config.uart_config.bit_time := C_UART_BIT;
    v_config.timeout              := C_TIMEOUT;
    return v_config;
  end function rbb_config;

  function jtag_base return t_jtag_bfm_config is
    variable v_config : t_jtag_bfm_config := C_JTAG_BFM_CONFIG_DEFAULT;
  begin
    v_config.trst_enable := false;
    return v_config;
  end function jtag_base;

  constant C_RBB_AXIS     : t_rbb_bfm_config  := rbb_config(false);
  constant C_RBB_UART     : t_rbb_bfm_config  := rbb_config(true);
  constant C_JTAG_BASE    : t_jtag_bfm_config := jtag_base;

  function chain_idcodes return std_logic_vector is
    variable v_idcodes : std_logic_vector(32*C_CHAIN_NB_TAP-1 downto 0);
  begin
    for tap in 0 to C_CHAIN_NB_TAP-1 loop
      v_idcodes(32*(C_CHAIN_NB_TAP-tap)-1 downto 32*(C_CHAIN_NB_TAP-1-tap)) := C_CHAIN_IDCODE(tap);
    end loop;
    return v_idcodes;
  end function chain_idcodes;

  procedure check_run_test_idle(
    constant msg          : in    string;
    signal   clk          : in    std_logic;
    signal   obs          : in    tb_obs_t
    ) is
  begin
    wait until falling_edge(clk);
    check_value(obs.tap_state = RUN_TEST_IDLE, ERROR, "TAP in Run-Test/Idle after " & msg, C_RBB_SCOPE);
  end procedure check_run_test_idle;

  procedure tb_reset(
    constant msg          : in    string;
    signal   clk          : in    std_logic;
    signal   rbb_if       : inout t_rbb_if;
    signal   obs          : in    tb_obs_t;
    constant config       : in    t_rbb_bfm_config;
    constant jtag_config  : in    t_jtag_bfm_config
    ) is
  begin
    rbb_reset    (msg          => msg,
                  clk          => clk,
                  rbb_if       => rbb_if,
                  scope        => C_RBB_SCOPE,
                  config       => config,
                  jtag_config  => jtag_config);
    check_run_test_idle(msg, clk, obs);
  end procedure tb_reset;

  procedure tb_write_ir(
    constant opcode       : in    natural;
    constant msg          : in    string;
    signal   clk          : in    std_logic;
    signal   rbb_if       : inout t_rbb_if;
    signal   answers      : in    t_rbb_answers;
    signal   obs          : in    tb_obs_t;
    constant config       : in    t_rbb_bfm_config;
    constant jtag_config  : in    t_jtag_bfm_config
    ) is
  begin
    rbb_write_ir (ir_value     => std_logic_vector(to_unsigned(opcode, jtag_config.ir_width)),
                  msg          => msg,
                  clk          => clk,
                  rbb_if       => rbb_if,
                  answers      => answers,
                  scope        => C_RBB_SCOPE,
                  config       => config,
                  jtag_config  => jtag_config);
    check_run_test_idle(msg, clk, obs);
  end procedure tb_write_ir;

  procedure tb_scan_dr(
    constant data         : in    std_logic_vector;
    variable data_out     : out   std_logic_vector;
    constant msg          : in    string;
    signal   clk          : in    std_logic;
    signal   rbb_if       : inout t_rbb_if;
    signal   answers      : in    t_rbb_answers;
    signal   obs          : in    tb_obs_t;
    constant config       : in    t_rbb_bfm_config;
    constant jtag_config  : in    t_jtag_bfm_config
    ) is
  begin
    rbb_scan_dr  (data_value   => data,
                  data_out     => data_out,
                  msg          => msg,
                  clk          => clk,
                  rbb_if       => rbb_if,
                  answers      => answers,
                  scope        => C_RBB_SCOPE,
                  config       => config,
                  jtag_config  => jtag_config);
    check_run_test_idle(msg, clk, obs);
  end procedure tb_scan_dr;

  procedure tb_check_dr(
    constant data         : in    std_logic_vector;
    constant data_exp     : in    std_logic_vector;
    constant msg          : in    string;
    signal   clk          : in    std_logic;
    signal   rbb_if       : inout t_rbb_if;
    signal   answers      : in    t_rbb_answers;
    signal   obs          : in    tb_obs_t;
    constant config       : in    t_rbb_bfm_config;
    constant jtag_config  : in    t_jtag_bfm_config;
    constant alert_level  : in    t_alert_level     := ERROR
    ) is
  begin
    rbb_check_dr (data_value   => data,
                  data_exp     => data_exp,
                  msg          => msg,
                  clk          => clk,
                  rbb_if       => rbb_if,
                  answers      => answers,
                  alert_level  => alert_level,
                  scope        => C_RBB_SCOPE,
                  config       => config,
                  jtag_config  => jtag_config);
    check_run_test_idle(msg, clk, obs);
  end procedure tb_check_dr;

end package body tb_rbb_bfm_pkg;
