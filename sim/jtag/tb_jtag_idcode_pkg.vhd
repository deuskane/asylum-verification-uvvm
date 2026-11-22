-------------------------------------------------------------------------------
-- Title      : tb_jtag_idcode_pkg
-- Project    : asylum-verification-uvvm
-------------------------------------------------------------------------------
-- File       : tb_jtag_idcode_pkg.vhd
-- Author     : Mathieu Rosiere
-- Company    :
-- Created    : 2026-11-22
-- Platform   :
-- Standard   : VHDL'08
-------------------------------------------------------------------------------
-- Description:
--  Scenario idcode of tb_jtag : IDCODE selected by the reset and
--  by its instruction, read with jtag_scan_dr and jtag_check_dr, don't care
--  bits of jtag_check_dr, a mismatch of jtag_check_dr raises one alert
--  (alert_level WARNING, counted : an ERROR of the counter check is never an
--  expected one).
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
use     asylum_uvvm.jtag_bfm_pkg.all;

use     work.tb_jtag_bfm_pkg.all;

package tb_jtag_idcode_pkg is

  -- IDCODE read, don't care bits and mismatch of jtag_check_dr
  procedure run(
    signal   jtag_if     : inout t_jtag_if;
    signal   tap_state   : in    tap_state_t;
    signal   trst_cnt    : in    natural;
    constant config      : in    t_jtag_bfm_config;
    constant dr_width    : in    positive
    );

end package tb_jtag_idcode_pkg;

package body tb_jtag_idcode_pkg is

  procedure run(
    signal   jtag_if     : inout t_jtag_if;
    signal   tap_state   : in    tap_state_t;
    signal   trst_cnt    : in    natural;
    constant config      : in    t_jtag_bfm_config;
    constant dr_width    : in    positive
    ) is
    variable v_data      : std_logic_vector(32-1 downto 0);
    variable v_warnings  : natural;
  begin
    tb_reset("Reset", jtag_if, tap_state, config);
    tb_check_dr(x"00000000", C_IDCODE, "IDCODE selected by the reset", jtag_if, tap_state, config);

    tb_write_ir(C_IR_IDCODE, "IDCODE", jtag_if, tap_state, config);
    tb_scan_dr(x"FFFFFFFF", v_data, "IDCODE", jtag_if, tap_state, config);
    check_value(v_data, C_IDCODE, ERROR, "jtag_scan_dr of IDCODE", C_TB_SCOPE);

    -- Don't care bits of jtag_check_dr
    tb_check_dr(x"00000000", C_IDCODE(32-1 downto 12) & "------------", "Don't care on the 12 LSB", jtag_if, tap_state, config);

    -- A mismatch of jtag_check_dr raises one alert
    increment_expected_alerts(WARNING, 1, "Mismatch of jtag_check_dr", C_TB_SCOPE);
    v_warnings := get_alert_counter(WARNING);
    tb_check_dr(x"00000000", not C_IDCODE, "Mismatch expected", jtag_if, tap_state, config, WARNING);
    check_value(get_alert_counter(WARNING), v_warnings+1, ERROR, "One alert of jtag_check_dr on a mismatch", C_TB_SCOPE);
  end procedure run;

end package body tb_jtag_idcode_pkg;
