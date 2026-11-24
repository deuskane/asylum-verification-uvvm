-------------------------------------------------------------------------------
-- Title      : tb_rbb_commands_pkg
-- Project    : asylum-verification-uvvm
-------------------------------------------------------------------------------
-- File       : tb_rbb_commands_pkg.vhd
-- Author     : Mathieu Rosiere
-- Company    :
-- Created    : 2026-11-24
-- Platform   :
-- Standard   : VHDL'08
-------------------------------------------------------------------------------
-- Description:
--  Scenario commands of tb_rbb : the command bytes of rbb_write_cmd,
--  rbb_reset_cmd and rbb_blink_cmd sent by rbb_command on the AXI-Stream,
--  checked on the outputs of the decoder : every value of TCK, TMS, TDI (TMS
--  and TDI changed while TCK is low only), every value of TRST, SRST, the LED
--  on and off, three commands in one call ; number of commands taken, no
--  answer.
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

package tb_rbb_commands_pkg is

  procedure run(
    signal   clk         : in    std_logic;
    signal   rbb_if      : inout t_rbb_if;
    signal   answers     : in    t_rbb_answers;
    signal   ctrl        : out   tb_ctrl_t;
    signal   obs         : in    tb_obs_t
    );

end package tb_rbb_commands_pkg;

package body tb_rbb_commands_pkg is

  procedure run(
    signal   clk         : in    std_logic;
    signal   rbb_if      : inout t_rbb_if;
    signal   answers     : in    t_rbb_answers;
    signal   ctrl        : out   tb_ctrl_t;
    signal   obs         : in    tb_obs_t
    ) is
    -- Values of TCK, TMS, TDI : TMS and TDI change while TCK is low only
    constant C_WRITES    : string := "0151373262040";
    constant C_ANSWERS   : natural := answers.cnt;
    variable v_pins      : std_logic_vector(3-1 downto 0);
    variable v_resets    : std_logic_vector(2-1 downto 0);
    variable v_led       : std_logic;
  begin
    -- Write commands
    for i in C_WRITES'range loop
      v_pins := std_logic_vector(to_unsigned(character'pos(C_WRITES(i)) - character'pos('0'), 3));
      rbb_command(rbb_write_cmd(v_pins(2), v_pins(1), v_pins(0)), "Write", clk, rbb_if, C_RBB_SCOPE, shared_msg_id_panel, C_RBB_AXIS);
      wait until falling_edge(clk);
      check_value(obs.pins, v_pins, ERROR, "TCK, TMS, TDI after rbb_write_cmd(" & to_string(v_pins(2)) & ", " & to_string(v_pins(1)) & ", " & to_string(v_pins(0)) & ")", C_RBB_SCOPE);
    end loop;

    -- Reset commands : 'u', 't', 's', 'r'
    for v in 3 downto 0 loop
      v_resets := std_logic_vector(to_unsigned(v, 2));
      rbb_command(rbb_reset_cmd(v_resets(1), v_resets(0)), "Reset", clk, rbb_if, C_RBB_SCOPE, shared_msg_id_panel, C_RBB_AXIS);
      wait until falling_edge(clk);
      check_value(obs.trst_b & obs.srst_b, not v_resets, ERROR, "TRST*, SRST* after rbb_reset_cmd(" & to_string(v_resets(1)) & ", " & to_string(v_resets(0)) & ")", C_RBB_SCOPE);
    end loop;

    -- Blink commands
    for i in 0 to 1 loop
      v_led := '1' when i = 0 else '0';
      rbb_command(rbb_blink_cmd(v_led), "Blink", clk, rbb_if, C_RBB_SCOPE, shared_msg_id_panel, C_RBB_AXIS);
      wait until falling_edge(clk);
      check_value(obs.blink, v_led, ERROR, "LED after rbb_blink_cmd(" & to_string(v_led) & ")", C_RBB_SCOPE);
    end loop;

    -- Three commands in one call
    rbb_command(rbb_blink_cmd('1') & rbb_write_cmd('0', '1', '1') & rbb_reset_cmd('0', '1'), "Three commands", clk, rbb_if, C_RBB_SCOPE, shared_msg_id_panel, C_RBB_AXIS);
    wait until falling_edge(clk);
    check_value(obs.blink & obs.pins & obs.trst_b & obs.srst_b, "101110", ERROR, "LED on, TCK, TMS, TDI 011, SRST after three commands in one call", C_RBB_SCOPE);

    check_value(obs.cmd_cnt, C_WRITES'length + 4 + 2 + 3, ERROR, "Commands taken by the decoder", C_RBB_SCOPE);
    check_value(answers.cnt, C_ANSWERS, ERROR, "No answer", C_RBB_SCOPE);
  end procedure run;

end package body tb_rbb_commands_pkg;
