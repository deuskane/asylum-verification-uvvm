-------------------------------------------------------------------------------
-- Title      : tb_jtag
-- Project    : asylum-verification-uvvm
-------------------------------------------------------------------------------
-- File       : tb_jtag.vhd
-- Author     : Mathieu Rosiere
-- Company    :
-- Created    : 2026-11-22
-- Platform   :
-- Standard   : VHDL'08
-------------------------------------------------------------------------------
-- Description:
--  Testbench of jtag_bfm_pkg : the BFM drives the IEEE 1149.1 TAP model
--  tb_jtag_tap (IR_WIDTH-bit IR, IDCODE, BYPASS, DR_WIDTH-bit user
--  register), TCK period TCK_PERIOD_NS. Monitors : TMS and TDI change while
--  TCK is low only, count of the TRST pulses.
--  TESTS_LIST : scenarios run in sequence, separated by ',' (names in
--  tb_jtag_tests_pkg), each one after a power-on reset pulse of the TAP
--  model ; "" : build and elaboration only.
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
use     asylum_uvvm.jtag_bfm_pkg.all;

use     work.tb_jtag_bfm_pkg.all;
use     work.tb_jtag_tests_pkg.all;

entity tb_jtag is
  generic (
    TESTS_LIST      : string   := ""                       -- Scenarios, e.g. "idcode,bypass" (tb_jtag_tests_pkg)
   ;IR_WIDTH        : positive := 5                        -- Width of the instruction register (config.ir_width)
   ;DR_WIDTH        : positive := 40                       -- Width of the user data register of the TAP model
   ;TCK_PERIOD_NS   : positive := 100                      -- Period of TCK (config.tck_period)
  );
end entity tb_jtag;

architecture sim of tb_jtag is

  constant C_SCOPE     : string    := "TB_JTAG";

  -- Power-on reset of the TAP model
  signal   arst_b      : std_logic := '0';

  -- BFM
  signal   jtag_if     : t_jtag_if := init_jtag_if_signals;

  -- TAP model
  signal   tdo         : std_logic;
  signal   tap_state   : tap_state_t;

  -- Monitor
  signal   trst_cnt    : natural   := 0;

begin  -- architecture sim

  -----------------------------------------------------------------------------
  -- TAP model, driven by the JTAG BFM
  -----------------------------------------------------------------------------
  ins_jtag_tap : entity work.tb_jtag_tap
    generic map
    (IR_WIDTH        => IR_WIDTH
    ,DR_WIDTH        => DR_WIDTH
    )
    port map
    (arst_b_i        => arst_b
    ,tck_i           => jtag_if.tck
    ,tms_i           => jtag_if.tms
    ,tdi_i           => jtag_if.tdi
    ,trst_b_i        => jtag_if.trst_b
    ,tdo_o           => tdo
    ,state_o         => tap_state
    );

  jtag_if.tdo <= tdo;

  -----------------------------------------------------------------------------
  -- Monitors : TMS and TDI change while TCK is low, TRST pulses
  -----------------------------------------------------------------------------
  p_tck_low : process
  begin
    wait on jtag_if.tms, jtag_if.tdi;
    if jtag_if.tck /= '0'
    then
      alert(ERROR, "TMS or TDI changed while TCK is high", C_SCOPE);
    end if;
  end process p_tck_low;

  p_trst : process
  begin
    wait until falling_edge(jtag_if.trst_b);
    trst_cnt <= trst_cnt + 1;
  end process p_trst;

  -----------------------------------------------------------------------------
  -- Sequencer
  -----------------------------------------------------------------------------
  p_main : process is
    variable v_config : t_jtag_bfm_config := C_JTAG_BFM_CONFIG_DEFAULT;
  begin
    v_config.ir_width   := IR_WIDTH;
    v_config.tck_period := TCK_PERIOD_NS * 1 ns;
    log(ID_LOG_HDR, "IR " & to_string(IR_WIDTH) & " bits, user DR " & to_string(DR_WIDTH) & " bits, TCK " & to_string(TCK_PERIOD_NS) & " ns, TESTS_LIST : " & TESTS_LIST, C_SCOPE);

    -- Every name is checked before the first scenario
    for i in 1 to list_length(TESTS_LIST) loop
      if not list_contains(C_TESTS, list_item(TESTS_LIST, i))
      then
        alert(TB_ERROR, "Unknown test """ & list_item(TESTS_LIST, i) & """ (tests : " & C_TESTS & ")", C_SCOPE);
      end if;
    end loop;

    for i in 1 to list_length(TESTS_LIST) loop
      -- BFM idle, power-on reset pulse of the TAP model : each scenario starts from reset
      jtag_if <= init_jtag_if_signals;
      arst_b  <= '0';
      wait for 2*v_config.tck_period;
      arst_b  <= '1';
      wait for v_config.tck_period;

      log(ID_LOG_HDR, "TEST " & integer'image(i) & "/" & integer'image(list_length(TESTS_LIST)) & " : " & list_item(TESTS_LIST, i), C_SCOPE);
      run_test(list_item(TESTS_LIST, i), jtag_if, tap_state, trst_cnt, v_config, DR_WIDTH);
      wait for 2*v_config.tck_period;
    end loop;

    report_alert_counters(FINAL);
    std.env.stop;
    wait;
  end process p_main;

end architecture sim;
