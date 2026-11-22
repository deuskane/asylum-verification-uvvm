-------------------------------------------------------------------------------
-- Title      : tb_apb_timeout_pkg
-- Project    : asylum-verification-uvvm
-------------------------------------------------------------------------------
-- File       : tb_apb_timeout_pkg.vhd
-- Author     : Mathieu Rosiere
-- Company    :
-- Created    : 2026-11-22
-- Platform   :
-- Standard   : VHDL'08
-------------------------------------------------------------------------------
-- Description:
--  Scenario timeout of tb_apb : the slave holds pready low during
--  max_wait_cycles+1 cycles : one timeout alert of the BFM
--  (config.max_wait_cycles_severity = WARNING, counted), and the slave model
--  flags the abandoned transfer (one expected ERROR, checked by the final
--  summary) ; then a normal transfer with max_wait_cycles wait states.
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

package tb_apb_timeout_pkg is

  -- pready never comes : timeout of the BFM, then a normal transfer
  procedure run(
    signal   clk         : in    std_logic;
    signal   apb_if      : inout t_apb_if;
    signal   wait_states : out   natural
    );

end package tb_apb_timeout_pkg;

package body tb_apb_timeout_pkg is

  procedure run(
    signal   clk         : in    std_logic;
    signal   apb_if      : inout t_apb_if;
    signal   wait_states : out   natural
    ) is
    variable v_config    : t_apb_bfm_config := C_APB_BFM_CONFIG_DEFAULT;
    variable v_warnings  : natural;
  begin
    v_config.max_wait_cycles_severity := WARNING;

    -- Timeout of the BFM, psel dropped before pready
    increment_expected_alerts(WARNING, 1, "Timeout", C_TB_SCOPE);
    increment_expected_alerts_and_stop_limit(ERROR, 1, "Transfer abandoned, flagged by the slave model", C_TB_SCOPE);
    v_warnings  := get_alert_counter(WARNING);
    wait_states <= v_config.max_wait_cycles+1;
    tb_write(16#50#, x"0F0F0F0F", "Timeout expected", clk, apb_if, v_config);
    check_value(get_alert_counter(WARNING), v_warnings+1, ERROR, "One timeout alert of apb_write", C_TB_SCOPE);
    wait until rising_edge(clk);                            -- The slave model sees psel low
    wait_states <= 0;
    tb_check(16#50#, mem_reset_value(16#50#), "Abandoned write ignored", clk, apb_if);

    -- max_wait_cycles : no timeout
    wait_states <= v_config.max_wait_cycles;
    tb_write(16#50#, x"0F0F0F0F", "max_wait_cycles wait states", clk, apb_if, v_config);
    tb_check(16#50#, x"0F0F0F0F", "max_wait_cycles wait states", clk, apb_if, v_config);
    wait_states <= 0;
  end procedure run;

end package body tb_apb_timeout_pkg;
