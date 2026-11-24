-------------------------------------------------------------------------------
-- Title      : tb_rbb
-- Project    : asylum-verification-uvvm
-------------------------------------------------------------------------------
-- File       : tb_rbb.vhd
-- Author     : Mathieu Rosiere
-- Company    :
-- Created    : 2026-11-24
-- Platform   :
-- Standard   : VHDL'08
-------------------------------------------------------------------------------
-- Description:
--  Testbench of rbb_bfm_pkg : the BFM sends the remote_bitbang bytes to the
--  decoder tb_rbb_decoder, which drives the chain of TAP models of tb_jtag
--  (TDI -> TAP 0 -> TAP 1 -> TAP 2 -> TDO, C_CHAIN_* of tb_jtag_bfm_pkg,
--  pull-ups between the TAPs and on TDO) ; its answers to 'R' come back to
--  rbb_axis_monitor (AXI-Stream) or, in the UART mode of a scenario
--  (ctrl.uart), as UART frames to rbb_uart_monitor : the commands of
--  rbb_if.tx are received by the UVVM UART BFM (p_uart_rx), the answers sent
--  by it (p_uart_tx).
--  Monitors : TMS and TDI change while TCK is low only, count of the TCK
--  rising edges and of the TRST* pulses.
--  TESTS_LIST : scenarios run in sequence, separated by ',' (names in
--  tb_rbb_tests_pkg), each one after a reset pulse of the decoder and of
--  the TAP models ; "" : build and elaboration only.
-------------------------------------------------------------------------------
-- Copyright (c) 2026
-------------------------------------------------------------------------------
-- Revisions  :
-- Date        Version  Author   Description
-- 2026-11-24  1.0      mrosiere Created
-------------------------------------------------------------------------------

library ieee;
use     ieee.std_logic_1164.all;
use     ieee.numeric_std.all;

library uvvm_util;
context uvvm_util.uvvm_util_context;

library bitvis_vip_uart;
use     bitvis_vip_uart.uart_bfm_pkg.all;

library asylum;
use     asylum.string_pkg.all;

library asylum_uvvm;
use     asylum_uvvm.rbb_bfm_pkg.all;

use     work.tb_jtag_bfm_pkg.all;
use     work.tb_rbb_bfm_pkg.all;
use     work.tb_rbb_tests_pkg.all;

entity tb_rbb is
  generic (
    TESTS_LIST      : string   := ""                       -- Scenarios, e.g. "commands,idcode" (tb_rbb_tests_pkg)
  );
end entity tb_rbb;

architecture sim of tb_rbb is

  constant C_SCOPE        : string    := "TB_RBB";

  signal   clk            : std_logic;
  signal   clk_ena        : boolean   := true;
  signal   arst_b         : std_logic := '0';

  -- BFM, answers of the monitors
  signal   rbb_if         : t_rbb_if      := init_rbb_if_signals;
  signal   axis_answers   : t_rbb_answers := C_RBB_ANSWERS_INIT;
  signal   uart_answers   : t_rbb_answers := C_RBB_ANSWERS_INIT;
  signal   answers        : t_rbb_answers;

  -- Scenarios
  signal   ctrl           : tb_ctrl_t     := C_TB_CTRL_IDLE;
  signal   obs            : tb_obs_t;

  -- Decoder
  signal   s_tdata        : std_logic_vector(8-1 downto 0);
  signal   s_tvalid       : std_logic;
  signal   s_tready       : std_logic;
  signal   m_tdata        : std_logic_vector(8-1 downto 0);
  signal   m_tvalid       : std_logic;
  signal   m_tready       : std_logic := '1';                -- Answers always taken
  signal   tck            : std_logic;
  signal   tms            : std_logic;
  signal   tdi            : std_logic;
  signal   trst_b         : std_logic;

  -- UART mode : commands received from rbb_if.tx, answers sent on uart_ans
  signal   u_tdata        : std_logic_vector(8-1 downto 0) := x"00";
  signal   u_tvalid       : std_logic := '0';
  signal   uart_ans       : std_logic := '1';
  signal   uart_stop      : std_logic;

  -- Monitors
  signal   tck_cnt        : natural;
  signal   trst_cnt       : natural;

  -- Chain : link i = TDI of TAP i, link C_CHAIN_NB_TAP = TDO
  signal   chain_link     : std_logic_vector(0 to C_CHAIN_NB_TAP);
  type tap_state_array_t is array (natural range <>) of tap_state_t;
  signal   chain_state    : tap_state_array_t(0 to C_CHAIN_NB_TAP-1);

