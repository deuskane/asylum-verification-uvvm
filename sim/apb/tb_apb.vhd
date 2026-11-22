-------------------------------------------------------------------------------
-- Title      : tb_apb
-- Project    : asylum-verification-uvvm
-------------------------------------------------------------------------------
-- File       : tb_apb.vhd
-- Author     : Mathieu Rosiere
-- Company    :
-- Created    : 2026-11-22
-- Platform   :
-- Standard   : VHDL'08
-------------------------------------------------------------------------------
-- Description:
--  Testbench of apb_bfm_pkg : the BFM drives the APB slave model
--  tb_apb_slave (memory, wait states, pslverr, protocol checker).
--  TESTS_LIST : scenarios run in sequence, separated by ',' (names in
--  tb_apb_tests_pkg), each one after a reset pulse ; "" : build and
--  elaboration only.
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
use     work.tb_apb_tests_pkg.all;

entity tb_apb is
  generic (
    TESTS_LIST      : string := ""                         -- Scenarios, e.g. "write_read,pslverr" (tb_apb_tests_pkg)
  );
end entity tb_apb;

architecture sim of tb_apb is

  constant C_SCOPE     : string    := "TB_APB";

  -- Clock and Reset
  signal   clk_i       : std_logic := '0';
  signal   clk_ena     : boolean   := true;
  signal   arst_b_i    : std_logic := '0';

  -- BFM
  signal   apb_if      : t_apb_if(paddr (C_ADDR_WIDTH-1 downto 0),
                                  pwdata(C_DATA_WIDTH-1 downto 0),
                                  prdata(C_DATA_WIDTH-1 downto 0)) := init_apb_if_signals(C_ADDR_WIDTH, C_DATA_WIDTH);

  -- APB
  signal   paddr       : std_logic_vector(C_ADDR_WIDTH-1 downto 0);
  signal   prdata      : std_logic_vector(C_DATA_WIDTH-1 downto 0);
  signal   pready      : std_logic;
  signal   pslverr     : std_logic;

  -- Slave model control
  signal   wait_states : natural   := 0;

begin  -- architecture sim

  -----------------------------------------------------------------------------
  -- Clock and Reset
  -----------------------------------------------------------------------------
  clock_generator(clk_i, clk_ena, C_CLK_PERIOD, "TB Clock");

  -----------------------------------------------------------------------------
  -- APB slave model, driven by the APB BFM
  -----------------------------------------------------------------------------
  ins_apb_slave : entity work.tb_apb_slave
    port map
    (clk_i           => clk_i
    ,arst_b_i        => arst_b_i
    ,psel_i          => apb_if.psel
    ,penable_i       => apb_if.penable
    ,pwrite_i        => apb_if.pwrite
    ,paddr_i         => paddr
    ,pwdata_i        => apb_if.pwdata
    ,prdata_o        => prdata
    ,pready_o        => pready
    ,pslverr_o       => pslverr
    ,wait_states_i   => wait_states
    );

  paddr          <= std_logic_vector(apb_if.paddr);
  apb_if.prdata  <= prdata;
  apb_if.pready  <= pready;
  apb_if.pslverr <= pslverr;

  -----------------------------------------------------------------------------
  -- Sequencer
  -----------------------------------------------------------------------------
  p_main : process is
  begin
    log(ID_LOG_HDR, "TESTS_LIST : " & TESTS_LIST, C_SCOPE);

    -- Every name is checked before the first scenario
    for i in 1 to list_length(TESTS_LIST) loop
      if not list_contains(C_TESTS, list_item(TESTS_LIST, i))
      then
        alert(TB_ERROR, "Unknown test """ & list_item(TESTS_LIST, i) & """ (tests : " & C_TESTS & ")", C_SCOPE);
      end if;
    end loop;

    for i in 1 to list_length(TESTS_LIST) loop
      -- Reset pulse, BFM and slave model idle : each scenario starts from reset
      apb_if      <= init_apb_if_signals(C_ADDR_WIDTH, C_DATA_WIDTH);
      wait_states <= 0;
      do_reset(clk_i, arst_b_i);
      wait_num_rising_edge(clk_i, 2);

      log(ID_LOG_HDR, "TEST " & integer'image(i) & "/" & integer'image(list_length(TESTS_LIST)) & " : " & list_item(TESTS_LIST, i), C_SCOPE);
      run_test(list_item(TESTS_LIST, i), clk_i, apb_if, wait_states);
      wait_num_rising_edge(clk_i, 2);
    end loop;

    report_alert_counters(FINAL);
    std.env.stop;
    wait;
  end process p_main;

end architecture sim;
