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
--  TCK is low only, count of the TRST pulses and of the TCK rising edges,
--  Capture-IR value of each IR scan (jtag_ir_capture_monitor of the BFM).
--  MODEL "chain" : TDI -> TAP 0 -> TAP 1 -> TAP 2 -> TDO (C_CHAIN_* of
--  tb_jtag_bfm_pkg, IR_WIDTH and DR_WIDTH not used), pull-ups between the
--  TAPs ; two Capture-IR monitors : the whole chain, and one target TAP at
--  its place (head_ir).
--  TESTS_LIST : scenarios run in sequence, separated by ',' (names in
--  tb_jtag_tests_pkg), each one after a power-on reset pulse of the TAP
--  model ; "" : build and elaboration only.
-------------------------------------------------------------------------------
-- Copyright (c) 2026
-------------------------------------------------------------------------------
-- Revisions  :
-- Date        Version  Author   Description
-- 2026-11-22  1.0      mrosiere Created
-- 2026-11-22  1.1      mrosiere jtag_ir_capture_monitor, count of the TCK
--                               edges, wrong Capture-IR value of the TAP
-- 2026-11-23  1.2      mrosiere MODEL "chain" : chain of 3 TAPs
-------------------------------------------------------------------------------

library ieee;
use     ieee.std_logic_1164.all;
use     ieee.numeric_std.all;

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
   ;MODEL           : string   := "single"                 -- "single" : one TAP ; "chain" : chain of C_CHAIN_NB_TAP TAPs
  );
end entity tb_jtag;

architecture sim of tb_jtag is

  constant C_SCOPE     : string    := "TB_JTAG";

  -- Configuration of the BFM and of the Capture-IR monitor
  constant C_JTAG_CONFIG : t_jtag_bfm_config := (
    tck_period       => TCK_PERIOD_NS * 1 ns,
    ir_width         => IR_WIDTH,
    idle_cycles      => 0,
    trst_enable      => true,
    head_ir          => 0,
    tail_ir          => 0,
    head_dr          => 0,
    tail_dr          => 0,
    match_strictness => MATCH_EXACT,
    id_for_bfm       => ID_BFM
    );

  -- Power-on reset of the TAP model
  signal   arst_b      : std_logic := '0';

  -- BFM
  signal   jtag_if     : t_jtag_if := init_jtag_if_signals;

  -- Valid scenarios of the model
  function model_tests return string is
  begin
    if MODEL = "chain"
    then
      return C_TESTS_CHAIN;
    end if;
    return C_TESTS;
  end function model_tests;

  constant C_MODEL_TESTS : string := model_tests;

  type tap_state_array_t is array (natural range <>) of tap_state_t;

  -- TAP model (state of TAP 0 in a chain), wrong Capture-IR value and
  -- instruction of each TAP of the chain
  signal   tdo         : std_logic;
  signal   tap_state   : tap_state_t;
  signal   capture_err : std_logic_vector(0 to C_CHAIN_NB_TAP-1) := (others => '0');
  signal   tap_ir      : integer_vector  (0 to C_CHAIN_NB_TAP-1) := (others => 0);

  -- Chain : link i = TDI of TAP i, link C_CHAIN_NB_TAP = TDO
  signal   chain_link  : std_logic_vector(0 to C_CHAIN_NB_TAP);
  signal   chain_state : tap_state_array_t(0 to C_CHAIN_NB_TAP-1);

  -- Monitor
  signal   trst_cnt    : natural   := 0;
  signal   tck_cnt     : natural   := 0;

