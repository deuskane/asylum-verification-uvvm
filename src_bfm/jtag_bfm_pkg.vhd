-------------------------------------------------------------------------------
-- Title      : jtag_bfm_pkg
-- Project    : asylum-verification-uvvm
-------------------------------------------------------------------------------
-- File       : jtag_bfm_pkg.vhd
-- Author     : Mathieu Rosiere
-- Company    :
-- Created    : 2026-11-22
-- Platform   :
-- Standard   : VHDL'08
-------------------------------------------------------------------------------
-- Description:
--  IEEE 1149.1 JTAG master BFM in the style of the UVVM BFMs (UVVM has no
--  JTAG VIP), library asylum_uvvm : jtag_reset / jtag_idle / jtag_write_ir /
--  jtag_scan_dr / jtag_check_dr with msg, interface record t_jtag_if and
--  configuration t_jtag_bfm_config, uvvm_util logs and alerts.
--  The BFM drives TCK itself (period config.tck_period). In each TCK cycle,
--  TCK falls and TMS / TDI change, then TDO is sampled just before the
--  rising edge (the TAP samples TMS and TDI on the rising edge and changes
--  TDO on the falling edge). Vectors are shifted LSB first.
--  jtag_reset ends in Run-Test/Idle ; every scan starts and ends in
--  Run-Test/Idle. TCK stays high between two procedures.
-------------------------------------------------------------------------------
-- Copyright (c) 2026
-------------------------------------------------------------------------------
-- Revisions  :
-- Date        Version  Author   Description
-- 2026-11-22  1.0      mrosiere Created from the JTAG procedures of
--                               WardRV_vips (WardRV debug unit)
-------------------------------------------------------------------------------

library ieee;
use     ieee.std_logic_1164.all;

library uvvm_util;
context uvvm_util.uvvm_util_context;

