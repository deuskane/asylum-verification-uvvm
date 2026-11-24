-------------------------------------------------------------------------------
-- Title      : rbb_jtag
-- Project    : asylum-verification-uvvm
-------------------------------------------------------------------------------
-- File       : rbb_jtag.vhd
-- Author     : Mathieu Rosiere
-- Company    :
-- Created    : 2026-11-24
-- Platform   :
-- Standard   : VHDL'08
-------------------------------------------------------------------------------
-- Description:
--  Testbench entity of the OpenOCD co-simulation, PIN mode : OpenOCD
--  (remote_bitbang adapter) drives the JTAG pins of the DUT. After the reset,
--  rbb_tick (rbb_pkg) is called every CLK_DIV rising edges of clk_i : at most
--  one pin change per call, so at least CLK_DIV cycles of clk_i between two
--  pin changes (TCK period >= 2*CLK_DIV cycles). 'R' is answered with tdo_i
--  ('0' / 'L' : 0, anything else : 1, the pull-up of TDO). quit_o rises when
--  OpenOCD quits or closes the connection ; the pins keep their last value.
-------------------------------------------------------------------------------
-- Copyright (c) 2026
-------------------------------------------------------------------------------
-- Revisions  :
-- Date        Version  Author   Description
-- 2026-11-24  1.0      mrosiere Created from tb_WardRV_openocd
--                               (asylum-processor-WardRV)
-------------------------------------------------------------------------------

library ieee;
use     ieee.std_logic_1164.all;
use     ieee.numeric_std.all;

use     work.rbb_pkg.all;

entity rbb_jtag is
  generic (
    CLK_DIV         : positive := 1                        -- Cycles of clk_i between two calls of rbb_tick
  );
  port (
    clk_i           : in  std_logic
   ;arst_b_i        : in  std_logic                        -- No call before its release
    -- JTAG pins
   ;tck_o           : out std_logic
   ;tms_o           : out std_logic
   ;tdi_o           : out std_logic
   ;trst_b_o        : out std_logic
   ;srst_b_o        : out std_logic
   ;tdo_i           : in  std_logic
    -- OpenOCD quit
   ;quit_o          : out std_logic
  );
end entity rbb_jtag;

architecture sim of rbb_jtag is
begin  -- architecture sim

  p_rbb : process
    variable v_pins : std_logic_vector(RBB_SRST downto 0);
    variable v_tdo  : integer;
  begin
    tck_o    <= '0';
    tms_o    <= '1';
    tdi_o    <= '0';
    trst_b_o <= '1';
    srst_b_o <= '1';
    quit_o   <= '0';
    wait until arst_b_i = '1';
    loop
      for i in 1 to CLK_DIV loop
        wait until rising_edge(clk_i);
      end loop;
      v_tdo    := 0 when to_X01(tdo_i) = '0' else 1;
      v_pins   := std_logic_vector(to_unsigned(rbb_tick(v_tdo), v_pins'length));
      tck_o    <= v_pins(RBB_TCK);
      tms_o    <= v_pins(RBB_TMS);
      tdi_o    <= v_pins(RBB_TDI);
      trst_b_o <= not v_pins(RBB_TRST);
      srst_b_o <= not v_pins(RBB_SRST);
      if v_pins(RBB_QUIT) = '1'
      then
        quit_o <= '1';
        wait;
      end if;
    end loop;
  end process p_rbb;

end architecture sim;
