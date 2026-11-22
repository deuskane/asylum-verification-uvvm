-------------------------------------------------------------------------------
-- Title      : tb_apb_write_read_pkg
-- Project    : asylum-verification-uvvm
-------------------------------------------------------------------------------
-- File       : tb_apb_write_read_pkg.vhd
-- Author     : Mathieu Rosiere
-- Company    :
-- Created    : 2026-11-22
-- Platform   :
-- Standard   : VHDL'08
-------------------------------------------------------------------------------
-- Description:
--  Scenario write_read of tb_apb : apb_write then apb_read / apb_check
--  of a pattern and of its complement (every data bit toggles), neighbour
--  address untouched, data narrower than pwdata (zero extended), don't care
--  bits of apb_check, a mismatch of apb_check raises one alert (alert_level
--  WARNING, counted : an ERROR of the counter check is never an expected
--  one).
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
use     asylum_uvvm.apb_bfm_pkg.all;

use     work.tb_apb_bfm_pkg.all;

package tb_apb_write_read_pkg is

  -- Write then read back, don't care bits and mismatch of apb_check
  procedure run(
    signal   clk         : in    std_logic;
    signal   apb_if      : inout t_apb_if;
    signal   wait_states : out   natural
    );

end package tb_apb_write_read_pkg;

package body tb_apb_write_read_pkg is

  procedure run(
    signal   clk         : in    std_logic;
    signal   apb_if      : inout t_apb_if;
    signal   wait_states : out   natural
    ) is
    constant C_DATA      : std_logic_vector(C_DATA_WIDTH-1 downto 0) := x"5A3C96E1";
    variable v_data      : std_logic_vector(C_DATA_WIDTH-1 downto 0);
    variable v_warnings  : natural;
  begin
    tb_write(16#10#, C_DATA    , "Pattern"           , clk, apb_if);
    tb_write(16#11#, not C_DATA, "Complement"        , clk, apb_if);
    tb_read (16#10#, v_data    , "Pattern"           , clk, apb_if);
    check_value(v_data, C_DATA, ERROR, "apb_read after apb_write", C_TB_SCOPE);
    tb_check(16#11#, not C_DATA, "Complement"        , clk, apb_if);
    tb_check(16#12#, mem_reset_value(16#12#), "Neighbour address untouched", clk, apb_if);

    -- Data narrower than pwdata : zero extended
    tb_write(16#13#, x"A5"      , "8-bit data"        , clk, apb_if);
    tb_check(16#13#, x"000000A5", "8-bit data, zero extended", clk, apb_if);

    -- Don't care bits of apb_check
    tb_check(16#10#, C_DATA(C_DATA_WIDTH-1 downto 8) & "--------", "Don't care on the 8 LSB", clk, apb_if);

    -- A mismatch of apb_check raises one alert
    increment_expected_alerts(WARNING, 1, "Mismatch of apb_check", C_TB_SCOPE);
    v_warnings := get_alert_counter(WARNING);
    tb_check(16#10#, not C_DATA, "Mismatch expected", clk, apb_if, C_APB_BFM_CONFIG_DEFAULT, WARNING);
    check_value(get_alert_counter(WARNING), v_warnings+1, ERROR, "One alert of apb_check on a mismatch", C_TB_SCOPE);
  end procedure run;

end package body tb_apb_write_read_pkg;
