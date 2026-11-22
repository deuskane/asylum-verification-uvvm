-------------------------------------------------------------------------------
-- Title      : tb_jtag_reset_trst_pkg
-- Project    : asylum-verification-uvvm
-------------------------------------------------------------------------------
-- File       : tb_jtag_reset_trst_pkg.vhd
-- Author     : Mathieu Rosiere
-- Company    :
-- Created    : 2026-11-22
-- Platform   :
-- Standard   : VHDL'08
-------------------------------------------------------------------------------
-- Description:
--  Scenario reset_trst of tb_jtag : jtag_reset with a TRST pulse
--  (config.trst_enable) : one pulse, TRST released, IDCODE selected, also
--  after an instruction that selects BYPASS.
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

package tb_jtag_reset_trst_pkg is

  -- TRST pulse then TMS reset : IDCODE selected
  procedure run(
    signal   jtag_if     : inout t_jtag_if;
    signal   tap_state   : in    tap_state_t;
    signal   trst_cnt    : in    natural;
    constant config      : in    t_jtag_bfm_config;
    constant dr_width    : in    positive
    );

end package tb_jtag_reset_trst_pkg;

package body tb_jtag_reset_trst_pkg is

  procedure run(
    signal   jtag_if     : inout t_jtag_if;
    signal   tap_state   : in    tap_state_t;
    signal   trst_cnt    : in    natural;
    constant config      : in    t_jtag_bfm_config;
    constant dr_width    : in    positive
    ) is
    variable v_config    : t_jtag_bfm_config := config;
    variable v_trst      : natural;
  begin
    v_config.trst_enable := true;
    v_trst := trst_cnt;
    tb_reset("TRST pulse", jtag_if, tap_state, v_config);
    check_value(trst_cnt, v_trst+1, ERROR, "One TRST pulse", C_TB_SCOPE);
    check_value(jtag_if.trst_b, '1', ERROR, "TRST released", C_TB_SCOPE);
    tb_check_dr(x"00000000", C_IDCODE, "IDCODE selected after the reset", jtag_if, tap_state, v_config);

    -- BYPASS selected, then reset again
    tb_write_ir(ir_bypass(v_config), "BYPASS", jtag_if, tap_state, v_config);
    tb_reset("TRST pulse", jtag_if, tap_state, v_config);
    check_value(trst_cnt, v_trst+2, ERROR, "One more TRST pulse", C_TB_SCOPE);
    tb_check_dr(x"00000000", C_IDCODE, "IDCODE selected after the reset", jtag_if, tap_state, v_config);
  end procedure run;

end package body tb_jtag_reset_trst_pkg;
