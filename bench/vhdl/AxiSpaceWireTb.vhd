-------------------------------------------------------------------------------
-- Company    : SLAC National Accelerator Laboratory
-------------------------------------------------------------------------------
-- Description: Simulation Testbed for testing the AxiSpaceWire module
-------------------------------------------------------------------------------
-- Copyright (c) 2020, The Board of Trustees of the Leland Stanford Junior
-- University, through SLAC National Accelerator Laboratory (subject to receipt
-- of any required approvals from the U.S. Dept. of Energy). All rights reserved.
-- Redistribution and use in source and binary forms, with or without
-- modification, are permitted provided that the following conditions are met:
--
-- (1) Redistributions of source code must retain the above copyright notice,
--     this list of conditions and the following disclaimer.
--
-- (2) Redistributions in binary form must reproduce the above copyright notice,
--     this list of conditions and the following disclaimer in the documentation
--     and/or other materials provided with the distribution.
--
-- (3) Neither the name of the Leland Stanford Junior University, SLAC National
--     Accelerator Laboratory, U.S. Dept. of Energy nor the names of its
--     contributors may be used to endorse or promote products derived from this
--     software without specific prior written permission.
--
-- THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS" AND
-- ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED
-- WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE
-- DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT OWNER, THE UNITED STATES GOVERNMENT,
-- OR CONTRIBUTORS BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL,
-- EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT
-- OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS
-- INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN
-- CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING
-- IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY
-- OF SUCH DAMAGE.
--
-- You are under no obligation whatsoever to provide any bug fixes, patches, or
-- upgrades to the features, functionality or performance of the source code
-- ("Enhancements") to anyone; however, if you choose to make your Enhancements
-- available either publicly, or directly to SLAC National Accelerator Laboratory,
-- without imposing a separate written license agreement for such Enhancements,
-- then you hereby grant the following license: a non-exclusive, royalty-free
-- perpetual license to install, use, modify, prepare derivative works, incorporate
-- into other computer software, distribute, and sublicense such Enhancements or
-- derivative works thereof, in binary and source code form.
-------------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;
use ieee.std_logic_unsigned.all;
use ieee.std_logic_arith.all;

library surf;
use surf.StdRtlPkg.all;
use surf.AxiLitePkg.all;
use surf.AxiStreamPkg.all;
use surf.SsiPkg.all;

entity AxiSpaceWireTb is end AxiSpaceWireTb;

architecture testbed of AxiSpaceWireTb is

   constant TPD_G : time := 1 ns;

   constant TX_PACKET_LENGTH_C : slv(31 downto 0) := x"0000_000F";

   constant PRBS_SEED_SIZE_C : natural      := 32;
   constant PRBS_TAPS_C      : NaturalArray := (0 => 31, 1 => 6, 2 => 2, 3 => 1);
   constant PRBS_FLOW_CTRL_C : boolean      := true;

   constant NOT_PAUSE_FLOW_CONTROL_C : boolean := false;  -- false for pause flow control

   constant AXI_STREAM_CONFIG_C : AxiStreamConfigType := (
      TSTRB_EN_C    => false,
      TDATA_BYTES_C => 1,
      TDEST_BITS_C  => 0,
      TID_BITS_C    => 0,
      TKEEP_MODE_C  => TKEEP_COMP_C,
      TUSER_BITS_C  => 2,
      TUSER_MODE_C  => TUSER_FIRST_LAST_C);

   signal txTrig      : sl := '0';
   signal txForceEofe : sl := '0';
   signal txBusy      : sl := '0';

   signal txMaster : AxiStreamMasterType := AXI_STREAM_MASTER_INIT_C;
   signal txSlave  : AxiStreamSlaveType  := AXI_STREAM_SLAVE_INIT_C;
   signal txCtrl   : AxiStreamCtrlType   := AXI_STREAM_CTRL_INIT_C;

   signal rxMaster : AxiStreamMasterType := AXI_STREAM_MASTER_INIT_C;
   signal rxSlave  : AxiStreamSlaveType  := AXI_STREAM_SLAVE_INIT_C;

   signal prbsFlowCtrlMaster : AxiStreamMasterType := AXI_STREAM_MASTER_INIT_C;
   signal prbsFlowCtrlSlave  : AxiStreamSlaveType  := AXI_STREAM_SLAVE_FORCE_C;

   signal updated      : sl               := '0';
   signal errorDet     : sl               := '0';
   signal errLength    : sl               := '0';
   signal errDataBus   : sl               := '0';
   signal errEofe      : sl               := '0';
   signal errWordCnt   : slv(31 downto 0) := (others => '0');
   signal packetLength : slv(31 downto 0) := (others => '0');
   signal cnt          : slv(31 downto 0) := (others => '0');
   signal trigCnt      : slv(31 downto 0) := (others => '0');
   signal failedVec    : slv(6 downto 0)  := (others => '0');

   signal spwLoopP : slv(1 downto 0) := (others => '0');
   signal spwLoopN : slv(1 downto 0) := (others => '1');

   signal axilClk    : sl := '0';
   signal axilRst    : sl := '1';
   signal axilRstL   : sl := '0';
   signal spwFastClk : sl := '0';

   signal passed : sl := '0';
   signal failed : sl := '0';

