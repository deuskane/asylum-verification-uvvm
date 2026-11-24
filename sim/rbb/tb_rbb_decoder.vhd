-------------------------------------------------------------------------------
-- Title      : tb_rbb_decoder
-- Project    : asylum-verification-uvvm
-------------------------------------------------------------------------------
-- File       : tb_rbb_decoder.vhd
-- Author     : Mathieu Rosiere
-- Company    :
-- Created    : 2026-11-24
-- Platform   :
-- Standard   : VHDL'08
-------------------------------------------------------------------------------
-- Description:
--  remote_bitbang decoder of tb_rbb and of tb_openocd (simulation only, the
--  testbench model of a DUT such as jtag_bitbang) : one command per rising
--  edge of clk_i from s_axis :
--    '0'..'7' : TCK, TMS, TDI = bits 2, 1, 0
--    'R'      : answer '0' / '1' on m_axis (TDO : '0' / 'L' : 0, else 1,
--               the pull-up), no command taken while it is pending
--    'r'..'u' : TRST, SRST = bits 1, 0 (1 : asserted, trst_b_o / srst_b_o
--               low)
--    'B', 'b' : blink_o on, off
--    'Q'      : ignored (OpenOCD quits)
--    other    : error (the BFM never sends them)
--  mute_i : 'R' not answered ; stall_i : s_axis_tready low (negative tests
--  of the BFM). cmd_cnt_o : commands taken since the reset.
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

entity tb_rbb_decoder is
  port (
    clk_i           : in  std_logic
   ;arst_b_i        : in  std_logic
    -- Commands
   ;s_axis_tdata_i  : in  std_logic_vector(8-1 downto 0)
   ;s_axis_tvalid_i : in  std_logic
   ;s_axis_tready_o : out std_logic
    -- Answers to 'R'
   ;m_axis_tdata_o  : out std_logic_vector(8-1 downto 0)
   ;m_axis_tvalid_o : out std_logic
   ;m_axis_tready_i : in  std_logic
    -- JTAG pins, system reset, LED
   ;tck_o           : out std_logic
   ;tms_o           : out std_logic
   ;tdi_o           : out std_logic
   ;trst_b_o        : out std_logic
   ;srst_b_o        : out std_logic
   ;blink_o         : out std_logic
   ;tdo_i           : in  std_logic
    -- Negative tests
   ;mute_i          : in  std_logic
   ;stall_i         : in  std_logic
    -- Commands taken
   ;cmd_cnt_o       : out natural
  );
end entity tb_rbb_decoder;

architecture sim of tb_rbb_decoder is

  constant C_SCOPE        : string := "RBB DECODER";

  signal   pins           : std_logic_vector(3-1 downto 0);  -- TCK, TMS, TDI
  signal   resets         : std_logic_vector(2-1 downto 0);  -- TRST, SRST (1 : asserted)
  signal   answer_valid   : std_logic;
  signal   cmd_cnt        : natural;

begin  -- architecture sim

  s_axis_tready_o <= not answer_valid and not stall_i;
  m_axis_tvalid_o <= answer_valid;

  p_decode : process(clk_i, arst_b_i)
    variable v_cmd : character;
  begin
    if arst_b_i = '0'
    then
      pins           <= "010";
      resets         <= "00";
      blink_o        <= '0';
      answer_valid   <= '0';
      m_axis_tdata_o <= x"00";
      cmd_cnt        <= 0;
    elsif rising_edge(clk_i)
    then
      if m_axis_tready_i = '1'
      then
        answer_valid <= '0';
      end if;

      if ((s_axis_tvalid_i = '1') and
          (answer_valid    = '0') and
          (stall_i         = '0'))
      then
        cmd_cnt <= cmd_cnt + 1;
        v_cmd   := character'val(to_integer(unsigned(s_axis_tdata_i)));
        case v_cmd is
          when '0' to '7' =>
            pins   <= std_logic_vector(to_unsigned(character'pos(v_cmd) - character'pos('0'), 3));
          when 'R'        =>
            if mute_i = '0'
            then
              m_axis_tdata_o <= x"30" when to_X01(tdo_i) = '0' else x"31";
              answer_valid   <= '1';
            end if;
          when 'r' to 'u' =>
            resets <= std_logic_vector(to_unsigned(character'pos(v_cmd) - character'pos('r'), 2));
          when 'B'        =>
            blink_o <= '1';
          when 'b'        =>
            blink_o <= '0';
          when 'Q'        =>
            null;
          when others     =>
            alert(ERROR, "Byte x" & to_hstring(s_axis_tdata_i) & " is not a remote_bitbang command", C_SCOPE);
        end case;
      end if;
    end if;
  end process p_decode;

  tck_o     <= pins(2);
  tms_o     <= pins(1);
  tdi_o     <= pins(0);
  trst_b_o  <= not resets(1);
  srst_b_o  <= not resets(0);
  cmd_cnt_o <= cmd_cnt;

end architecture sim;
