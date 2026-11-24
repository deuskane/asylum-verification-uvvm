-------------------------------------------------------------------------------
-- Title      : rbb_bfm_pkg
-- Project    : asylum-verification-uvvm
-------------------------------------------------------------------------------
-- File       : rbb_bfm_pkg.vhd
-- Author     : Mathieu Rosiere
-- Company    :
-- Created    : 2026-11-24
-- Platform   :
-- Standard   : VHDL'08
-------------------------------------------------------------------------------
-- Description:
--  OpenOCD remote_bitbang BFM in the style of the UVVM BFMs, library
--  asylum_uvvm : the testbench plays OpenOCD in front of a DUT that decodes
--  the remote_bitbang byte stream (a JTAG master such as jtag_bitbang of
--  asylum-debug-jtag). The procedures send the bytes the bitbang driver of
--  OpenOCD 0.12 sends :
--    write   '0'..'7' : TCK, TMS, TDI = bits 2, 1, 0
--    read    'R'      : the DUT answers '0' or '1' (TDO)
--    reset   'r'..'u' : TRST, SRST = bits 1, 0 (1 : asserted)
--    blink   'B' / 'b': LED on / off
--  TMS move : for each TMS bit, TCK low then high, then TCK low
--  (bitbang_state_move) ; scan : for each bit, TCK low with TMS and TDI,
--  'R', TCK high (bitbang_scan) ; vectors LSB first.
--  The scans have the meaning of jtag_write_ir / jtag_scan_dr /
--  jtag_check_dr of jtag_bfm_pkg, with a t_jtag_bfm_config for the chain
--  (ir_width, head_ir, tail_ir, head_dr, tail_dr, idle_cycles,
--  trst_enable, match_strictness) : from Run-Test/Idle to Run-Test/Idle.
--  Transport (t_rbb_bfm_config.uart) : the commands as an AXI-Stream
--  (rbb_if.tdata / tvalid / tready, driven on the falling edge of clk, one
--  byte per cycle at most) or as UART frames
--  on rbb_if.tx (UVVM UART BFM). The answers to 'R' are collected by a
--  concurrent monitor (rbb_axis_monitor or rbb_uart_monitor) in a
--  t_rbb_answers signal that the procedures read.
-------------------------------------------------------------------------------
-- Copyright (c) 2026
-------------------------------------------------------------------------------
-- Revisions  :
-- Date        Version  Author   Description
-- 2026-11-24  1.0      mrosiere Created from tb_bitbang_bfm_pkg
--                               (asylum-debug-jtag) and
--                               tb_PicoSoC_bitbang_pkg (asylum-soc-picosoc)
-------------------------------------------------------------------------------

library ieee;
use     ieee.std_logic_1164.all;
use     ieee.numeric_std.all;

library uvvm_util;
context uvvm_util.uvvm_util_context;

library bitvis_vip_uart;
use     bitvis_vip_uart.uart_bfm_pkg.all;

use     work.jtag_bfm_pkg.all;

