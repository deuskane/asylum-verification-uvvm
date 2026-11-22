-------------------------------------------------------------------------------
-- Title      : tb_jtag_tests_pkg
-- Project    : asylum-verification-uvvm
-------------------------------------------------------------------------------
-- File       : tb_jtag_tests_pkg.vhd
-- Author     : Mathieu Rosiere
-- Company    :
-- Created    : 2026-11-22
-- Platform   :
-- Standard   : VHDL'08
-------------------------------------------------------------------------------
-- Description:
--  Scenarios of tb_jtag : names (valid items of TESTS_LIST) and dispatch
--  (run_test) to the package of each scenario (tb_jtag_<name>_pkg).
-------------------------------------------------------------------------------
-- Copyright (c) 2026
-------------------------------------------------------------------------------
-- Revisions  :
-- Date        Version  Author   Description
-- 2026-11-22  1.0      mrosiere Created
-- 2026-11-22  1.1      mrosiere trst, ir_capture, ir_capture_error
-------------------------------------------------------------------------------

library ieee;
use     ieee.std_logic_1164.all;

library uvvm_util;
context uvvm_util.uvvm_util_context;

library asylum;
use     asylum.string_pkg.all;

library asylum_uvvm;
use     asylum_uvvm.jtag_bfm_pkg.all;

use     work.tb_jtag_bfm_pkg.all;

package tb_jtag_tests_pkg is

  -- Names of the scenarios (valid items of TESTS_LIST)
  constant C_TESTS : string := "reset_trst,reset_tms,idcode,bypass,user_dr,idle,trst,ir_capture,ir_capture_error";

  -- Run the scenario name
  procedure run_test(
    constant name        : in    string;
    signal   jtag_if     : inout t_jtag_if;
    signal   tap_state   : in    tap_state_t;
    signal   trst_cnt    : in    natural;
    signal   tck_cnt     : in    natural;
    signal   capture_err : out   std_logic;
    constant config      : in    t_jtag_bfm_config;
    constant dr_width    : in    positive
    );

end package tb_jtag_tests_pkg;

package body tb_jtag_tests_pkg is

  procedure run_test(
    constant name        : in    string;
    signal   jtag_if     : inout t_jtag_if;
    signal   tap_state   : in    tap_state_t;
    signal   trst_cnt    : in    natural;
    signal   tck_cnt     : in    natural;
    signal   capture_err : out   std_logic;
    constant config      : in    t_jtag_bfm_config;
    constant dr_width    : in    positive
    ) is
  begin
    if    string_eq(name, "reset_trst")
    then
      work.tb_jtag_reset_trst_pkg.run(jtag_if, tap_state, trst_cnt, config, dr_width);
    elsif string_eq(name, "reset_tms")
    then
      work.tb_jtag_reset_tms_pkg.run (jtag_if, tap_state, trst_cnt, config, dr_width);
    elsif string_eq(name, "idcode")
    then
      work.tb_jtag_idcode_pkg.run    (jtag_if, tap_state, trst_cnt, config, dr_width);
    elsif string_eq(name, "bypass")
    then
      work.tb_jtag_bypass_pkg.run    (jtag_if, tap_state, trst_cnt, config, dr_width);
    elsif string_eq(name, "user_dr")
    then
      work.tb_jtag_user_dr_pkg.run   (jtag_if, tap_state, trst_cnt, config, dr_width);
    elsif string_eq(name, "idle")
    then
      work.tb_jtag_idle_pkg.run      (jtag_if, tap_state, trst_cnt, config, dr_width);
    elsif string_eq(name, "trst")
    then
      work.tb_jtag_trst_pkg.run      (jtag_if, tap_state, trst_cnt, tck_cnt, config);
    elsif string_eq(name, "ir_capture")
    then
      work.tb_jtag_ir_capture_pkg.run(jtag_if, tap_state, config);
    elsif string_eq(name, "ir_capture_error")
    then
      work.tb_jtag_ir_capture_error_pkg.run(jtag_if, tap_state, capture_err, config);
    else
      alert(TB_ERROR, "Unknown test " & name, C_TB_SCOPE);
    end if;
  end procedure run_test;

end package body tb_jtag_tests_pkg;
