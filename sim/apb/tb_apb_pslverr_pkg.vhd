-------------------------------------------------------------------------------
-- Title      : tb_apb_pslverr_pkg
-- Project    : asylum-verification-uvvm
-------------------------------------------------------------------------------
-- File       : tb_apb_pslverr_pkg.vhd
-- Author     : Mathieu Rosiere
-- Company    :
-- Created    : 2026-11-22
-- Platform   :
-- Standard   : VHDL'08
-------------------------------------------------------------------------------
-- Description:
--  Scenario pslverr of tb_apb : pslverr of the slave at C_ERR_ADDR,
--  with config.pslverr_severity = WARNING (alerts counted : an ERROR of the
--  counter checks is never an expected one) : expected
--  (config.expected_pslverr = '1'), no alert ; not expected, one alert per
--  apb_write / apb_read ; expected but missing, one alert.
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

package tb_apb_pslverr_pkg is

  -- pslverr expected (no alert), not expected and missing (one alert each)
  procedure run(
    signal   clk         : in    std_logic;
    signal   apb_if      : inout t_apb_if;
    signal   wait_states : out   natural
    );

end package tb_apb_pslverr_pkg;

package body tb_apb_pslverr_pkg is

  procedure run(
    signal   clk         : in    std_logic;
    signal   apb_if      : inout t_apb_if;
    signal   wait_states : out   natural
    ) is
    variable v_config    : t_apb_bfm_config := C_APB_BFM_CONFIG_DEFAULT;
    variable v_data      : std_logic_vector(C_DATA_WIDTH-1 downto 0);
    variable v_warnings  : natural;
  begin
    v_config.pslverr_severity := WARNING;
    v_warnings := get_alert_counter(WARNING);

    -- pslverr expected : no alert
    v_config.expected_pslverr := '1';
    tb_write(C_ERR_ADDR, x"FFFFFFFF", "pslverr expected", clk, apb_if, v_config);
    tb_read (C_ERR_ADDR, v_data     , "pslverr expected", clk, apb_if, v_config);
    check_value(get_alert_counter(WARNING), v_warnings, ERROR, "No alert when pslverr is expected", C_TB_SCOPE);

    -- pslverr not expected : one alert per access
    increment_expected_alerts(WARNING, 2, "pslverr not expected", C_TB_SCOPE);
    v_config.expected_pslverr := '0';
    tb_write(C_ERR_ADDR, x"FFFFFFFF", "pslverr not expected", clk, apb_if, v_config);
    check_value(get_alert_counter(WARNING), v_warnings+1, ERROR, "One alert of apb_write on pslverr", C_TB_SCOPE);
    tb_read (C_ERR_ADDR, v_data     , "pslverr not expected", clk, apb_if, v_config);
    check_value(get_alert_counter(WARNING), v_warnings+2, ERROR, "One alert of apb_read on pslverr", C_TB_SCOPE);

    -- pslverr expected but missing : one alert
    increment_expected_alerts(WARNING, 1, "pslverr missing", C_TB_SCOPE);
    v_config.expected_pslverr := '1';
    tb_write(16#40#, x"3C5AA5C3", "pslverr missing", clk, apb_if, v_config);
    check_value(get_alert_counter(WARNING), v_warnings+3, ERROR, "One alert of apb_write on a missing pslverr", C_TB_SCOPE);

    -- The slave answered normally
    tb_check(16#40#, x"3C5AA5C3", "Write without pslverr", clk, apb_if);
  end procedure run;

end package body tb_apb_pslverr_pkg;
