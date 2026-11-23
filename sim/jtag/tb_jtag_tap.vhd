-------------------------------------------------------------------------------
-- Title      : tb_jtag_tap
-- Project    : asylum-verification-uvvm
-------------------------------------------------------------------------------
-- File       : tb_jtag_tap.vhd
-- Author     : Mathieu Rosiere
-- Company    :
-- Created    : 2026-11-22
-- Platform   :
-- Standard   : VHDL'08
-------------------------------------------------------------------------------
-- Description:
--  IEEE 1149.1 TAP model of tb_jtag (simulation only) :
--  - TAP controller of 16 states, reset by trst_b_i, by arst_b_i (power-on
--    reset) or by TMS = 1 during 5 TCK,
--  - instruction register of IR_WIDTH bits, Capture-IR loads "0...01"
--    ("10...01", MSB set, when capture_error_i = '1' : negative test of
--    jtag_ir_capture_monitor), IDCODE selected in Test-Logic-Reset,
--  - data registers : IDCODE (generic IDCODE), BYPASS (1 bit, capture 0), a user
--    register of DR_WIDTH bits (captures its value, updated in Update-DR,
--    cleared by arst_b_i only),
--  - TMS and TDI sampled on the rising edge of TCK, TDO changed on the
--    falling edge ('Z' out of Shift-IR / Shift-DR),
--  - state_o, ir_o : state of the TAP controller and instruction, for the
--    checks of the testbench.
-------------------------------------------------------------------------------
-- Copyright (c) 2026
-------------------------------------------------------------------------------
-- Revisions  :
-- Date        Version  Author   Description
-- 2026-11-22  1.0      mrosiere Created
-- 2026-11-22  1.1      mrosiere capture_error_i
-- 2026-11-23  1.2      mrosiere IDCODE generic, ir_o (chain of TAPs)
-------------------------------------------------------------------------------

library ieee;
use     ieee.std_logic_1164.all;
use     ieee.numeric_std.all;

library uvvm_util;
context uvvm_util.uvvm_util_context;

use     work.tb_jtag_bfm_pkg.all;

entity tb_jtag_tap is
  generic (
    IR_WIDTH        : positive := 5                                  -- Width of the instruction register (>= 2)
   ;DR_WIDTH        : positive := 40                                 -- Width of the user data register
   ;IDCODE          : std_logic_vector(32-1 downto 0) := C_IDCODE    -- Value of the IDCODE register
  );
  port (
    -- Power-on reset
    arst_b_i        : in  std_logic
    -- JTAG
   ;tck_i           : in  std_logic
   ;tms_i           : in  std_logic
   ;tdi_i           : in  std_logic
   ;trst_b_i        : in  std_logic
   ;tdo_o           : out std_logic
    -- Capture-IR loads a wrong value (MSB set)
   ;capture_error_i : in  std_logic
    -- State of the TAP controller and instruction
   ;state_o         : out tap_state_t
   ;ir_o            : out std_logic_vector(IR_WIDTH-1 downto 0)
  );
end entity tb_jtag_tap;

architecture sim of tb_jtag_tap is

  constant C_SCOPE      : string := "TAP MODEL";

  -- Next state of the TAP controller : (TMS = 0, TMS = 1)
  type tap_next_t is array (tap_state_t, boolean) of tap_state_t;
  constant C_NEXT       : tap_next_t := (
    TEST_LOGIC_RESET => (RUN_TEST_IDLE, TEST_LOGIC_RESET),
    RUN_TEST_IDLE    => (RUN_TEST_IDLE, SELECT_DR_SCAN  ),
    SELECT_DR_SCAN   => (CAPTURE_DR   , SELECT_IR_SCAN  ),
    CAPTURE_DR       => (SHIFT_DR     , EXIT1_DR        ),
    SHIFT_DR         => (SHIFT_DR     , EXIT1_DR        ),
    EXIT1_DR         => (PAUSE_DR     , UPDATE_DR       ),
    PAUSE_DR         => (PAUSE_DR     , EXIT2_DR        ),
    EXIT2_DR         => (SHIFT_DR     , UPDATE_DR       ),
    UPDATE_DR        => (RUN_TEST_IDLE, SELECT_DR_SCAN  ),
    SELECT_IR_SCAN   => (CAPTURE_IR   , TEST_LOGIC_RESET),
    CAPTURE_IR       => (SHIFT_IR     , EXIT1_IR        ),
    SHIFT_IR         => (SHIFT_IR     , EXIT1_IR        ),
    EXIT1_IR         => (PAUSE_IR     , UPDATE_IR       ),
    PAUSE_IR         => (PAUSE_IR     , EXIT2_IR        ),
    EXIT2_IR         => (SHIFT_IR     , UPDATE_IR       ),
    UPDATE_IR        => (RUN_TEST_IDLE, SELECT_DR_SCAN  ));

  constant C_IR_RESET         : std_logic_vector(IR_WIDTH-1 downto 0) := std_logic_vector(to_unsigned(C_IR_IDCODE, IR_WIDTH));
  constant C_IR_CAPTURE       : std_logic_vector(IR_WIDTH-1 downto 0) := std_logic_vector(to_unsigned(1          , IR_WIDTH));
  constant C_IR_CAPTURE_ERROR : std_logic_vector(IR_WIDTH-1 downto 0) := '1' & C_IR_CAPTURE(IR_WIDTH-2 downto 0);

  type dr_t is (DR_IDCODE, DR_BYPASS, DR_USER);

  signal   rst_b        : std_logic;
  signal   state        : tap_state_t;
  signal   ir           : std_logic_vector(IR_WIDTH-1 downto 0);
  signal   dr           : dr_t;

  -- Shift registers and user register
  signal   ir_sr        : std_logic_vector(IR_WIDTH-1 downto 0);
  signal   idcode_sr    : std_logic_vector(32-1 downto 0);
  signal   bypass_sr    : std_logic;
  signal   user_sr      : std_logic_vector(DR_WIDTH-1 downto 0);
  signal   user         : std_logic_vector(DR_WIDTH-1 downto 0);

