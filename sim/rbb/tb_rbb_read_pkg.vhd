-------------------------------------------------------------------------------
-- Title      : tb_rbb_read_pkg
-- Project    : asylum-verification-uvvm
-------------------------------------------------------------------------------
-- File       : tb_rbb_read_pkg.vhd
-- Author     : Mathieu Rosiere
-- Company    :
-- Created    : 2026-11-24
-- Platform   :
-- Standard   : VHDL'08
-------------------------------------------------------------------------------
-- Description:
--  Scenario read of tb_rbb : rbb_read in Run-Test/Idle (TDO not driven : the
--  pull-up, '1'), then in Shift-DR, IDCODE selected by the reset : one
--  rbb_read per bit and one TCK cycle (rbb_tms) to the next one, the IDCODE of
--  the TAP next to TDO read LSB first ; one answer per rbb_read.
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

package tb_rbb_read_pkg is

  procedure run(
    signal   clk         : in    std_logic;
    signal   rbb_if      : inout t_rbb_if;
    signal   answers     : in    t_rbb_answers;
    signal   ctrl        : out   tb_ctrl_t;
    signal   obs         : in    tb_obs_t
    );

end package tb_rbb_read_pkg;

package body tb_rbb_read_pkg is

  procedure run(
    signal   clk         : in    std_logic;
    signal   rbb_if      : inout t_rbb_if;
    signal   answers     : in    t_rbb_answers;
    signal   ctrl        : out   tb_ctrl_t;
    signal   obs         : in    tb_obs_t
    ) is
    constant C_WHOLE     : t_jtag_bfm_config := chain_whole_config(C_JTAG_BASE);
    constant C_TDO_TAP   : natural := C_CHAIN_NB_TAP-1;  -- The TAP next to TDO
    variable v_first     : natural;
    variable v_tdo       : std_logic;
    variable v_data      : std_logic_vector(32-1 downto 0);
  begin
    tb_reset("Reset", clk, rbb_if, obs, C_RBB_AXIS, C_WHOLE);
    v_first := answers.cnt;

    -- Run-Test/Idle : TDO not driven
    rbb_read(v_tdo, "Run-Test/Idle", clk, rbb_if, answers, C_RBB_SCOPE, shared_msg_id_panel, C_RBB_AXIS);
    check_value(v_tdo, '1', ERROR, "rbb_read in Run-Test/Idle : TDO not driven (pull-up)", C_RBB_SCOPE);

    -- Shift-DR : the IDCODE of the TAP next to TDO, LSB first
    rbb_tms("100", "Shift-DR", clk, rbb_if, C_RBB_SCOPE, shared_msg_id_panel, C_RBB_AXIS);
    for i in 0 to 32-1 loop
      rbb_read(v_tdo, "IDCODE bit " & to_string(i), clk, rbb_if, answers, C_RBB_SCOPE, shared_msg_id_panel, C_RBB_AXIS);
      v_data(i) := v_tdo;
      rbb_tms("0", "Next bit", clk, rbb_if, C_RBB_SCOPE, shared_msg_id_panel, C_RBB_AXIS);
    end loop;
    check_value(v_data, C_CHAIN_IDCODE(C_TDO_TAP), ERROR, "IDCODE of TAP " & to_string(C_TDO_TAP) & " read bit by bit with rbb_read", C_RBB_SCOPE);
    check_value(answers.cnt - v_first, 33, ERROR, "One answer per rbb_read", C_RBB_SCOPE);

    -- Exit1-DR, Update-DR, Run-Test/Idle
    rbb_tms("110", "Run-Test/Idle", clk, rbb_if, C_RBB_SCOPE, shared_msg_id_panel, C_RBB_AXIS);
    wait until falling_edge(clk);
    check_value(obs.tap_state = RUN_TEST_IDLE, ERROR, "TAP in Run-Test/Idle after the reads", C_RBB_SCOPE);
  end procedure run;

end package body tb_rbb_read_pkg;
