-------------------------------------------------------------------------------
-- Title      : tb_rbb_tests_pkg
-- Project    : asylum-verification-uvvm
-------------------------------------------------------------------------------
-- File       : tb_rbb_tests_pkg.vhd
-- Author     : Mathieu Rosiere
-- Company    :
-- Created    : 2026-11-24
-- Platform   :
-- Standard   : VHDL'08
-------------------------------------------------------------------------------
-- Description:
--  Scenarios of tb_rbb : names (valid items of TESTS_LIST) and dispatch
--  (run_test) to the package of each scenario (tb_rbb_<name>_pkg).
-------------------------------------------------------------------------------
-- Copyright (c) 2026
-------------------------------------------------------------------------------
-- Revisions  :
-- Date        Version  Author   Description
-- 2026-11-24  1.0      mrosiere Created
-------------------------------------------------------------------------------

library ieee;
use     ieee.std_logic_1164.all;

library uvvm_util;
context uvvm_util.uvvm_util_context;

library asylum;
use     asylum.string_pkg.all;

library asylum_uvvm;
use     asylum_uvvm.rbb_bfm_pkg.all;

use     work.tb_rbb_bfm_pkg.all;

package tb_rbb_tests_pkg is

  -- Names of the scenarios (valid items of TESTS_LIST)
  constant C_TESTS       : string := "commands,tms,read,idcode,user_dr,uart,errors";

  -- Run the scenario name
  procedure run_test(
    constant name        : in    string;
    signal   clk         : in    std_logic;
    signal   rbb_if      : inout t_rbb_if;
    signal   answers     : in    t_rbb_answers;
    signal   ctrl        : out   tb_ctrl_t;
    signal   obs         : in    tb_obs_t
    );

end package tb_rbb_tests_pkg;

package body tb_rbb_tests_pkg is

  procedure run_test(
    constant name        : in    string;
    signal   clk         : in    std_logic;
    signal   rbb_if      : inout t_rbb_if;
    signal   answers     : in    t_rbb_answers;
    signal   ctrl        : out   tb_ctrl_t;
    signal   obs         : in    tb_obs_t
    ) is
  begin
    if    string_eq(name, "commands")
    then
      work.tb_rbb_commands_pkg.run(clk, rbb_if, answers, ctrl, obs);
    elsif string_eq(name, "tms")
    then
      work.tb_rbb_tms_pkg.run     (clk, rbb_if, answers, ctrl, obs);
    elsif string_eq(name, "read")
    then
      work.tb_rbb_read_pkg.run    (clk, rbb_if, answers, ctrl, obs);
    elsif string_eq(name, "idcode")
    then
      work.tb_rbb_idcode_pkg.run  (clk, rbb_if, answers, ctrl, obs);
    elsif string_eq(name, "user_dr")
    then
      work.tb_rbb_user_dr_pkg.run (clk, rbb_if, answers, ctrl, obs);
    elsif string_eq(name, "uart")
    then
      work.tb_rbb_uart_pkg.run    (clk, rbb_if, answers, ctrl, obs);
    elsif string_eq(name, "errors")
    then
      work.tb_rbb_errors_pkg.run  (clk, rbb_if, answers, ctrl, obs);
    else
      alert(TB_ERROR, "Unknown test " & name, C_RBB_SCOPE);
    end if;
  end procedure run_test;

end package body tb_rbb_tests_pkg;