begin  -- architecture sim

  rst_b   <= arst_b_i and trst_b_i;

  -- Data register selected by the instruction
  dr      <= DR_IDCODE when to_integer(unsigned(ir)) = C_IR_IDCODE else
             DR_USER   when to_integer(unsigned(ir)) = C_IR_USER   else
             DR_BYPASS;

  -----------------------------------------------------------------------------
  -- TAP controller, Capture and Shift on the rising edge of TCK
  -----------------------------------------------------------------------------
  p_rising : process(tck_i, rst_b)
  begin
    if rst_b = '0'
    then
      state <= TEST_LOGIC_RESET;
    elsif rising_edge(tck_i)
    then
      if ((tms_i /= '0' and tms_i /= '1') or
          (tdi_i /= '0' and tdi_i /= '1'))
      then
        alert(ERROR, "TMS or TDI not 0 or 1 at the rising edge of TCK", C_SCOPE);
      end if;

      case state is
        when CAPTURE_IR =>
          if capture_error_i = '1'
          then
            ir_sr   <= C_IR_CAPTURE_ERROR;
          else
            ir_sr   <= C_IR_CAPTURE;
          end if;
        when SHIFT_IR   =>
          ir_sr     <= tdi_i & ir_sr(IR_WIDTH-1 downto 1);
        when CAPTURE_DR =>
          idcode_sr <= IDCODE;
          bypass_sr <= '0';
          user_sr   <= user;
        when SHIFT_DR   =>
          -- Every data register shifts, the instruction selects the one on TDO
          idcode_sr <= tdi_i & idcode_sr(32-1 downto 1);
          bypass_sr <= tdi_i;
          user_sr   <= tdi_i & user_sr(DR_WIDTH-1 downto 1);
        when others     =>
          null;
      end case;

      state <= C_NEXT(state, tms_i = '1');
    end if;
  end process p_rising;

  -----------------------------------------------------------------------------
  -- Update and TDO on the falling edge of TCK
  -----------------------------------------------------------------------------
  p_falling : process(tck_i, rst_b)
  begin
    if rst_b = '0'
    then
      ir    <= C_IR_RESET;
      tdo_o <= 'Z';
    elsif falling_edge(tck_i)
    then
      case state is
        when TEST_LOGIC_RESET =>
          ir    <= C_IR_RESET;
        when UPDATE_IR        =>
          ir    <= ir_sr;
        when others           =>
          null;
      end case;

      case state is
        when SHIFT_IR =>
          tdo_o <= ir_sr(0);
        when SHIFT_DR =>
          case dr is
            when DR_IDCODE => tdo_o <= idcode_sr(0);
            when DR_USER   => tdo_o <= user_sr(0);
            when DR_BYPASS => tdo_o <= bypass_sr;
          end case;
        when others   =>
          tdo_o <= 'Z';
      end case;
    end if;
  end process p_falling;

  -- User register : updated in Update-DR, cleared by the power-on reset only
  p_user : process(tck_i, arst_b_i)
  begin
    if arst_b_i = '0'
    then
      user <= (others => '0');
    elsif falling_edge(tck_i)
    then
      if ((state = UPDATE_DR) and
          (dr    = DR_USER))
      then
        user <= user_sr;
      end if;
    end if;
  end process p_user;

  state_o <= state;
  ir_o    <= ir;

end architecture sim;