package rbb_bfm_pkg is

  constant C_RBB_BFM_SCOPE : string   := "RBB BFM";

  -- Answers kept by the monitors : longer than the longest scan
  constant C_RBB_DEPTH     : positive := 1024;

  -- Commands to the DUT
  type t_rbb_if is record
    tdata                    : std_logic_vector(8-1 downto 0); -- to DUT : command byte (AXI-Stream)
    tvalid                   : std_logic;     -- to DUT
    tready                   : std_logic;     -- from DUT
    tx                       : std_logic;     -- to DUT : command bytes as UART frames (config.uart)
  end record t_rbb_if;

  -- Answers of the DUT to 'R', written by a monitor
  type t_rbb_answers is record
    cnt                      : natural;       -- Answers since the start of the simulation
    tdo                      : std_logic_vector(C_RBB_DEPTH-1 downto 0); -- The last answers, the last one in the LSB
  end record t_rbb_answers;

  constant C_RBB_ANSWERS_INIT : t_rbb_answers := (cnt => 0, tdo => (others => 'U'));

  type t_rbb_bfm_config is record
    uart                     : boolean;       -- false : commands on the AXI-Stream of rbb_if ; true : UART frames on rbb_if.tx
    uart_config              : t_uart_bfm_config; -- UART frames of the commands (and of the answers, rbb_uart_monitor)
    timeout                  : time;          -- Maximum wait of tready and of the answers to 'R'
    id_for_bfm               : t_msg_id;      -- Message ID of the BFM logs
  end record t_rbb_bfm_config;

  -- AXI-Stream, timeout 1 ms ; UART : 115200 baud, 8 bits, no parity, one
  -- stop bit, no log of each frame
  constant C_RBB_BFM_CONFIG_DEFAULT : t_rbb_bfm_config;

  -- Initial values of the signals of the interface : no command, tready at
  -- 'Z' (driven by the DUT), UART line idle
  function init_rbb_if_signals return t_rbb_if;

  -- Command bytes : write ('0'..'7'), reset ('r'..'u', 1 : asserted),
  -- blink ('B' / 'b'), as strings for rbb_command
  function rbb_write_cmd(tck, tms, tdi : std_logic) return string;
  function rbb_reset_cmd(trst, srst : std_logic) return string;
  function rbb_blink_cmd(led : std_logic) return string;

  -- Send the bytes of cmd, no wait for the answers
  procedure rbb_command(
    constant cmd           : in    string;
    constant msg           : in    string;
    signal   clk           : in    std_logic;
    signal   rbb_if        : inout t_rbb_if;
    constant scope         : in    string            := C_RBB_BFM_SCOPE;
    constant msg_id_panel  : in    t_msg_id_panel    := shared_msg_id_panel;
    constant config        : in    t_rbb_bfm_config  := C_RBB_BFM_CONFIG_DEFAULT;
    constant ext_proc_call : in    string            := ""  -- Set when called from another BFM procedure
    );

  -- 'R', then wait for its answer : TDO
  procedure rbb_read(
    variable tdo           : out   std_logic;
    constant msg           : in    string;
    signal   clk           : in    std_logic;
    signal   rbb_if        : inout t_rbb_if;
    signal   answers       : in    t_rbb_answers;
    constant scope         : in    string            := C_RBB_BFM_SCOPE;
    constant msg_id_panel  : in    t_msg_id_panel    := shared_msg_id_panel;
    constant config        : in    t_rbb_bfm_config  := C_RBB_BFM_CONFIG_DEFAULT
    );

  -- One TCK cycle per bit of tms (left first), TDI = 0, then TCK low
  procedure rbb_tms(
    constant tms           : in    std_logic_vector;
    constant msg           : in    string;
    signal   clk           : in    std_logic;
    signal   rbb_if        : inout t_rbb_if;
    constant scope         : in    string            := C_RBB_BFM_SCOPE;
    constant msg_id_panel  : in    t_msg_id_panel    := shared_msg_id_panel;
    constant config        : in    t_rbb_bfm_config  := C_RBB_BFM_CONFIG_DEFAULT;
    constant ext_proc_call : in    string            := ""  -- Set when called from another BFM procedure
    );

  -- Optional TRST ('t' then 'r', jtag_config.trst_enable), then 5 TCK with
  -- TMS = 1 (Test-Logic-Reset from any state), then Run-Test/Idle
  procedure rbb_reset(
    constant msg           : in    string;
    signal   clk           : in    std_logic;
    signal   rbb_if        : inout t_rbb_if;
    constant scope         : in    string            := C_RBB_BFM_SCOPE;
    constant msg_id_panel  : in    t_msg_id_panel    := shared_msg_id_panel;
    constant config        : in    t_rbb_bfm_config  := C_RBB_BFM_CONFIG_DEFAULT;
    constant jtag_config   : in    t_jtag_bfm_config := C_JTAG_BFM_CONFIG_DEFAULT
    );

  -- num_cycles TCK in Run-Test/Idle
  procedure rbb_idle(
    constant num_cycles    : in    natural;
    constant msg           : in    string;
    signal   clk           : in    std_logic;
    signal   rbb_if        : inout t_rbb_if;
    constant scope         : in    string            := C_RBB_BFM_SCOPE;
    constant msg_id_panel  : in    t_msg_id_panel    := shared_msg_id_panel;
    constant config        : in    t_rbb_bfm_config  := C_RBB_BFM_CONFIG_DEFAULT
    );

  -- IR scan of jtag_config.ir_width bits (target TAP), between
  -- jtag_config.head_ir and tail_ir ones (BYPASS of the other TAPs) ;
  -- checks the two LSB of the Capture-IR value of the target ("01")
  procedure rbb_write_ir(
    constant ir_value      : in    std_logic_vector;
    constant msg           : in    string;
    signal   clk           : in    std_logic;
    signal   rbb_if        : inout t_rbb_if;
    signal   answers       : in    t_rbb_answers;
    constant scope         : in    string            := C_RBB_BFM_SCOPE;
    constant msg_id_panel  : in    t_msg_id_panel    := shared_msg_id_panel;
    constant config        : in    t_rbb_bfm_config  := C_RBB_BFM_CONFIG_DEFAULT;
    constant jtag_config   : in    t_jtag_bfm_config := C_JTAG_BFM_CONFIG_DEFAULT
    );

  -- DR scan of data_value'length bits (target TAP), between
  -- jtag_config.head_dr and tail_dr zeros : the captured value of the
  -- target in data_out (same length)
  procedure rbb_scan_dr(
    constant data_value    : in    std_logic_vector;
    variable data_out      : out   std_logic_vector;
    constant msg           : in    string;
    signal   clk           : in    std_logic;
    signal   rbb_if        : inout t_rbb_if;
    signal   answers       : in    t_rbb_answers;
    constant scope         : in    string            := C_RBB_BFM_SCOPE;
    constant msg_id_panel  : in    t_msg_id_panel    := shared_msg_id_panel;
    constant config        : in    t_rbb_bfm_config  := C_RBB_BFM_CONFIG_DEFAULT;
    constant jtag_config   : in    t_jtag_bfm_config := C_JTAG_BFM_CONFIG_DEFAULT;
    constant ext_proc_call : in    string            := ""  -- Set when called from another BFM procedure
    );

  -- DR scan, then compare the captured value to data_exp ('-' : don't care
  -- bit)
  procedure rbb_check_dr(
    constant data_value    : in    std_logic_vector;
    constant data_exp      : in    std_logic_vector;
    constant msg           : in    string;
    signal   clk           : in    std_logic;
    signal   rbb_if        : inout t_rbb_if;
    signal   answers       : in    t_rbb_answers;
    constant alert_level   : in    t_alert_level     := error;
    constant scope         : in    string            := C_RBB_BFM_SCOPE;
    constant msg_id_panel  : in    t_msg_id_panel    := shared_msg_id_panel;
    constant config        : in    t_rbb_bfm_config  := C_RBB_BFM_CONFIG_DEFAULT;
    constant jtag_config   : in    t_jtag_bfm_config := C_JTAG_BFM_CONFIG_DEFAULT
    );

  -- Concurrent procedure (never returns) : one answer per rising edge of clk
  -- with tvalid and tready ; an answer other than '0' / '1' is an error
  procedure rbb_axis_monitor(
    signal   clk           : in    std_logic;
    signal   tdata         : in    std_logic_vector(8-1 downto 0);
    signal   tvalid        : in    std_logic;
    signal   tready        : in    std_logic;
    signal   answers       : out   t_rbb_answers;
    constant scope         : in    string            := C_RBB_BFM_SCOPE
    );

  -- Concurrent procedure (never returns) : answers received as UART frames
  -- (config.uart_config) on rx while stop = '0' (it waits for an idle line
  -- after stop falls) ; an answer other than '0' / '1' is an error
  procedure rbb_uart_monitor(
    signal   rx            : in    std_logic;
    signal   stop          : in    std_logic;
    signal   answers       : out   t_rbb_answers;
    constant scope         : in    string            := C_RBB_BFM_SCOPE;
    constant config        : in    t_rbb_bfm_config  := C_RBB_BFM_CONFIG_DEFAULT
    );

