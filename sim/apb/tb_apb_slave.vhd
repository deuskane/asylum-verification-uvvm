-------------------------------------------------------------------------------
-- Title      : tb_apb_slave
-- Project    : asylum-verification-uvvm
-------------------------------------------------------------------------------
-- File       : tb_apb_slave.vhd
-- Author     : Mathieu Rosiere
-- Company    :
-- Created    : 2026-11-22
-- Platform   :
-- Standard   : VHDL'08
-------------------------------------------------------------------------------
-- Description:
--  APB3 slave model of tb_apb (simulation only) :
--  - memory of 2**C_ADDR_WIDTH words, mem_reset_value after the reset,
--  - wait_states_i cycles with pready low in the access phase,
--  - pslverr at C_ERR_ADDR (the write is ignored),
--  - prdata at 'X' outside the end of a read transfer,
--  - protocol checker (UVVM alerts) : setup phase of one cycle with penable
--    low, then psel, penable, paddr, pwrite and pwdata held until pready.
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

use     work.tb_apb_bfm_pkg.all;

entity tb_apb_slave is
  port (
    -- Clock and Reset
    clk_i           : in  std_logic
   ;arst_b_i        : in  std_logic
    -- APB
   ;psel_i          : in  std_logic
   ;penable_i       : in  std_logic
   ;pwrite_i        : in  std_logic
   ;paddr_i         : in  std_logic_vector(C_ADDR_WIDTH-1 downto 0)
   ;pwdata_i        : in  std_logic_vector(C_DATA_WIDTH-1 downto 0)
   ;prdata_o        : out std_logic_vector(C_DATA_WIDTH-1 downto 0)
   ;pready_o        : out std_logic
   ;pslverr_o       : out std_logic
    -- Control
   ;wait_states_i   : in  natural                                    -- Cycles with pready low in the access phase
  );
end entity tb_apb_slave;

architecture sim of tb_apb_slave is

  constant C_SCOPE    : string := "APB SLAVE";

  type mem_t is array (0 to 2**C_ADDR_WIDTH-1) of std_logic_vector(C_DATA_WIDTH-1 downto 0);

  signal   mem        : mem_t;
  signal   addr       : natural range 0 to 2**C_ADDR_WIDTH-1;
  signal   wait_cnt   : natural;
  signal   pready     : std_logic;
  signal   pslverr    : std_logic;

  -- Protocol checker : transfer in progress and its setup phase
  signal   xfer_r     : boolean;
  signal   pwrite_r   : std_logic;
  signal   paddr_r    : std_logic_vector(C_ADDR_WIDTH-1 downto 0);
  signal   pwdata_r   : std_logic_vector(C_DATA_WIDTH-1 downto 0);

begin  -- architecture sim

  addr      <= to_integer(unsigned(paddr_i)) when not is_x(paddr_i) else 0;

  -----------------------------------------------------------------------------
  -- Answer : pready after wait_states_i cycles of the access phase
  -----------------------------------------------------------------------------
  pready    <= '1' when ((psel_i    = '1') and
                         (penable_i = '1') and
                         (wait_cnt  = wait_states_i)) else
               '0';
  pslverr   <= '1' when ((pready    = '1') and
                         (addr      = C_ERR_ADDR)) else
               '0';

  -- Read data valid at the end of a read transfer only
  prdata_o  <= mem(addr) when ((pready   = '1') and
                               (pwrite_i = '0') and
                               (pslverr  = '0')) else
               (others => 'X');
  pready_o  <= pready;
  pslverr_o <= pslverr;

  -----------------------------------------------------------------------------
  -- Memory, wait states and protocol checker
  -----------------------------------------------------------------------------
  process(clk_i, arst_b_i)
  begin
    if arst_b_i = '0'
    then
      for i in mem'range loop
        mem(i) <= mem_reset_value(i);
      end loop;
      wait_cnt <= 0;
      xfer_r   <= false;
    elsif rising_edge(clk_i)
    then
      -- Wait states
      if ((psel_i    = '1') and
          (penable_i = '1') and
          (pready    = '0'))
      then
        wait_cnt <= wait_cnt + 1;
      else
        wait_cnt <= 0;
      end if;

      -- Write at the end of the transfer
      if ((pready   = '1') and
          (pwrite_i = '1') and
          (pslverr  = '0'))
      then
        mem(addr) <= pwdata_i;
      end if;

      -- Protocol checker
      if not xfer_r
      then
        -- Idle : a transfer starts with a setup phase (psel, penable low)
        if penable_i = '1'
        then
          alert(ERROR, "penable high without setup phase", C_SCOPE);
        end if;
        if psel_i = '1'
        then
          xfer_r   <= true;
          pwrite_r <= pwrite_i;
          paddr_r  <= paddr_i;
          pwdata_r <= pwdata_i;
        end if;
      else
        -- Access phase : everything held until pready
        if psel_i /= '1'
        then
          alert(ERROR, "psel dropped before pready", C_SCOPE);
        elsif penable_i /= '1'
        then
          alert(ERROR, "penable low in the access phase", C_SCOPE);
        elsif ((pwrite_i /= pwrite_r) or
               (paddr_i  /= paddr_r ) or
               (pwdata_i /= pwdata_r))
        then
          alert(ERROR, "pwrite, paddr or pwdata changed during the transfer", C_SCOPE);
        end if;
        if ((pready = '1') or
            (psel_i = '0'))
        then
          xfer_r   <= false;
        end if;
      end if;
    end if;
  end process;

end architecture sim;
