-------------------------------------------------------------------------------
-- Title      : tb_rbb_uart_pkg
-- Project    : asylum-verification-uvvm
-------------------------------------------------------------------------------
-- File       : tb_rbb_uart_pkg.vhd
-- Author     : Mathieu Rosiere
-- Company    :
-- Created    : 2026-11-24
-- Platform   :
-- Standard   : VHDL'08
-------------------------------------------------------------------------------
-- Description:
--  Scenario uart of tb_rbb : the commands as UART frames on rbb_if.tx (16
--  clock cycles per bit), the answers as UART frames received by
--  rbb_uart_monitor : reset of the TAPs, IDCODE of every TAP, user data
--  register of TAP 1 (head / tail bits) written and read back, rbb_read in
--  Run-Test/Idle, then TRST, SRST and the LED.
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

package tb_rbb_uart_pkg is

  procedure run(
    signal   clk         : in    std_logic;
    signal   rbb_if      : inout t_rbb_if;
    signal   answers     : in    t_rbb_answers;
    signal   ctrl        : out   tb_ctrl_t;
    signal   obs         : in    tb_obs_t
    );

end package tb_rbb_uart_pkg;

package body tb_rbb_uart_pkg is

  procedure run(
    signal   clk         : in    std_logic;
    signal   rbb_if      : inout t_rbb_if;
    signal   answers     : in    t_rbb_answers;
    signal   ctrl        : out   tb_ctrl_t;
    signal   obs         : in    tb_obs_t
    ) is
    constant C_TAP       : natural := 1;
    constant C_WHOLE     : t_jtag_bfm_config := chain_whole_config(C_JTAG_BASE);
    constant C_CONFIG    : t_jtag_bfm_config := chain_config(C_JTAG_BASE, C_TAP);
    constant C_ZERO      : std_logic_vector(32*C_CHAIN_NB_TAP-1 downto 0) := (others => '0');
    constant C_DATA      : std_logic_vector(C_CHAIN_DR_WIDTH(C_TAP)-1 downto 0) := std_logic_vector(to_unsigned(16#5A3C_96E1#, C_CHAIN_DR_WIDTH(C_TAP)));
    variable v_tdo       : std_logic;
  begin
    ctrl <= (uart => true, mute => '0', stall => '0');
    wait for 2*C_UART_BIT;

    tb_reset("Reset through the UART", clk, rbb_if, obs, C_RBB_UART, C_WHOLE);
    tb_check_dr(C_ZERO, chain_idcodes, "IDCODE of every TAP through the UART", clk, rbb_if, answers, obs, C_RBB_UART, C_WHOLE);

    tb_write_ir(C_IR_USER, "USER of TAP " & to_string(C_TAP), clk, rbb_if, answers, obs, C_RBB_UART, C_CONFIG);
    check_chain_ir(obs.tap_ir, C_TAP, C_IR_USER, "USER of TAP " & to_string(C_TAP) & " through the UART");
    tb_check_dr(C_DATA, C_ZERO(C_DATA'range), "Power-on value of TAP " & to_string(C_TAP) & " through the UART", clk, rbb_if, answers, obs, C_RBB_UART, C_CONFIG);
    tb_check_dr(not C_DATA, C_DATA, "Value written through the UART", clk, rbb_if, answers, obs, C_RBB_UART, C_CONFIG);

    rbb_read(v_tdo, "Run-Test/Idle", clk, rbb_if, answers, C_RBB_SCOPE, shared_msg_id_panel, C_RBB_UART);
    check_value(v_tdo, '1', ERROR, "rbb_read through the UART in Run-Test/Idle : TDO not driven (pull-up)", C_RBB_SCOPE);

    rbb_command(rbb_reset_cmd('1', '1') & rbb_blink_cmd('1'), "TRST, SRST, LED on", clk, rbb_if, C_RBB_SCOPE, shared_msg_id_panel, C_RBB_UART);
    wait until falling_edge(clk);
    check_value(std_logic_vector'(obs.trst_b & obs.srst_b & obs.blink), "001", ERROR, "TRST*, SRST* asserted, LED on through the UART", C_RBB_SCOPE);
    rbb_command(rbb_reset_cmd('0', '0') & rbb_blink_cmd('0'), "Released, LED off", clk, rbb_if, C_RBB_SCOPE, shared_msg_id_panel, C_RBB_UART);
    wait until falling_edge(clk);
    check_value(std_logic_vector'(obs.trst_b & obs.srst_b & obs.blink), "110", ERROR, "TRST*, SRST* released, LED off through the UART", C_RBB_SCOPE);
  end procedure run;

end package body tb_rbb_uart_pkg;
