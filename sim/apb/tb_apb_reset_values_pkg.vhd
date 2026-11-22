-------------------------------------------------------------------------------
-- Title      : tb_apb_reset_values_pkg
-- Project    : asylum-verification-uvvm
-------------------------------------------------------------------------------
-- File       : tb_apb_reset_values_pkg.vhd
-- Author     : Mathieu Rosiere
-- Company    :
-- Created    : 2026-11-22
-- Platform   :
-- Standard   : VHDL'08
-------------------------------------------------------------------------------
-- Description:
--  Scenario reset_values of tb_apb : read of the memory of the slave
--  model after the reset (mem_reset_value) at addresses that set each address
--  bit : apb_read and apb_check.
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

package tb_apb_reset_values_pkg is

  -- Read of the slave memory after the reset
  procedure run(
    signal   clk         : in    std_logic;
    signal   apb_if      : inout t_apb_if;
    signal   wait_states : out   natural
    );

end package tb_apb_reset_values_pkg;

package body tb_apb_reset_values_pkg is

  procedure run(
    signal   clk         : in    std_logic;
    signal   apb_if      : inout t_apb_if;
    signal   wait_states : out   natural
    ) is
    variable v_data      : std_logic_vector(C_DATA_WIDTH-1 downto 0);
  begin
    tb_read(0, v_data, "Address 0x00", clk, apb_if);
    check_value(v_data, mem_reset_value(0), ERROR, "apb_read of address 0x00", C_TB_SCOPE);

    -- One address per address bit, and the last one
    for i in 0 to C_ADDR_WIDTH-1 loop
      tb_check(2**i, mem_reset_value(2**i), "Address bit " & to_string(i), clk, apb_if);
    end loop;
    tb_check(2**C_ADDR_WIDTH-1, mem_reset_value(2**C_ADDR_WIDTH-1), "Last address", clk, apb_if);
  end procedure run;

end package body tb_apb_reset_values_pkg;
