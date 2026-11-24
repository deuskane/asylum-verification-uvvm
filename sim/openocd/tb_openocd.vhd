-------------------------------------------------------------------------------
-- Title      : tb_openocd
-- Project    : asylum-verification-uvvm
-------------------------------------------------------------------------------
-- File       : tb_openocd.vhd
-- Author     : Mathieu Rosiere
-- Company    :
-- Created    : 2026-11-24
-- Platform   :
-- Standard   : VHDL'08
-------------------------------------------------------------------------------
-- Description:
--  Co-simulation of the OpenOCD kit (asylum:verification:openocd) : OpenOCD
--  (remote_bitbang adapter, TCP, rbb_server.c through VHPIDIRECT) drives
--  the TAP model of tb_jtag (IR of 5 bits, IDCODE x5A7C3E1B, user data
--  register of 16 bits, opcode 2) :
--  - MODE "pin"  : rbb_jtag (PIN mode, CLK_DIV cycles of clk between two
--                  pin changes) drives the pins of the TAP,
--  - MODE "byte" : rbb_axis (BYTE mode) sends the bytes to the
--                  remote_bitbang decoder of tb_rbb, which drives the TAP.
--  OpenOCD runs the checks of sim/openocd/tap.cfg (hooks in rbb/cosim.sh of
--  the kit) ; the testbench checks that OpenOCD used TCK, TRST* and SRST*,
--  that its last TRST* pulse reset the TAP (USER instruction of tap.cfg
--  before, IDCODE and Test-Logic-Reset after : OpenOCD needs an IR scan
--  after TRST*, so it cannot see it), the pin changes CLK_DIV cycles apart
--  at least (pin), the answers to 'R' and the LED (byte). End when OpenOCD
--  closes the connection, error after C_TIMEOUT.
-------------------------------------------------------------------------------
-- Copyright (c) 2026
-------------------------------------------------------------------------------
-- Revisions  :
-- Date        Version  Author   Description
-- 2026-11-24  1.0      mrosiere Created
-- 2026-11-24  1.1      mrosiere TRST* checked on the TAP
-------------------------------------------------------------------------------

library ieee;
use     ieee.std_logic_1164.all;
use     ieee.numeric_std.all;

library uvvm_util;
context uvvm_util.uvvm_util_context;

library asylum_uvvm;

use     work.tb_jtag_bfm_pkg.all;

entity tb_openocd is
  generic (
    MODE            : string   := "pin"                    -- "pin" : rbb_jtag ; "byte" : rbb_axis and the remote_bitbang decoder
   ;CLK_DIV         : positive := 4                        -- Cycles of clk between two calls of rbb_tick (pin)
  );
end entity tb_openocd;

architecture sim of tb_openocd is

  constant C_SCOPE        : string    := "TB_OPENOCD";
  constant C_CLK_PERIOD   : time      := 10 ns;
  constant C_TIMEOUT      : time      := 100 ms;
  constant C_IR_WIDTH     : positive  := 5;                -- sim/openocd/tap.cfg
  constant C_DR_WIDTH     : positive  := 16;

  signal   clk            : std_logic;
  signal   clk_ena        : boolean   := true;
  signal   arst_b         : std_logic := '0';

  -- JTAG pins, system reset, LED, end
  signal   tck            : std_logic;
  signal   tms            : std_logic;
  signal   tdi            : std_logic;
  signal   trst_b         : std_logic;
  signal   srst_b         : std_logic;
  signal   tdo            : std_logic;
  signal   tap_state      : tap_state_t;
  signal   tap_ir         : std_logic_vector(C_IR_WIDTH-1 downto 0);
  signal   blink          : std_logic := '0';
  signal   quit           : std_logic;

  -- Answers to 'R' (byte)
  signal   reads          : natural   := 0;

