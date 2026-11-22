-------------------------------------------------------------------------------
-- Title      : tb_apb_bfm_pkg
-- Project    : asylum-verification-uvvm
-------------------------------------------------------------------------------
-- File       : tb_apb_bfm_pkg.vhd
-- Author     : Mathieu Rosiere
-- Company    :
-- Created    : 2026-11-22
-- Platform   :
-- Standard   : VHDL'08
-------------------------------------------------------------------------------
-- Description:
--  Constants and helpers shared by the scenarios of tb_apb (test of
--  apb_bfm_pkg against the APB slave model tb_apb_slave) : bus widths,
--  memory content after reset, error address, reset pulse, APB accesses
--  through the BFM.
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

package tb_apb_bfm_pkg is

  constant C_TB_SCOPE     : string  := "TB_APB";      -- Scope of the scenarios (C_SCOPE of uvvm_util is hidden by the C_SCOPE of the testbench)
  constant C_CLK_PERIOD   : time    := 10 ns;
  constant C_ADDR_WIDTH   : natural := 8;
  constant C_DATA_WIDTH   : natural := 32;
  constant C_ERR_ADDR     : natural := 16#E7#;        -- Address answered with pslverr by the slave model

  -- Memory of the slave model after the reset : address and its complement
  -- (every bit toggles over the addresses)
  function mem_reset_value(addr : natural) return std_logic_vector;

  -- Reset pulse of the slave model, released on the falling (inactive) edge
  procedure do_reset(
    signal   clk          : in    std_logic;
    signal   arst_b       : out   std_logic
    );

  -- APB accesses through the BFM (address as a natural)
  procedure tb_write(
    constant addr         : in    natural;
    constant data         : in    std_logic_vector;
    constant msg          : in    string;
    signal   clk          : in    std_logic;
    signal   apb_if       : inout t_apb_if;
    constant config       : in    t_apb_bfm_config := C_APB_BFM_CONFIG_DEFAULT
    );

  procedure tb_read(
    constant addr         : in    natural;
    variable data         : out   std_logic_vector;
    constant msg          : in    string;
    signal   clk          : in    std_logic;
    signal   apb_if       : inout t_apb_if;
    constant config       : in    t_apb_bfm_config := C_APB_BFM_CONFIG_DEFAULT
    );

  procedure tb_check(
    constant addr         : in    natural;
    constant data_exp     : in    std_logic_vector;
    constant msg          : in    string;
    signal   clk          : in    std_logic;
    signal   apb_if       : inout t_apb_if;
    constant config       : in    t_apb_bfm_config := C_APB_BFM_CONFIG_DEFAULT;
    constant alert_level  : in    t_alert_level    := ERROR
    );

end package tb_apb_bfm_pkg;

package body tb_apb_bfm_pkg is

  function mem_reset_value(addr : natural) return std_logic_vector is
    constant C_ADDR : std_logic_vector(8-1 downto 0) := std_logic_vector(to_unsigned(addr, 8));
  begin
    return C_ADDR & not C_ADDR & C_ADDR & not C_ADDR;
  end function mem_reset_value;

  procedure do_reset(
    signal   clk          : in    std_logic;
    signal   arst_b       : out   std_logic
    ) is
  begin
    arst_b <= '0';
    wait_num_rising_edge(clk, 4);
    wait until falling_edge(clk);
    arst_b <= '1';
  end procedure do_reset;

  procedure tb_write(
    constant addr         : in    natural;
    constant data         : in    std_logic_vector;
    constant msg          : in    string;
    signal   clk          : in    std_logic;
    signal   apb_if       : inout t_apb_if;
    constant config       : in    t_apb_bfm_config := C_APB_BFM_CONFIG_DEFAULT
    ) is
  begin
    apb_write(addr_value   => to_unsigned(addr, C_ADDR_WIDTH),
              data_value   => data,
              msg          => msg,
              clk          => clk,
              apb_if       => apb_if,
              scope        => C_TB_SCOPE,
              config       => config);
  end procedure tb_write;

  procedure tb_read(
    constant addr         : in    natural;
    variable data         : out   std_logic_vector;
    constant msg          : in    string;
    signal   clk          : in    std_logic;
    signal   apb_if       : inout t_apb_if;
    constant config       : in    t_apb_bfm_config := C_APB_BFM_CONFIG_DEFAULT
    ) is
  begin
    apb_read (addr_value   => to_unsigned(addr, C_ADDR_WIDTH),
              data_value   => data,
              msg          => msg,
              clk          => clk,
              apb_if       => apb_if,
              scope        => C_TB_SCOPE,
              config       => config);
  end procedure tb_read;

  procedure tb_check(
    constant addr         : in    natural;
    constant data_exp     : in    std_logic_vector;
    constant msg          : in    string;
    signal   clk          : in    std_logic;
    signal   apb_if       : inout t_apb_if;
    constant config       : in    t_apb_bfm_config := C_APB_BFM_CONFIG_DEFAULT;
    constant alert_level  : in    t_alert_level    := ERROR
    ) is
  begin
    apb_check(addr_value   => to_unsigned(addr, C_ADDR_WIDTH),
              data_exp     => data_exp,
              msg          => msg,
              clk          => clk,
              apb_if       => apb_if,
              alert_level  => alert_level,
              scope        => C_TB_SCOPE,
              config       => config);
  end procedure tb_check;

end package body tb_apb_bfm_pkg;