end package rbb_bfm_pkg;

package body rbb_bfm_pkg is

  function rbb_config_default return t_rbb_bfm_config is
    variable v_config : t_rbb_bfm_config;
  begin
    v_config.uart                    := false;
    v_config.uart_config             := C_UART_BFM_CONFIG_DEFAULT;
    v_config.uart_config.bit_time    := 1 sec / 115200;
    v_config.uart_config.parity      := PARITY_NONE;
    v_config.uart_config.id_for_bfm  := ID_NEVER;
    v_config.timeout                 := 1 ms;
    v_config.id_for_bfm              := ID_BFM;
    return v_config;
  end function rbb_config_default;

  constant C_RBB_BFM_CONFIG_DEFAULT : t_rbb_bfm_config := rbb_config_default;

  function init_rbb_if_signals return t_rbb_if is
    variable v_if : t_rbb_if;
  begin
    v_if.tdata   := x"00";
    v_if.tvalid  := '0';
    v_if.tready  := 'Z';
    v_if.tx      := '1';
    return v_if;
  end function init_rbb_if_signals;

  function rbb_write_cmd(tck, tms, tdi : std_logic) return string is
  begin
    return (1 => character'val(character'pos('0') + to_integer(unsigned'(tck & tms & tdi))));
  end function rbb_write_cmd;

  function rbb_reset_cmd(trst, srst : std_logic) return string is
  begin
    return (1 => character'val(character'pos('r') + to_integer(unsigned'(trst & srst))));
  end function rbb_reset_cmd;

  function rbb_blink_cmd(led : std_logic) return string is
  begin
    if led = '1'
    then
      return "B";
    end if;
    return "b";
  end function rbb_blink_cmd;

  -----------------------------------------------------------------------------
  -- Bytes of a TMS move (bitbang_state_move of OpenOCD)
  -----------------------------------------------------------------------------
  function tms_bytes(tms : std_logic_vector) return string is
    alias    v_tms   : std_logic_vector(0 to tms'length-1) is tms;
    variable v_bytes : string(1 to 2*tms'length+1);
  begin
    for i in v_tms'range loop
      v_bytes(2*i+1 to 2*i+2) := rbb_write_cmd('0', v_tms(i), '0') & rbb_write_cmd('1', v_tms(i), '0');
    end loop;
    v_bytes(v_bytes'high) := rbb_write_cmd('0', v_tms(v_tms'high), '0')(1);
    return v_bytes;
  end function tms_bytes;

  -----------------------------------------------------------------------------
  -- rbb_command
  -----------------------------------------------------------------------------
  procedure rbb_command(
    constant cmd           : in    string;
    constant msg           : in    string;
    signal   clk           : in    std_logic;
    signal   rbb_if        : inout t_rbb_if;
    constant scope         : in    string            := C_RBB_BFM_SCOPE;
    constant msg_id_panel  : in    t_msg_id_panel    := shared_msg_id_panel;
    constant config        : in    t_rbb_bfm_config  := C_RBB_BFM_CONFIG_DEFAULT;
    constant ext_proc_call : in    string            := ""
    ) is
    constant proc_call : string := "rbb_command(""" & cmd & """)";
    variable v_byte    : std_logic_vector(8-1 downto 0);
  begin
    for i in cmd'range loop
      v_byte := std_logic_vector(to_unsigned(character'pos(cmd(i)), 8));
      if config.uart
      then
        uart_transmit(v_byte, proc_call, rbb_if.tx, config.uart_config, scope, msg_id_panel);
      else
        -- Driven on the falling edge of clk, taken on a rising edge
        wait until falling_edge(clk);
        rbb_if.tdata  <= v_byte;
        rbb_if.tvalid <= '1';
        wait until rising_edge(clk) and rbb_if.tready = '1' for config.timeout;
        rbb_if.tvalid <= '0';
        if not (rising_edge(clk) and rbb_if.tready = '1')
        then
          alert(error, proc_call & " byte x" & to_hstring(v_byte) & " not taken (tready low). " & add_msg_delimiter(msg), scope);
          return;
        end if;
      end if;
    end loop;
    if ext_proc_call = ""
    then
      log(config.id_for_bfm, proc_call & " completed. " & add_msg_delimiter(msg), scope, msg_id_panel);
    end if;
  end procedure rbb_command;

  -----------------------------------------------------------------------------
  -- Wait until num answers were received since first ; false and an alert
  -- after config.timeout
  -----------------------------------------------------------------------------
  procedure wait_answers(
    constant first         : in    natural;
    constant num           : in    natural;
    constant proc_call     : in    string;
    constant msg           : in    string;
    signal   answers       : in    t_rbb_answers;
    constant scope         : in    string;
    constant config        : in    t_rbb_bfm_config;
    variable ok            : out   boolean
    ) is
  begin
    if answers.cnt < first + num
    then
      wait until answers.cnt >= first + num for config.timeout;
    end if;
    ok := answers.cnt = first + num;
    if answers.cnt /= first + num
    then
      alert(error, proc_call & " " & integer'image(answers.cnt - first) & " answers to 'R' instead of " & integer'image(num) & ". " & add_msg_delimiter(msg), scope);
    end if;
  end procedure wait_answers;

  -----------------------------------------------------------------------------
  -- rbb_read
  -----------------------------------------------------------------------------
  procedure rbb_read(
    variable tdo           : out   std_logic;
    constant msg           : in    string;
    signal   clk           : in    std_logic;
    signal   rbb_if        : inout t_rbb_if;
    signal   answers       : in    t_rbb_answers;
    constant scope         : in    string            := C_RBB_BFM_SCOPE;
    constant msg_id_panel  : in    t_msg_id_panel    := shared_msg_id_panel;
    constant config        : in    t_rbb_bfm_config  := C_RBB_BFM_CONFIG_DEFAULT
    ) is
    constant proc_call : string  := "rbb_read()";
    constant C_FIRST   : natural := answers.cnt;
    variable v_ok      : boolean;
  begin
    rbb_command("R", msg, clk, rbb_if, scope, msg_id_panel, config, proc_call);
    wait_answers(C_FIRST, 1, proc_call, msg, answers, scope, config, v_ok);
    tdo := answers.tdo(0) when v_ok else 'X';
    log(config.id_for_bfm, proc_call & "=> " & to_string(answers.tdo(0)) & ". " & add_msg_delimiter(msg), scope, msg_id_panel);
  end procedure rbb_read;

  -----------------------------------------------------------------------------
  -- rbb_tms
  -----------------------------------------------------------------------------
  procedure rbb_tms(
    constant tms           : in    std_logic_vector;
    constant msg           : in    string;
    signal   clk           : in    std_logic;
    signal   rbb_if        : inout t_rbb_if;
    constant scope         : in    string            := C_RBB_BFM_SCOPE;
    constant msg_id_panel  : in    t_msg_id_panel    := shared_msg_id_panel;
    constant config        : in    t_rbb_bfm_config  := C_RBB_BFM_CONFIG_DEFAULT;
    constant ext_proc_call : in    string            := ""
    ) is
    constant proc_call : string := "rbb_tms(" & to_string(tms) & ")";
  begin
    if tms'length > 0
    then
      rbb_command(tms_bytes(tms), msg, clk, rbb_if, scope, msg_id_panel, config, proc_call);
    end if;
    if ext_proc_call = ""
    then
      log(config.id_for_bfm, proc_call & " completed. " & add_msg_delimiter(msg), scope, msg_id_panel);
    end if;
  end procedure rbb_tms;

  -----------------------------------------------------------------------------
  -- rbb_reset
  -----------------------------------------------------------------------------
  procedure rbb_reset(
    constant msg           : in    string;
    signal   clk           : in    std_logic;
    signal   rbb_if        : inout t_rbb_if;
    constant scope         : in    string            := C_RBB_BFM_SCOPE;
    constant msg_id_panel  : in    t_msg_id_panel    := shared_msg_id_panel;
    constant config        : in    t_rbb_bfm_config  := C_RBB_BFM_CONFIG_DEFAULT;
    constant jtag_config   : in    t_jtag_bfm_config := C_JTAG_BFM_CONFIG_DEFAULT
    ) is
    constant proc_call : string := "rbb_reset()";
  begin
    if jtag_config.trst_enable
    then
      rbb_command(rbb_reset_cmd('1', '0') & rbb_reset_cmd('0', '0'), msg, clk, rbb_if, scope, msg_id_panel, config, proc_call);
    end if;
    rbb_tms("111110", msg, clk, rbb_if, scope, msg_id_panel, config, proc_call);
    log(config.id_for_bfm, proc_call & " completed. " & add_msg_delimiter(msg), scope, msg_id_panel);
  end procedure rbb_reset;

  -----------------------------------------------------------------------------
  -- rbb_idle
  -----------------------------------------------------------------------------
  procedure rbb_idle(
    constant num_cycles    : in    natural;
    constant msg           : in    string;
    signal   clk           : in    std_logic;
    signal   rbb_if        : inout t_rbb_if;
    constant scope         : in    string            := C_RBB_BFM_SCOPE;
    constant msg_id_panel  : in    t_msg_id_panel    := shared_msg_id_panel;
    constant config        : in    t_rbb_bfm_config  := C_RBB_BFM_CONFIG_DEFAULT
    ) is
    constant proc_call : string := "rbb_idle(" & to_string(num_cycles) & ")";
    constant C_ZEROS   : std_logic_vector(1 to num_cycles) := (others => '0');
  begin
    rbb_tms(C_ZEROS, msg, clk, rbb_if, scope, msg_id_panel, config, proc_call);
    log(config.id_for_bfm, proc_call & " completed. " & add_msg_delimiter(msg), scope, msg_id_panel);
  end procedure rbb_idle;

  -----------------------------------------------------------------------------
  -- IR scan (ir = true) or DR scan, from Run-Test/Idle to Run-Test/Idle, of
  -- the target TAP of the chain : bytes of the head bits, of the bits of
  -- the target and of the tail bits, then the answers of the target bits
  -----------------------------------------------------------------------------
  procedure rbb_scan(
    constant ir            : in    boolean;
    constant data_value    : in    std_logic_vector;
    variable data_out      : out   std_logic_vector;
    constant proc_call     : in    string;
    constant msg           : in    string;
    signal   clk           : in    std_logic;
    signal   rbb_if        : inout t_rbb_if;
    signal   answers       : in    t_rbb_answers;
    constant scope         : in    string;
    constant msg_id_panel  : in    t_msg_id_panel;
    constant config        : in    t_rbb_bfm_config;
    constant jtag_config   : in    t_jtag_bfm_config
    ) is
    alias    v_data_value  : std_logic_vector(data_value'length-1 downto 0) is data_value;
    variable v_data_out    : std_logic_vector(data_value'length-1 downto 0) := (others => 'X');
    variable v_head        : natural;    -- Bits of the TAPs between the target and TDO
    variable v_tail        : natural;    -- Bits of the TAPs between TDI and the target
    variable v_pad         : std_logic;  -- Value shifted into the other TAPs
    variable v_nb          : natural;
    variable v_tms         : std_logic;
    variable v_tdi         : std_logic;
    variable v_ok          : boolean;
    constant C_FIRST       : natural := answers.cnt;
    constant C_IDLE        : std_logic_vector(1 to jtag_config.idle_cycles) := (others => '0');
  begin
    if ir
    then
      v_head := jtag_config.head_ir;
      v_tail := jtag_config.tail_ir;
      v_pad  := '1';  -- BYPASS (all zeros is EXTEST)
    else
      v_head := jtag_config.head_dr;
      v_tail := jtag_config.tail_dr;
      v_pad  := '0';
    end if;
    v_nb := v_head + v_data_value'length + v_tail;
    if v_nb > C_RBB_DEPTH
    then
      alert(TB_ERROR, proc_call & " scan of " & integer'image(v_nb) & " bits, longer than C_RBB_DEPTH. " & add_msg_delimiter(msg), scope);
      return;
    end if;

    -- Run-Test/Idle -> Select-DR-Scan (-> Select-IR-Scan) -> Capture -> Shift
    if ir
    then
      rbb_tms("1100", msg, clk, rbb_if, scope, msg_id_panel, config, proc_call);
    else
      rbb_tms("100" , msg, clk, rbb_if, scope, msg_id_panel, config, proc_call);
    end if;

    -- Shift, LSB first : the head bits, the bits of the target, the tail
    -- bits ; the last bit with TMS = 1 (-> Exit1)
    for i in 0 to v_nb-1 loop
      v_tms := '1' when i = v_nb-1 else '0';
      if ((i >= v_head) and
          (i <  v_head + v_data_value'length))
      then
        v_tdi := v_data_value(i-v_head);
      else
        v_tdi := v_pad;
      end if;
      rbb_command(rbb_write_cmd('0', v_tms, v_tdi) & "R" & rbb_write_cmd('1', v_tms, v_tdi), msg, clk, rbb_if, scope, msg_id_panel, config, proc_call);
    end loop;

    -- Exit1 -> Update -> Run-Test/Idle, then the idle cycles
    rbb_tms("10" & C_IDLE, msg, clk, rbb_if, scope, msg_id_panel, config, proc_call);

    -- Answers : bit i of the scan is the answer C_FIRST+i
    wait_answers(C_FIRST, v_nb, proc_call, msg, answers, scope, config, v_ok);
    if v_ok
    then
      for i in v_data_out'range loop
        v_data_out(i) := answers.tdo(v_nb-1-(v_head+i));
      end loop;
    end if;
    data_out := v_data_out;
  end procedure rbb_scan;

  -----------------------------------------------------------------------------
  -- rbb_write_ir
  -----------------------------------------------------------------------------
  procedure rbb_write_ir(
    constant ir_value      : in    std_logic_vector;
    constant msg           : in    string;
    signal   clk           : in    std_logic;
    signal   rbb_if        : inout t_rbb_if;
    signal   answers       : in    t_rbb_answers;
    constant scope         : in    string            := C_RBB_BFM_SCOPE;
    constant msg_id_panel  : in    t_msg_id_panel    := shared_msg_id_panel;
    constant config        : in    t_rbb_bfm_config  := C_RBB_BFM_CONFIG_DEFAULT;
    constant jtag_config   : in    t_jtag_bfm_config := C_JTAG_BFM_CONFIG_DEFAULT
    ) is
    constant proc_call : string := "rbb_write_ir(" & to_string(ir_value, HEX, AS_IS, INCL_RADIX) & ")";
    variable v_ir      : std_logic_vector(jtag_config.ir_width-1 downto 0);
    variable v_capture : std_logic_vector(jtag_config.ir_width-1 downto 0);
  begin
    v_ir := normalize_and_check(ir_value, v_ir, ALLOW_WIDER_NARROWER, "ir_value", "jtag_config.ir_width", msg);
    rbb_scan(true, v_ir, v_capture, proc_call, msg, clk, rbb_if, answers, scope, msg_id_panel, config, jtag_config);
    check_value(value => v_capture(1 downto 0), exp => "01", alert_level => error, msg => proc_call & " Capture-IR. " & add_msg_delimiter(msg),
                scope => scope, msg_id => ID_NEVER, msg_id_panel => msg_id_panel);
    log(config.id_for_bfm, proc_call & " completed. " & add_msg_delimiter(msg), scope, msg_id_panel);
  end procedure rbb_write_ir;

  -----------------------------------------------------------------------------
  -- rbb_scan_dr
  -----------------------------------------------------------------------------
  procedure rbb_scan_dr(
    constant data_value    : in    std_logic_vector;
    variable data_out      : out   std_logic_vector;
    constant msg           : in    string;
    signal   clk           : in    std_logic;
    signal   rbb_if        : inout t_rbb_if;
    signal   answers       : in    t_rbb_answers;
    constant scope         : in    string            := C_RBB_BFM_SCOPE;
    constant msg_id_panel  : in    t_msg_id_panel    := shared_msg_id_panel;
    constant config        : in    t_rbb_bfm_config  := C_RBB_BFM_CONFIG_DEFAULT;
    constant jtag_config   : in    t_jtag_bfm_config := C_JTAG_BFM_CONFIG_DEFAULT;
    constant ext_proc_call : in    string            := ""
    ) is
    constant local_proc_call : string := "rbb_scan_dr(" & to_string(data_value, HEX, AS_IS, INCL_RADIX) & ")";
    variable v_data_out      : std_logic_vector(data_value'length-1 downto 0);
  begin
    check_value(data_out'length = data_value'length, TB_ERROR, local_proc_call & " data_out and data_value of the same length. " & add_msg_delimiter(msg), scope, ID_NEVER, msg_id_panel);
    rbb_scan(false, data_value, v_data_out, local_proc_call, msg, clk, rbb_if, answers, scope, msg_id_panel, config, jtag_config);
    if ext_proc_call = ""
    then
      log(config.id_for_bfm, local_proc_call & "=> " & to_string(v_data_out, HEX, AS_IS, INCL_RADIX) & ". " & add_msg_delimiter(msg), scope, msg_id_panel);
    end if;
    data_out := v_data_out;
  end procedure rbb_scan_dr;

  -----------------------------------------------------------------------------
  -- rbb_check_dr
  -----------------------------------------------------------------------------
  procedure rbb_check_dr(
    constant data_value    : in    std_logic_vector;
    constant data_exp      : in    std_logic_vector;
    constant msg           : in    string;
    signal   clk           : in    std_logic;
    signal   rbb_if        : inout t_rbb_if;
    signal   answers       : in    t_rbb_answers;
    constant alert_level   : in    t_alert_level     := error;
    constant scope         : in    string            := C_RBB_BFM_SCOPE;
    constant msg_id_panel  : in    t_msg_id_panel    := shared_msg_id_panel;
    constant config        : in    t_rbb_bfm_config  := C_RBB_BFM_CONFIG_DEFAULT;
    constant jtag_config   : in    t_jtag_bfm_config := C_JTAG_BFM_CONFIG_DEFAULT
    ) is
    constant proc_call  : string := "rbb_check_dr(" & to_string(data_value, HEX, AS_IS, INCL_RADIX) & ", " & to_string(data_exp, HEX, AS_IS, INCL_RADIX) & ")";
    variable v_data_exp : std_logic_vector(data_value'length-1 downto 0);
    variable v_data_out : std_logic_vector(data_value'length-1 downto 0);
    variable v_check_ok : boolean := true;
  begin
    v_data_exp := normalize_and_check(data_exp, v_data_exp, ALLOW_EXACT_ONLY, "data_exp", "data_value", msg);
    rbb_scan_dr(data_value, v_data_out, msg, clk, rbb_if, answers, scope, msg_id_panel, config, jtag_config, proc_call);

    for i in v_data_exp'range loop
      if not (v_data_exp(i) = '-' or check_value(v_data_out(i), v_data_exp(i), jtag_config.match_strictness, NO_ALERT, msg, scope, ID_NEVER))
      then
        v_check_ok := false;
        exit;
      end if;
    end loop;

    if v_check_ok
    then
      log(config.id_for_bfm, proc_call & "=> OK, captured data = " & to_string(v_data_out, HEX, AS_IS, INCL_RADIX) & ". " & add_msg_delimiter(msg), scope, msg_id_panel);
    else
      alert(alert_level, proc_call & "=> Failed. Was " & to_string(v_data_out, HEX, AS_IS, INCL_RADIX) & ". Expected " & to_string(v_data_exp, HEX, AS_IS, INCL_RADIX) & "." & LF & add_msg_delimiter(msg), scope);
    end if;
  end procedure rbb_check_dr;

  -----------------------------------------------------------------------------
  -- One answer : '0' or '1', shifted in the LSB
  -----------------------------------------------------------------------------
  procedure add_answer(
    constant byte          : in    std_logic_vector(8-1 downto 0);
    variable v_answers     : inout t_rbb_answers;
    signal   answers       : out   t_rbb_answers;
    constant scope         : in    string
    ) is
  begin
    if byte /= x"30" and byte /= x"31"
    then
      alert(error, "Answer x" & to_hstring(byte) & " to 'R' is not '0' or '1'", scope);
    end if;
    v_answers.cnt := v_answers.cnt + 1;
    v_answers.tdo := v_answers.tdo(C_RBB_DEPTH-2 downto 0) & byte(0);
    answers       <= v_answers;
  end procedure add_answer;

  -----------------------------------------------------------------------------
  -- rbb_axis_monitor
  -----------------------------------------------------------------------------
  procedure rbb_axis_monitor(
    signal   clk           : in    std_logic;
    signal   tdata         : in    std_logic_vector(8-1 downto 0);
    signal   tvalid        : in    std_logic;
    signal   tready        : in    std_logic;
    signal   answers       : out   t_rbb_answers;
    constant scope         : in    string            := C_RBB_BFM_SCOPE
    ) is
    variable v_answers     : t_rbb_answers := C_RBB_ANSWERS_INIT;
  begin
    answers <= v_answers;
    loop
      wait until rising_edge(clk);
      if tvalid = '1' and tready = '1'
      then
        add_answer(tdata, v_answers, answers, scope);
      end if;
    end loop;
  end procedure rbb_axis_monitor;

  -----------------------------------------------------------------------------
  -- rbb_uart_monitor
  -----------------------------------------------------------------------------
  procedure rbb_uart_monitor(
    signal   rx            : in    std_logic;
    signal   stop          : in    std_logic;
    signal   answers       : out   t_rbb_answers;
    constant scope         : in    string            := C_RBB_BFM_SCOPE;
    constant config        : in    t_rbb_bfm_config  := C_RBB_BFM_CONFIG_DEFAULT
    ) is
    variable v_answers     : t_rbb_answers := C_RBB_ANSWERS_INIT;
    variable v_byte        : std_logic_vector(8-1 downto 0);
  begin
    answers <= v_answers;
    loop
      -- Idle line while the answers are expected
      if not (stop = '0' and to_X01(rx) = '1')
      then
        wait until stop = '0' and to_X01(rx) = '1';
      end if;
      uart_receive(v_byte, "Answer to 'R'", rx, stop, config.uart_config, scope);
      if stop = '0'
      then
        add_answer(v_byte, v_answers, answers, scope);
      end if;
    end loop;
  end procedure rbb_uart_monitor;

end package body rbb_bfm_pkg;
