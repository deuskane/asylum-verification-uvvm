-------------------------------------------------------------------------------
-- Title      : rbb_axis
-- Project    : asylum-verification-uvvm
-------------------------------------------------------------------------------
-- File       : rbb_axis.vhd
-- Author     : Mathieu Rosiere
-- Company    :
-- Created    : 2026-11-24
-- Platform   :
-- Standard   : VHDL'08
-------------------------------------------------------------------------------
-- Description:
--  Testbench entity of the OpenOCD co-simulation, BYTE mode : the bytes of
--  OpenOCD (remote_bitbang adapter) on m_axis, the answers of the DUT on
--  s_axis back to OpenOCD (always taken), at most one byte each way per
--  rising edge of clk_i, after the reset (rbb_recv, rbb_send of rbb_pkg).
--  quit_o rises when OpenOCD closes the connection (or never came).
-------------------------------------------------------------------------------
-- Copyright (c) 2026
-------------------------------------------------------------------------------
-- Revisions  :
-- Date        Version  Author   Description
-- 2026-11-24  1.0      mrosiere Created from tb_bitbang_openocd
--                               (asylum-debug-jtag)
-------------------------------------------------------------------------------

library ieee;
use     ieee.std_logic_1164.all;
use     ieee.numeric_std.all;

use     work.rbb_pkg.all;

entity rbb_axis is
  port (
    clk_i           : in  std_logic
   ;arst_b_i        : in  std_logic                        -- No call before its release
    -- Bytes of OpenOCD
   ;m_axis_tdata_o  : out std_logic_vector(8-1 downto 0)
   ;m_axis_tvalid_o : out std_logic
   ;m_axis_tready_i : in  std_logic
    -- Answers to OpenOCD
   ;s_axis_tdata_i  : in  std_logic_vector(8-1 downto 0)
   ;s_axis_tvalid_i : in  std_logic
   ;s_axis_tready_o : out std_logic
    -- OpenOCD quit
   ;quit_o          : out std_logic
  );
end entity rbb_axis;

architecture sim of rbb_axis is

  signal   m_tvalid       : std_logic := '0';

begin  -- architecture sim

  s_axis_tready_o <= '1';
  m_axis_tvalid_o <= m_tvalid;

  p_rbb : process
    variable v_byte : integer;
  begin
    m_axis_tdata_o <= x"00";
    quit_o         <= '0';
    wait until arst_b_i = '1';
    loop
      wait until rising_edge(clk_i);
      if s_axis_tvalid_i = '1'
      then
        rbb_send(to_integer(unsigned(s_axis_tdata_i)));
      end if;
      if m_tvalid = '0' or m_axis_tready_i = '1'
      then
        v_byte := rbb_recv;
        if v_byte >= 0
        then
          m_axis_tdata_o <= std_logic_vector(to_unsigned(v_byte, 8));
          m_tvalid       <= '1';
        else
          m_tvalid       <= '0';
          if v_byte = RBB_CLOSED
          then
            quit_o <= '1';
            wait;
          end if;
        end if;
      end if;
    end loop;
  end process p_rbb;

end architecture sim;