begin  -- architecture sim

  clock_generator(clk, clk_ena, C_CLK_PERIOD, "TB Clock");

  -----------------------------------------------------------------------------
  -- Decoder : commands of the BFM (AXI-Stream) or of the UART
  -----------------------------------------------------------------------------
  s_tdata       <= u_tdata  when ctrl.uart else rbb_if.tdata;
  s_tvalid      <= u_tvalid when ctrl.uart else rbb_if.tvalid;
  rbb_if.tready <= '0'      when ctrl.uart else s_tready;

  ins_decoder : entity work.tb_rbb_decoder
    port map
    (clk_i           => clk
    ,arst_b_i        => arst_b
    ,s_axis_tdata_i  => s_tdata
    ,s_axis_tvalid_i => s_tvalid
    ,s_axis_tready_o => s_tready
    ,m_axis_tdata_o  => m_tdata
    ,m_axis_tvalid_o => m_tvalid
    ,m_axis_tready_i => m_tready
    ,tck_o           => tck
    ,tms_o           => tms
    ,tdi_o           => tdi
    ,trst_b_o        => trst_b
    ,srst_b_o        => obs.srst_b
    ,blink_o         => obs.blink
    ,tdo_i           => chain_link(C_CHAIN_NB_TAP)
    ,mute_i          => ctrl.mute
    ,stall_i         => ctrl.stall
    ,cmd_cnt_o       => obs.cmd_cnt
    );

  -----------------------------------------------------------------------------
  -- Answers : AXI-Stream, or UART frames in the UART mode
  -----------------------------------------------------------------------------
  rbb_axis_monitor(clk, m_tdata, m_tvalid, m_tready, axis_answers, C_SCOPE);

  uart_stop <= '0' when ctrl.uart else '1';
  rbb_uart_monitor(uart_ans, uart_stop, uart_answers, C_SCOPE, C_RBB_UART);

  answers   <= uart_answers when ctrl.uart else axis_answers;

  -- Command frames of the BFM to the decoder
  p_uart_rx : process
    variable v_byte : std_logic_vector(8-1 downto 0);
  begin
    if not ctrl.uart
    then
      wait until ctrl.uart;
    end if;
    uart_receive(v_byte, "Command", rbb_if.tx, uart_stop, C_RBB_UART.uart_config, C_SCOPE);
    if ctrl.uart
    then
      wait until falling_edge(clk);
      u_tdata  <= v_byte;
      u_tvalid <= '1';
      wait until rising_edge(clk) and s_tready = '1';
      u_tvalid <= '0';
    end if;
  end process p_uart_rx;

  -- Answers of the decoder as frames (one answer at most per 3 commands)
  p_uart_tx : process
  begin
    wait until rising_edge(clk) and m_tvalid = '1' and ctrl.uart;
    uart_transmit(m_tdata, "Answer", uart_ans, C_RBB_UART.uart_config, C_SCOPE);
  end process p_uart_tx;

  -----------------------------------------------------------------------------
  -- Chain of TAP models : TDI -> TAP 0 -> ... -> TAP C_CHAIN_NB_TAP-1 -> TDO,
  -- pull-ups (TDO of a TAP at 'Z' out of Shift-IR and Shift-DR)
  -----------------------------------------------------------------------------
  chain_link(0)                   <= tdi;
  chain_link(1 to C_CHAIN_NB_TAP) <= (others => 'H');

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
      ,tck_i           => tck
      ,tms_i           => tms
      ,tdi_i           => to_X01(chain_link(i))
      ,trst_b_i        => trst_b
      ,tdo_o           => chain_link(i+1)
      ,capture_error_i => '0'
      ,state_o         => chain_state(i)
      ,ir_o            => ir
      );

    obs.tap_ir(i) <= to_integer(unsigned(ir));
  end generate gen_tap;

  obs.tap_state <= chain_state(0);
  obs.pins      <= tck & tms & tdi;
  obs.trst_b    <= trst_b;

  -----------------------------------------------------------------------------
  -- Monitors : TMS and TDI change while TCK is low, TCK edges, TRST* pulses
  -----------------------------------------------------------------------------
  p_tck_low : process
  begin
    wait on tms, tdi;
    if tck /= '0'
    then
      alert(ERROR, "TMS or TDI changed while TCK is high", C_SCOPE);
    end if;
  end process p_tck_low;

  p_tck : process
  begin
    wait until rising_edge(tck) or arst_b = '0';
    tck_cnt  <= 0 when arst_b = '0' else tck_cnt + 1;
  end process p_tck;

  p_trst : process
  begin
    wait until falling_edge(trst_b) or arst_b = '0';
    trst_cnt <= 0 when arst_b = '0' else trst_cnt + 1;
  end process p_trst;

  obs.tck_cnt   <= tck_cnt;
  obs.trst_cnt  <= trst_cnt;

  -----------------------------------------------------------------------------
  -- Sequencer
  -----------------------------------------------------------------------------
  p_main : process is
  begin
    log(ID_LOG_HDR, "Chain of " & to_string(C_CHAIN_NB_TAP) & " TAPs behind a remote_bitbang decoder, TESTS_LIST : " & TESTS_LIST, C_SCOPE);

    -- Every name is checked before the first scenario
    for i in 1 to list_length(TESTS_LIST) loop
      if not list_contains(C_TESTS, list_item(TESTS_LIST, i))
      then
        alert(TB_ERROR, "Unknown test """ & list_item(TESTS_LIST, i) & """ (tests : " & C_TESTS & ")", C_SCOPE);
      end if;
    end loop;

    for i in 1 to list_length(TESTS_LIST) loop
      -- BFM idle, AXI-Stream, reset pulse of the decoder and of the TAP
      -- models released on the falling edge of clk : each scenario starts
      -- from reset
      rbb_if <= init_rbb_if_signals;
      ctrl   <= C_TB_CTRL_IDLE;
      arst_b <= '0';
      wait until falling_edge(clk);
      wait for 2*C_CLK_PERIOD;
      arst_b <= '1';
      wait until falling_edge(clk);

      log(ID_LOG_HDR, "TEST " & integer'image(i) & "/" & integer'image(list_length(TESTS_LIST)) & " : " & list_item(TESTS_LIST, i), C_SCOPE);
      run_test(list_item(TESTS_LIST, i), clk, rbb_if, answers, ctrl, obs);
      wait for 4*C_CLK_PERIOD;
    end loop;

    report_alert_counters(FINAL);
    std.env.stop;
    wait;
  end process p_main;

end architecture sim;