begin

   -----------------------------
   -- Generate clocks and resets
   -----------------------------
   U_Slow : entity surf.ClkRst
      generic map (
         CLK_PERIOD_G      => 10 ns,    -- 100 MHz
         RST_START_DELAY_G => 0 ns,
         RST_HOLD_TIME_G   => 1 us)
      port map (
         clkP => axilClk,
         rst  => axilRst,
         rstL => axilRstL);

   U_Fast : entity surf.ClkRst
      generic map (
         CLK_PERIOD_G      => (10 ns/3),  -- 300 MHz
         RST_START_DELAY_G => 0 ns,
         RST_HOLD_TIME_G   => 1 us)
      port map (
         clkP => spwFastClk);

   --------------
   -- Data Source
   --------------
   U_Tx : entity surf.SsiPrbsTx
      generic map (
         -- General Configurations
         TPD_G                      => TPD_G,
         AXI_EN_G                   => '0',
         -- FIFO configurations
         GEN_SYNC_FIFO_G            => true,
         -- PRBS Configurations
         PRBS_SEED_SIZE_G           => PRBS_SEED_SIZE_C,
         PRBS_TAPS_G                => PRBS_TAPS_C,
         -- AXI Stream Configurations
         MASTER_AXI_STREAM_CONFIG_G => AXI_STREAM_CONFIG_C)
      port map (
         -- Master Port (mAxisClk)
         mAxisClk     => axilClk,
         mAxisRst     => axilRst,
         mAxisMaster  => txMaster,
         mAxisSlave   => txSlave,
         -- Trigger Signal (locClk domain)
         locClk       => axilClk,
         locRst       => axilRst,
         -- trig         => txTrig,
         trig         => axilRstL,
         packetLength => TX_PACKET_LENGTH_C,
         forceEofe    => txForceEofe,
         busy         => txBusy);

   trig : process (axilClk) is
   begin
      if rising_edge(axilClk) then
         txTrig  <= '0'         after TPD_G;
         trigCnt <= trigCnt + 1 after TPD_G;
         if trigCnt = 4096 then
            txTrig <= '1' after TPD_G;
         end if;
      end if;
   end process trig;

   ----------------------
   -- Module to be tested
   ----------------------
   U_AxiSpaceWire : entity work.AxiSpaceWire
      generic map (
         TPD_G           => TPD_G,
         LINK_START_G    => '1',
         SYS_CLK_FREQ_G  => 100.0E+6,
         FAST_CLK_FREQ_G => 300.0E+6)
      port map (
         -- Clock and Reset
         sysClk          => axilClk,
         sysRst          => axilRst,
         fastClk         => spwFastClk,
         -- AXI Stream Interface (sysClk domain)
         spwIbMaster     => txMaster,
         spwIbSlave      => txSlave,
         spwObMaster     => rxMaster,
         spwObSlave      => rxSlave,
         -- AXI-Lite Interface (sysClk domain)
         axilWriteMaster => AXI_LITE_WRITE_MASTER_INIT_C,
         axilWriteSlave  => open,
         axilReadMaster  => AXI_LITE_READ_MASTER_INIT_C,
         axilReadSlave   => open,
         -- Space Wire Ports
         spwSinP         => spwLoopP(0),
         spwSinN         => spwLoopN(0),
         spwDinP         => spwLoopP(1),
         spwDinN         => spwLoopN(1),
         spwSoutP        => spwLoopP(0),
         spwSoutN        => spwLoopN(0),
         spwDoutP        => spwLoopP(1),
         spwDoutN        => spwLoopN(1));

   ------------
   -- Data Sink
   ------------
   U_Rx : entity surf.SsiPrbsRx
      generic map (
         -- General Configurations
         TPD_G                      => TPD_G,
         -- FIFO Configurations
         GEN_SYNC_FIFO_G            => true,
         -- PRBS Configurations
         PRBS_SEED_SIZE_G           => PRBS_SEED_SIZE_C,
         PRBS_TAPS_G                => PRBS_TAPS_C,
         -- AXI Stream Configurations
         SLAVE_AXI_STREAM_CONFIG_G  => AXI_STREAM_CONFIG_C,
         MASTER_AXI_STREAM_CONFIG_G => AXI_STREAM_CONFIG_C)
      port map (
         -- Streaming RX Data Interface (sAxisClk domain)
         sAxisClk       => axilClk,
         sAxisRst       => axilRst,
         sAxisMaster    => rxMaster,
         sAxisSlave     => rxSlave,
         -- Optional: TX Data Interface with EOFE tagging (sAxisClk domain)
         mAxisMaster    => prbsFlowCtrlMaster,
         mAxisSlave     => prbsFlowCtrlSlave,
         -- Error Detection Signals (sAxisClk domain)
         updatedResults => updated,
         errorDet       => errorDet,
         packetLength   => packetLength,
         errLength      => errLength,
         errDataBus     => errDataBus,
         errEofe        => errEofe,
         errWordCnt     => errWordCnt);

   ------------------------------------
   -- Assert PseudoRandom back pressure
   ------------------------------------
   GEN_PRBS_FLOW_CTRL : if (PRBS_FLOW_CTRL_C) generate
      U_PrbsFlowCtrl : entity surf.AxiStreamPrbsFlowCtrl
         generic map (
            TPD_G => TPD_G)
         port map (
            clk         => axilClk,
            rst         => axilRst,
            threshold   => x"1000_0000",
            -- Slave Port
            sAxisMaster => prbsFlowCtrlMaster,
            sAxisSlave  => prbsFlowCtrlSlave,
            -- Master Port
            mAxisMaster => open,
            mAxisSlave  => AXI_STREAM_SLAVE_FORCE_C);
   end generate;

   -----------------
   -- Error Checking
   -----------------
   error_checking : process(axilClk)
   begin
      if rising_edge(axilClk) then
         -- Check for RX PRBS update
         if updated = '1' then

            -- Map the error flag to the failed test vector
            failedVec(0) <= errLength  after TPD_G;
            failedVec(1) <= errDataBus after TPD_G;
            failedVec(2) <= errEofe    after TPD_G;

            -- Check for non-zero error word counts
            if errWordCnt /= 0 then
               failedVec(3) <= '1' after TPD_G;
            else
               failedVec(3) <= '0' after TPD_G;
            end if;

            -- Check for mismatch in expect length
            if packetLength /= TX_PACKET_LENGTH_C then
               failedVec(4) <= '1' after TPD_G;
            else
               failedVec(4) <= '0' after TPD_G;
            end if;

            -- Check for non-pause flow control and error detected
            if (NOT_PAUSE_FLOW_CONTROL_C) then
               failedVec(5) <= errorDet        after TPD_G;
               failedVec(6) <= txCtrl.overflow after TPD_G;
            end if;

            -- Increment the counter
            cnt <= cnt + 1 after TPD_G;

         end if;
      end if;
   end process error_checking;

   results : process (axilClk) is
   begin
      if rising_edge(axilClk) then

         -- OR Failed bits together
         failed <= uOR(failedVec) after TPD_G;

         -- Check for counter
         if (cnt = x"0001_0000") then
            passed <= '1' after TPD_G;
         end if;

      end if;
   end process results;

   process(failed, passed)
   begin
      if passed = '1' then
         assert false
            report "Simulation Passed!" severity failure;
      elsif failed = '1' then
         assert false
            report "Simulation Failed!" severity failure;
      end if;
   end process;

end testbed;
