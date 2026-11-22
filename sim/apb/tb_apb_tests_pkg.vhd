-------------------------------------------------------------------------------
-- Title      : tb_apb_tests_pkg
-- Project    : asylum-verification-uvvm
-------------------------------------------------------------------------------
-- File       : tb_apb_tests_pkg.vhd
-- Author     : Mathieu Rosiere
-- Company    :
-- Created    : 2026-11-22
-- Platform   :
-- Standard   : VHDL'08
-------------------------------------------------------------------------------
-- Description:
--  Scenarios of tb_apb : names (valid items of TESTS_LIST) and dispatch
--  (run_test) to the package of each scenario (tb_apb_<name>_pkg).
-------------------------------------------------------------------------------
-- Copyright (c) 2026
-------------------------------------------------------------------------------
-- Revisions  :
-- Date        Version  Author   Description
-- 2026-11-22  1.0      mrosiere Created
-------------------------------------------------------------------------------

library ieee;
use     ieee.std_logic_1164.all;

library uvvm_util;
context uvvm_util.uvvm_util_context;

library asylum;
use     asylum.string_pkg.all;

library asylum_uvvm;
use     asylum_uvvm.apb_bfm_pkg.all;

use     work.tb_apb_bfm_pkg.all;

package tb_apb_tests_pkg is

  -- Names of the scenarios (valid items of TESTS_LIST)
  constant C_TESTS : string := "reset_values,write_read,back_to_back,wait_states,pslverr,timeout";

  -- Run the scenario name
  procedure run_test(
    constant name        : in    string;
    signal   clk         : in    std_logic;
    signal   apb_if      : inout t_apb_if;
    signal   wait_states : out   natural
    );

end package tb_apb_tests_pkg;

package body tb_apb_tests_pkg is

  procedure run_test(
    constant name        : in    string;
    signal   clk         : in    std_logic;
    signal   apb_if      : inout t_apb_if;
    signal   wait_states : out   natural
    ) is
  begin
    if    string_eq(name, "reset_values")
    then
      work.tb_apb_reset_values_pkg.run(clk, apb_if, wait_states);
    elsif string_eq(name, "write_read")
    then
      work.tb_apb_write_read_pkg.run  (clk, apb_if, wait_states);
    elsif string_eq(name, "back_to_back")
    then
      work.tb_apb_back_to_back_pkg.run(clk, apb_if, wait_states);
    elsif string_eq(name, "wait_states")
    then
      work.tb_apb_wait_states_pkg.run (clk, apb_if, wait_states);
    elsif string_eq(name, "pslverr")
    then
      work.tb_apb_pslverr_pkg.run     (clk, apb_if, wait_states);
    elsif string_eq(name, "timeout")
    then
      work.tb_apb_timeout_pkg.run     (clk, apb_if, wait_states);
    else
      alert(TB_ERROR, "Unknown test " & name, C_TB_SCOPE);
    end if;
  end procedure run_test;

end package body tb_apb_tests_pkg;