begin  -- architecture sim

  clock_generator(clk, clk_ena, C_CLK_PERIOD, "TB Clock");
  arst_b <= '1' after 4*C_CLK_PERIOD + C_CLK_PERIOD/2;

  -----------------------------------------------------------------------------
  -- PIN mode : OpenOCD drives the pins
  -----------------------------------------------------------------------------
  gen_pin: if MODE = "pin"
  generate
    ins_rbb : entity asylum_uvvm.rbb_jtag
      generic map
      (CLK_DIV         => CLK_DIV
      )
      port map
      (clk_i           => clk
      ,arst_b_i        => arst_b
      ,tck_o           => tck
      ,tms_o           => tms
      ,tdi_o           => tdi
      ,trst_b_o        => trst_b
      ,srst_b_o        => srst_b
      ,tdo_i           => tdo
      ,quit_o          => quit
      );
  end generate gen_pin;

  -----------------------------------------------------------------------------
  -- BYTE mode : the bytes of OpenOCD to the remote_bitbang decoder
  -----------------------------------------------------------------------------
  gen_byte: if MODE = "byte"
  generate
    signal   cmd_tdata      : std_logic_vector(8-1 downto 0);
    signal   cmd_tvalid     : std_logic;
    signal   cmd_tready     : std_logic;
    signal   ans_tdata      : std_logic_vector(8-1 downto 0);
    signal   ans_tvalid     : std_logic;
  begin
    ins_rbb : entity asylum_uvvm.rbb_axis
      port map
      (clk_i           => clk
      ,arst_b_i        => arst_b
      ,m_axis_tdata_o  => cmd_tdata
      ,m_axis_tvalid_o => cmd_tvalid
      ,m_axis_tready_i => cmd_tready
      ,s_axis_tdata_i  => ans_tdata
      ,s_axis_tvalid_i => ans_tvalid
      ,s_axis_tready_o => open
      ,quit_o          => quit
      );

    ins_decoder : entity work.tb_rbb_decoder
      port map
      (clk_i           => clk
      ,arst_b_i        => arst_b
      ,s_axis_tdata_i  => cmd_tdata
      ,s_axis_tvalid_i => cmd_tvalid
      ,s_axis_tready_o => cmd_tready
      ,m_axis_tdata_o  => ans_tdata
      ,m_axis_tvalid_o => ans_tvalid
      ,m_axis_tready_i => '1'
      ,tck_o           => tck
      ,tms_o           => tms
      ,tdi_o           => tdi
      ,trst_b_o        => trst_b
      ,srst_b_o        => srst_b
      ,blink_o         => blink
      ,tdo_i           => tdo
      ,mute_i          => '0'
      ,stall_i         => '0'
      ,cmd_cnt_o       => open
      );

    p_reads : process
    begin
      wait until rising_edge(clk) and ans_tvalid = '1';
      reads <= reads + 1;
    end process p_reads;
  end generate gen_byte;

  -----------------------------------------------------------------------------
  -- TAP model, pull-up of TDO
  -----------------------------------------------------------------------------
  ins_jtag_tap : entity work.tb_jtag_tap
    generic map
    (IR_WIDTH        => C_IR_WIDTH
    ,DR_WIDTH        => C_DR_WIDTH
    )
    port map
    (arst_b_i        => arst_b
    ,tck_i           => tck
    ,tms_i           => tms
    ,tdi_i           => tdi
    ,trst_b_i        => trst_b
    ,tdo_o           => tdo
    ,capture_error_i => '0'
    ,state_o         => tap_state
    ,ir_o            => tap_ir
    );

  tdo <= 'H';

  -----------------------------------------------------------------------------
  -- Pins used by OpenOCD, end of the simulation
  -----------------------------------------------------------------------------
  p_main : process
    variable v_tck      : natural := 0;
    variable v_trst     : boolean := false;
    variable v_srst     : boolean := false;
    variable v_blink    : boolean := false;
    variable v_trst_ir  : natural := 0;                    -- Instruction before the last TRST* pulse
    variable v_trst_rst : boolean := false;                -- The last TRST* pulse reset the TAP
    variable v_last     : time    := 0 ns;
    variable v_min      : time    := time'high;
  begin
    if MODE /= "pin" and MODE /= "byte"
    then
      alert(TB_ERROR, "Unknown MODE """ & MODE & """ (pin, byte)", C_SCOPE);
    end if;
    log(ID_LOG_HDR, "OpenOCD co-simulation, MODE " & MODE & ", CLK_DIV " & integer'image(CLK_DIV), C_SCOPE);

    wait until arst_b = '1';
    while quit /= '1' loop
      wait on tck, tms, tdi, trst_b, srst_b, blink, quit for C_TIMEOUT;
      exit when now >= C_TIMEOUT;
      if tck'event or tms'event or tdi'event or trst_b'event or srst_b'event
      then
        v_min  := minimum(v_min, now - v_last);
        v_last := now;
      end if;
      v_tck   := v_tck + 1 when rising_edge(tck) else v_tck;
      v_trst  := v_trst  or trst_b = '0';
      if trst_b'event and trst_b = '0'
      then
        v_trst_ir  := to_integer(unsigned(tap_ir));        -- The TAP sees the pulse in the next delta cycles
      end if;
      if trst_b'event and trst_b = '1'
      then
        v_trst_rst := tap_state = TEST_LOGIC_RESET and to_integer(unsigned(tap_ir)) = C_IR_IDCODE;
      end if;
      v_srst  := v_srst  or srst_b = '0';
      v_blink := v_blink or blink  = '1';
    end loop;

    log(ID_LOG_HDR, "End at " & integer'image(now / 1 us) & " us : " & integer'image(v_tck) & " TCK cycles", C_SCOPE);
    check_value(quit = '1', ERROR, "OpenOCD closed the connection before " & integer'image(C_TIMEOUT / 1 ms) & " ms", C_SCOPE);
    check_value(v_tck > 0 , ERROR, "OpenOCD drove TCK", C_SCOPE);
    check_value(v_trst    , ERROR, "OpenOCD asserted TRST*", C_SCOPE);
    check_value(v_srst    , ERROR, "OpenOCD asserted SRST*", C_SCOPE);
    check_value(v_trst_ir , C_IR_USER, ERROR, "Instruction of the TAP before the last TRST* pulse (USER, tap.cfg)", C_SCOPE);
    check_value(v_trst_rst, ERROR, "The last TRST* pulse reset the TAP : Test-Logic-Reset, IDCODE instruction", C_SCOPE);
    if MODE = "pin"
    then
      check_value(v_min >= CLK_DIV*C_CLK_PERIOD, ERROR, "Pin changes " & integer'image(CLK_DIV) & " clock cycles apart at least (" & integer'image(v_min / 1 ns) & " ns)", C_SCOPE);
    else
      check_value(reads > 0 , ERROR, "OpenOCD read TDO ('R') : " & integer'image(reads) & " answers", C_SCOPE);
      check_value(v_blink   , ERROR, "OpenOCD switched the LED on ('B')", C_SCOPE);
    end if;
    report_alert_counters(FINAL);
    std.env.stop;
    wait;
  end process p_main;

end architecture sim;