package jtag_bfm_pkg is

  constant C_JTAG_BFM_SCOPE : string := "JTAG BFM";

  type t_jtag_if is record
    tck                      : std_logic;     -- to DUT
    tms                      : std_logic;     -- to DUT
    tdi                      : std_logic;     -- to DUT
    trst_b                   : std_logic;     -- to DUT (optional, config.trst_enable)
    tdo                      : std_logic;     -- from DUT
  end record t_jtag_if;

  type t_jtag_bfm_config is record
    tck_period               : time;          -- Period of TCK
    ir_width                 : positive;      -- Width of the instruction register (>= 2)
    idle_cycles              : natural;       -- Extra Run-Test/Idle cycles at the end of each scan
    trst_enable              : boolean;       -- jtag_reset pulses trst_b before the TMS sequence
    match_strictness         : t_match_strictness; -- Matching strictness of std_logic values in jtag_check_dr
    id_for_bfm               : t_msg_id;      -- Message ID of the BFM logs
  end record t_jtag_bfm_config;

  constant C_JTAG_BFM_CONFIG_DEFAULT : t_jtag_bfm_config := (
    tck_period               => 100 ns,
    ir_width                 => 5,
    idle_cycles              => 0,
    trst_enable              => true,
    match_strictness         => MATCH_EXACT,
    id_for_bfm               => ID_BFM
    );

  -- Initial values of the signals of the interface : TCK low, TMS high
  -- (Test-Logic-Reset is kept), trst_b inactive, TDO at 'Z' (driven by the
  -- DUT)
  function init_jtag_if_signals return t_jtag_if;

  -- Optional TRST* pulse (config.trst_enable), then 5 TCK with TMS = 1
  -- (Test-Logic-Reset from any state), then Run-Test/Idle
  procedure jtag_reset(
    constant msg           : in    string;
    signal   jtag_if       : inout t_jtag_if;
    constant scope         : in    string            := C_JTAG_BFM_SCOPE;
    constant msg_id_panel  : in    t_msg_id_panel    := shared_msg_id_panel;
    constant config        : in    t_jtag_bfm_config := C_JTAG_BFM_CONFIG_DEFAULT
    );

  -- num_cycles TCK in Run-Test/Idle
  procedure jtag_idle(
    constant num_cycles    : in    natural;
    constant msg           : in    string;
    signal   jtag_if       : inout t_jtag_if;
    constant scope         : in    string            := C_JTAG_BFM_SCOPE;
    constant msg_id_panel  : in    t_msg_id_panel    := shared_msg_id_panel;
    constant config        : in    t_jtag_bfm_config := C_JTAG_BFM_CONFIG_DEFAULT
    );

  -- IR scan of config.ir_width bits ; checks the two LSB of the Capture-IR
  -- value ("01", IEEE 1149.1)
  procedure jtag_write_ir(
    constant ir_value      : in    std_logic_vector;
    constant msg           : in    string;
    signal   jtag_if       : inout t_jtag_if;
    constant scope         : in    string            := C_JTAG_BFM_SCOPE;
    constant msg_id_panel  : in    t_msg_id_panel    := shared_msg_id_panel;
    constant config        : in    t_jtag_bfm_config := C_JTAG_BFM_CONFIG_DEFAULT
    );

  -- DR scan of data_value'length bits : data_value is shifted in, the
  -- captured value is shifted out to data_out (same length)
  procedure jtag_scan_dr(
    constant data_value    : in    std_logic_vector;
    variable data_out      : out   std_logic_vector;
    constant msg           : in    string;
    signal   jtag_if       : inout t_jtag_if;
    constant scope         : in    string            := C_JTAG_BFM_SCOPE;
    constant msg_id_panel  : in    t_msg_id_panel    := shared_msg_id_panel;
    constant config        : in    t_jtag_bfm_config := C_JTAG_BFM_CONFIG_DEFAULT;
    constant ext_proc_call : in    string            := ""  -- Set when called from another BFM procedure
    );

  -- DR scan, then compare the captured value to data_exp ('-' : don't care
  -- bit)
  procedure jtag_check_dr(
    constant data_value    : in    std_logic_vector;
    constant data_exp      : in    std_logic_vector;
    constant msg           : in    string;
    signal   jtag_if       : inout t_jtag_if;
    constant alert_level   : in    t_alert_level     := error;
    constant scope         : in    string            := C_JTAG_BFM_SCOPE;
    constant msg_id_panel  : in    t_msg_id_panel    := shared_msg_id_panel;
    constant config        : in    t_jtag_bfm_config := C_JTAG_BFM_CONFIG_DEFAULT
    );

end package jtag_bfm_pkg;