begin  -- architecture sim

  -----------------------------------------------------------------------------
  -- TAP model, driven by the JTAG BFM
  -----------------------------------------------------------------------------
  gen_single: if MODEL = "single"
  generate
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
      ,capture_error_i => capture_err(0)
      ,state_o         => tap_state
      ,ir_o            => open
      );

    jtag_if.tdo <= tdo;

    jtag_ir_capture_monitor(jtag_if      => jtag_if,
                            expected     => "01",
                            scope        => C_SCOPE,
                            config       => C_JTAG_CONFIG);
  end generate gen_single;

  -----------------------------------------------------------------------------
  -- Chain of TAP models : TDI -> TAP 0 -> ... -> TAP C_CHAIN_NB_TAP-1 -> TDO
  -----------------------------------------------------------------------------
  gen_chain: if MODEL = "chain"
  generate
    -- Pull-up of the TDI of each TAP (IEEE 1149.1) : the TDO of the previous
    -- TAP is 'Z' out of Shift-IR and Shift-DR
    chain_link(0)                     <= jtag_if.tdi;
    chain_link(1 to C_CHAIN_NB_TAP-1) <= (others => 'H');

    gen_tap: for i in 0 to C_CHAIN_NB_TAP-1
    generate
      signal   ir      : std_logic_vector(C_CHAIN_IR_WIDTH(i)-1 downto 0);
    begin
      ins_jtag_tap : entity work.tb_jtag_tap
        generic map
        (IR_WIDTH        => C_CHAIN_IR_WIDTH(i)
        ,DR_WIDTH        => C_CHAIN_DR_WIDTH(i)
        ,IDCODE          => C_CHAIN_IDCODE  (i)
        )
        port map
        (arst_b_i        => arst_b
        ,tck_i           => jtag_if.tck
        ,tms_i           => jtag_if.tms
        ,tdi_i           => to_X01(chain_link(i))
        ,trst_b_i        => jtag_if.trst_b
        ,tdo_o           => chain_link(i+1)
        ,capture_error_i => capture_err(i)
        ,state_o         => chain_state(i)
        ,ir_o            => ir
        );

      tap_ir(i) <= to_integer(unsigned(ir));
    end generate gen_tap;

    tap_state   <= chain_state(0);
    jtag_if.tdo <= chain_link(C_CHAIN_NB_TAP);

    -- Capture-IR monitors : the whole chain ; the target TAP
    -- C_CHAIN_MONITOR_TAP alone, at its place
    jtag_ir_capture_monitor(jtag_if      => jtag_if,
                            expected     => chain_ir_capture,
                            scope        => C_SCOPE & " chain",
                            config       => chain_whole_config(C_JTAG_CONFIG));

    jtag_ir_capture_monitor(jtag_if      => jtag_if,
                            expected     => "01",
                            scope        => C_SCOPE & " TAP " & to_string(C_CHAIN_MONITOR_TAP),
                            config       => chain_config(C_JTAG_CONFIG, C_CHAIN_MONITOR_TAP));
  end generate gen_chain;

  -----------------------------------------------------------------------------
  -- Monitors : TMS and TDI change while TCK is low, TRST pulses, TCK edges,
  -- Capture-IR value
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

  p_tck : process
  begin
    wait until rising_edge(jtag_if.tck);
    tck_cnt  <= tck_cnt + 1;
  end process p_tck;

  -----------------------------------------------------------------------------
  -- Sequencer
  -----------------------------------------------------------------------------
  p_main : process is
    variable v_config : t_jtag_bfm_config := C_JTAG_CONFIG;
  begin
    if MODEL = "chain"
    then
      log(ID_LOG_HDR, "Chain of " & to_string(C_CHAIN_NB_TAP) & " TAPs, TCK " & to_string(TCK_PERIOD_NS) & " ns, TESTS_LIST : " & TESTS_LIST, C_SCOPE);
    elsif MODEL = "single"
    then
      log(ID_LOG_HDR, "IR " & to_string(IR_WIDTH) & " bits, user DR " & to_string(DR_WIDTH) & " bits, TCK " & to_string(TCK_PERIOD_NS) & " ns, TESTS_LIST : " & TESTS_LIST, C_SCOPE);
    else
      alert(TB_ERROR, "Unknown MODEL """ & MODEL & """ (single, chain)", C_SCOPE);
    end if;

    -- Every name is checked before the first scenario
    for i in 1 to list_length(TESTS_LIST) loop
      if not list_contains(C_MODEL_TESTS, list_item(TESTS_LIST, i))
      then
        alert(TB_ERROR, "Unknown test """ & list_item(TESTS_LIST, i) & """ (tests of MODEL " & MODEL & " : " & C_MODEL_TESTS & ")", C_SCOPE);
      end if;
    end loop;

    for i in 1 to list_length(TESTS_LIST) loop
      -- BFM idle, power-on reset pulse of the TAP model : each scenario starts from reset
      jtag_if     <= init_jtag_if_signals;
      capture_err <= (others => '0');
      arst_b      <= '0';
      wait for 2*v_config.tck_period;
      arst_b      <= '1';
      wait for v_config.tck_period;

      log(ID_LOG_HDR, "TEST " & integer'image(i) & "/" & integer'image(list_length(TESTS_LIST)) & " : " & list_item(TESTS_LIST, i), C_SCOPE);
      run_test(list_item(TESTS_LIST, i), jtag_if, tap_state, trst_cnt, tck_cnt, capture_err, tap_ir, v_config, DR_WIDTH);
      wait for 2*v_config.tck_period;
    end loop;

    report_alert_counters(FINAL);
    std.env.stop;
    wait;
  end process p_main;

end architecture sim;