package body jtag_bfm_pkg is

  function init_jtag_if_signals return t_jtag_if is
    variable v_if : t_jtag_if;
  begin
    v_if.tck     := '0';
    v_if.tms     := '1';
    v_if.tdi     := '0';
    v_if.trst_b  := '1';
    v_if.tdo     := 'Z';
    return v_if;
  end function init_jtag_if_signals;

  -----------------------------------------------------------------------------
  -- One TCK cycle : TCK falls with the new TMS and TDI, TDO is sampled just
  -- before the rising edge
  -----------------------------------------------------------------------------
  procedure jtag_clock(
    constant tms           : in    std_logic;
    constant tdi           : in    std_logic;
    variable tdo           : out   std_logic;
    signal   jtag_if       : inout t_jtag_if;
    constant config        : in    t_jtag_bfm_config
    ) is
  begin
    jtag_if.tck  <= '0';
    jtag_if.tms  <= tms;
    jtag_if.tdi  <= tdi;
    wait for config.tck_period/2;
    tdo          := jtag_if.tdo;
    jtag_if.tck  <= '1';
    wait for config.tck_period/2;
  end procedure jtag_clock;

  -----------------------------------------------------------------------------
  -- IR scan (ir = true) or DR scan, from Run-Test/Idle to Run-Test/Idle
  -----------------------------------------------------------------------------
  procedure jtag_scan(
    constant ir            : in    boolean;
    constant data_value    : in    std_logic_vector;
    variable data_out      : out   std_logic_vector;
    signal   jtag_if       : inout t_jtag_if;
    constant config        : in    t_jtag_bfm_config
    ) is
    alias    v_data_value  : std_logic_vector(data_value'length-1 downto 0) is data_value;
    variable v_data_out    : std_logic_vector(data_value'length-1 downto 0);
    variable v_tms         : std_logic;
    variable v_tdo         : std_logic;
  begin
    -- Run-Test/Idle -> Select-DR-Scan (-> Select-IR-Scan) -> Capture -> Shift
    jtag_clock('1', '0', v_tdo, jtag_if, config);
    if ir
    then
      jtag_clock('1', '0', v_tdo, jtag_if, config);
    end if;
    jtag_clock('0', '0', v_tdo, jtag_if, config);
    jtag_clock('0', '0', v_tdo, jtag_if, config);

    -- Shift, LSB first, the last bit with TMS = 1 (-> Exit1)
    for i in 0 to v_data_value'length-1 loop
      v_tms := '1' when i = v_data_value'length-1 else '0';
      jtag_clock(v_tms, v_data_value(i), v_data_out(i), jtag_if, config);
    end loop;

    -- Exit1 -> Update -> Run-Test/Idle, then the idle cycles
    jtag_clock('1', '0', v_tdo, jtag_if, config);
    jtag_clock('0', '0', v_tdo, jtag_if, config);
    for i in 1 to config.idle_cycles loop
      jtag_clock('0', '0', v_tdo, jtag_if, config);
    end loop;
    data_out := v_data_out;
  end procedure jtag_scan;

  -----------------------------------------------------------------------------
  -- jtag_reset
  -----------------------------------------------------------------------------
  procedure jtag_reset(
    constant msg           : in    string;
    signal   jtag_if       : inout t_jtag_if;
    constant scope         : in    string            := C_JTAG_BFM_SCOPE;
    constant msg_id_panel  : in    t_msg_id_panel    := shared_msg_id_panel;
    constant config        : in    t_jtag_bfm_config := C_JTAG_BFM_CONFIG_DEFAULT
    ) is
    constant proc_call : string := "jtag_reset()";
    variable v_tdo     : std_logic;
  begin
    if config.trst_enable
    then
      jtag_if.tck    <= '0';
      jtag_if.tms    <= '1';
      jtag_if.trst_b <= '0';
      wait for config.tck_period;
      jtag_if.trst_b <= '1';
      wait for config.tck_period;
    end if;
    for i in 1 to 5 loop
      jtag_clock('1', '0', v_tdo, jtag_if, config);
    end loop;
    jtag_clock('0', '0', v_tdo, jtag_if, config);
    log(config.id_for_bfm, proc_call & " completed. " & add_msg_delimiter(msg), scope, msg_id_panel);
  end procedure jtag_reset;

  -----------------------------------------------------------------------------
  -- jtag_idle
  -----------------------------------------------------------------------------
  procedure jtag_idle(
    constant num_cycles    : in    natural;
    constant msg           : in    string;
    signal   jtag_if       : inout t_jtag_if;
    constant scope         : in    string            := C_JTAG_BFM_SCOPE;
    constant msg_id_panel  : in    t_msg_id_panel    := shared_msg_id_panel;
    constant config        : in    t_jtag_bfm_config := C_JTAG_BFM_CONFIG_DEFAULT
    ) is
    constant proc_call : string := "jtag_idle(" & to_string(num_cycles) & ")";
    variable v_tdo     : std_logic;
  begin
    for i in 1 to num_cycles loop
      jtag_clock('0', '0', v_tdo, jtag_if, config);
    end loop;
    log(config.id_for_bfm, proc_call & " completed. " & add_msg_delimiter(msg), scope, msg_id_panel);
  end procedure jtag_idle;

  -----------------------------------------------------------------------------
  -- jtag_write_ir
  -----------------------------------------------------------------------------
  procedure jtag_write_ir(
    constant ir_value      : in    std_logic_vector;
    constant msg           : in    string;
    signal   jtag_if       : inout t_jtag_if;
    constant scope         : in    string            := C_JTAG_BFM_SCOPE;
    constant msg_id_panel  : in    t_msg_id_panel    := shared_msg_id_panel;
    constant config        : in    t_jtag_bfm_config := C_JTAG_BFM_CONFIG_DEFAULT
    ) is
    constant proc_call : string := "jtag_write_ir(" & to_string(ir_value, HEX, AS_IS, INCL_RADIX) & ")";
    variable v_ir      : std_logic_vector(config.ir_width-1 downto 0);
    variable v_capture : std_logic_vector(config.ir_width-1 downto 0);
  begin
    v_ir := normalize_and_check(ir_value, v_ir, ALLOW_WIDER_NARROWER, "ir_value", "config.ir_width", msg);
    jtag_scan(true, v_ir, v_capture, jtag_if, config);
    check_value(value => v_capture(1 downto 0), exp => "01", alert_level => error, msg => proc_call & " Capture-IR. " & add_msg_delimiter(msg),
                scope => scope, msg_id => ID_NEVER, msg_id_panel => msg_id_panel);
    log(config.id_for_bfm, proc_call & " completed. " & add_msg_delimiter(msg), scope, msg_id_panel);
  end procedure jtag_write_ir;

  -----------------------------------------------------------------------------
  -- jtag_scan_dr
  -----------------------------------------------------------------------------
  procedure jtag_scan_dr(
    constant data_value    : in    std_logic_vector;
    variable data_out      : out   std_logic_vector;
    constant msg           : in    string;
    signal   jtag_if       : inout t_jtag_if;
    constant scope         : in    string            := C_JTAG_BFM_SCOPE;
    constant msg_id_panel  : in    t_msg_id_panel    := shared_msg_id_panel;
    constant config        : in    t_jtag_bfm_config := C_JTAG_BFM_CONFIG_DEFAULT;
    constant ext_proc_call : in    string            := ""
    ) is
    constant local_proc_call : string := "jtag_scan_dr(" & to_string(data_value, HEX, AS_IS, INCL_RADIX) & ")";
    variable v_data_out      : std_logic_vector(data_value'length-1 downto 0);
  begin
    check_value(data_out'length = data_value'length, TB_ERROR, local_proc_call & " data_out and data_value of the same length. " & add_msg_delimiter(msg), scope, ID_NEVER, msg_id_panel);
    jtag_scan(false, data_value, v_data_out, jtag_if, config);
    if ext_proc_call = ""
    then
      log(config.id_for_bfm, local_proc_call & "=> " & to_string(v_data_out, HEX, AS_IS, INCL_RADIX) & ". " & add_msg_delimiter(msg), scope, msg_id_panel);
    end if;
    data_out := v_data_out;
  end procedure jtag_scan_dr;

  -----------------------------------------------------------------------------
  -- jtag_check_dr
  -----------------------------------------------------------------------------
  procedure jtag_check_dr(
    constant data_value    : in    std_logic_vector;
    constant data_exp      : in    std_logic_vector;
    constant msg           : in    string;
    signal   jtag_if       : inout t_jtag_if;
    constant alert_level   : in    t_alert_level     := error;
    constant scope         : in    string            := C_JTAG_BFM_SCOPE;
    constant msg_id_panel  : in    t_msg_id_panel    := shared_msg_id_panel;
    constant config        : in    t_jtag_bfm_config := C_JTAG_BFM_CONFIG_DEFAULT
    ) is
    constant proc_call  : string := "jtag_check_dr(" & to_string(data_value, HEX, AS_IS, INCL_RADIX) & ", " & to_string(data_exp, HEX, AS_IS, INCL_RADIX) & ")";
    variable v_data_exp : std_logic_vector(data_value'length-1 downto 0);
    variable v_data_out : std_logic_vector(data_value'length-1 downto 0);
    variable v_check_ok : boolean := true;
  begin
    v_data_exp := normalize_and_check(data_exp, v_data_exp, ALLOW_EXACT_ONLY, "data_exp", "data_value", msg);
    jtag_scan_dr(data_value, v_data_out, msg, jtag_if, scope, msg_id_panel, config, proc_call);

    for i in v_data_exp'range loop
      if not (v_data_exp(i) = '-' or check_value(v_data_out(i), v_data_exp(i), config.match_strictness, NO_ALERT, msg, scope, ID_NEVER))
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
  end procedure jtag_check_dr;

end package body jtag_bfm_pkg;
