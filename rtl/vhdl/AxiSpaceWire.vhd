-------------------------------------------------------------------------------
-- File       : AxiSpaceWire.vhd
-- Company    : SLAC National Accelerator Laboratory
-------------------------------------------------------------------------------
-- Description: AxiSpaceWire Module
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
use surf.AxiStreamPkg.all;
use surf.AxiLitePkg.all;
use surf.SsiPkg.all;

library work;
use work.spwpkg.all;

library unisim;
use unisim.vcomponents.all;

entity AxiSpaceWire is
   generic (
      TPD_G           : time                    := 1 ns;
      SYS_CLK_FREQ_G  : real;           -- System clock frequency in Hz.
      FAST_CLK_FREQ_G : real;  -- fastClk frequency in Hz (if tximpl = impl_fast).
      RX_IMPL_G       : spw_implementation_type := impl_fast;  -- Receiver front-end implementation.
      RX_CHUCK_G      : positive range 1 to 4   := 4;  -- Maximum number of bits received per system clock (impl_fast only).
      TX_IMPL_G       : spw_implementation_type := impl_fast;  -- Transmitter implementation.
      RX_FIFO_WIDTH_G : positive range 6 to 14  := 11;  -- Width of receive FIFO.
      TX_FIFO_WIDTH_G : positive range 6 to 14  := 11;  -- Width of transmit FIFO.
      CNT_WIDTH_G     : positive range 1 to 32  := 16;  -- Width of status counters
      AUTO_START_G    : sl                      := '1';
      LINK_START_G    : sl                      := '0';
      TX_BLOWOFF_G    : sl                      := '0');
   port (
      -- Clock and Reset
      sysClk          : in  sl;
      sysRst          : in  sl;
      fastClk         : in  sl;
      -- AXI Stream Interface (sysClk domain)
      spwIbMaster     : in  AxiStreamMasterType;
      spwIbSlave      : out AxiStreamSlaveType;
      spwObMaster     : out AxiStreamMasterType;
      spwObSlave      : in  AxiStreamSlaveType;
      -- AXI-Lite Interface (sysClk domain)
      axilWriteMaster : in  AxiLiteWriteMasterType;
      axilWriteSlave  : out AxiLiteWriteSlaveType;
      axilReadMaster  : in  AxiLiteReadMasterType;
      axilReadSlave   : out AxiLiteReadSlaveType;
      -- Space Wire Ports
      spwSinP         : in  sl;
      spwSinN         : in  sl;
      spwDinP         : in  sl;
      spwDinN         : in  sl;
      spwSoutP        : out sl;
      spwSoutN        : out sl;
      spwDoutP        : out sl;
      spwDoutN        : out sl);
end AxiSpaceWire;

architecture mapping of AxiSpaceWire is

   constant SPW_AXIS_CONFIG_C : AxiStreamConfigType := ssiAxiStreamConfig(1);

   constant EOP_C : slv(7 downto 0) := x"00";
   constant EEP_C : slv(7 downto 0) := x"01";

   constant STATUS_WIDTH_C : positive := 14;

   type StateType is (
      IDLE_S,
      MOVE_S);

   type RegType is record
      -- Control Interface
      autostart      : sl;  -- Enables automatic link start on receipt of a NULL token.
      linkstart      : sl;              -- Enables spontaneous link start.
      linkdis        : sl;  -- Do not start link and/or disconnect current link.
      txdivcnt       : slv(7 downto 0);  -- Scaling factor minus 1 for TX bitrate.
      tick_in        : sl;  -- High for one clock cycle to request transmission of a TimeCode.
      ctrl_in        : slv(1 downto 0);  -- Control bits of the TimeCode to be sent. Must be valid while tick_in is high.
      time_in        : slv(5 downto 0);  -- Counter value of the TimeCode to be sent. Must be valid while tick_in is high.
      -- TimeCode Interface
      sendtick       : sl;
      rx_expecttick  : sl;
      rx_gottick     : sl;
      tickerror      : sl;
      tx_timecnt     : slv(31 downto 0);
      tx_timemax     : slv(31 downto 0);
      -- TX Interface
      txBlowoff      : sl;
      tLast          : sl;
      eofe           : sl;
      txValid        : sl;
      txFlag         : sl;
      txData         : slv(7 downto 0);
      -- RX Interface
      rxReady        : sl;
      rxWordDrop     : sl;
      state          : StateType;
      -- AXI Stream Interface
      spwIbSlave     : AxiStreamSlaveType;
      spwObMasters   : AxiStreamMasterArray(1 downto 0);
      -- Status Counter Interface
      rollOverEn     : slv(STATUS_WIDTH_C-1 downto 0);
      cntRst         : sl;
      -- AXI-Lite Interface
      axilReadSlave  : AxiLiteReadSlaveType;
      axilWriteSlave : AxiLiteWriteSlaveType;
   end record;

   constant REG_INIT_C : RegType := (
      -- Control Interface
      autostart      => AUTO_START_G,
      linkstart      => LINK_START_G,
      linkdis        => '0',
      txdivcnt       => x"03",          -- Scaling by 4
      tick_in        => '0',
      ctrl_in        => (others => '0'),
      time_in        => (others => '0'),
      -- TimeCode Interface
      sendtick       => '0',
      rx_expecttick  => '0',
      rx_gottick     => '0',
      tickerror      => '0',
      tx_timecnt     => x"000F_FFFF",
      tx_timemax     => x"000F_FFFF",
      -- TX Interface
      txBlowoff      => TX_BLOWOFF_G,
      tLast          => '0',
      eofe           => '0',
      txValid        => '0',
      txFlag         => '0',
      txData         => (others => '0'),
      -- RX Interface
      rxReady        => '0',
      rxWordDrop     => '0',
      state          => IDLE_S,
      -- AXI Stream Interface
      spwIbSlave     => AXI_STREAM_SLAVE_INIT_C,
      spwObMasters   => (others => axiStreamMasterInit(SPW_AXIS_CONFIG_C)),
      -- Status Counter Interface
      rollOverEn     => (others => '0'),
      cntRst         => '1',
      -- AXI-Lite Interface
      axilReadSlave  => AXI_LITE_READ_SLAVE_INIT_C,
      axilWriteSlave => AXI_LITE_WRITE_SLAVE_INIT_C);

   signal r   : RegType := REG_INIT_C;
   signal rin : RegType;

   signal statusOut : slv(STATUS_WIDTH_C-1 downto 0);
   signal statusCnt : SlVectorArray(STATUS_WIDTH_C-1 downto 0, CNT_WIDTH_G-1 downto 0);

   signal started    : sl;
   signal connecting : sl;
   signal running    : sl;
   signal errdisc    : sl;
   signal errpar     : sl;
   signal erresc     : sl;
   signal errcred    : sl;

   signal txReady : sl;
   signal txhalff : sl;

   signal rxValid : sl;
   signal rxFlag  : sl;
   signal rxData  : slv(7 downto 0);
   signal rxReady : sl;
   signal rxhalff : sl;

   signal tick_out : sl;
   signal ctrl_out : slv(1 downto 0);
   signal time_out : slv(5 downto 0);

   signal spwSin  : sl;
   signal spwDin  : sl;
   signal spwSout : sl;
   signal spwDout : sl;

begin

   --------------
   -- LVDS IN/OUT
   --------------
   U_Sin : IBUFDS
      generic map (
         DIFF_TERM => true)
      port map (
         I  => spwSinP,
         IB => spwSinN,
         O  => spwSin);

   U_Din : IBUFDS
      generic map (
         DIFF_TERM => true)
      port map (
         I  => spwDinP,
         IB => spwDinN,
         O  => spwDin);

   U_Sout : OBUFDS
      port map (
         I  => spwSout,
         O  => spwSoutP,
         OB => spwSoutN);

   U_Dout : OBUFDS
      port map (
         I  => spwDout,
         O  => spwDoutP,
         OB => spwDoutN);

   ----------------
   -- SpaceWire PHY
   ----------------
   U_spwstream : entity work.spwstream
      generic map (
         sysfreq         => SYS_CLK_FREQ_G,
         txclkfreq       => FAST_CLK_FREQ_G,
         rximpl          => RX_IMPL_G,
         rxchunk         => RX_CHUCK_G,
         tximpl          => TX_IMPL_G,
         rxfifosize_bits => RX_FIFO_WIDTH_G,
         txfifosize_bits => TX_FIFO_WIDTH_G)
      port map (
         -- Clocks and Reset
         clk        => sysClk,
         rst        => sysRst,
         rxclk      => fastClk,         -- only for impl_fast
         txclk      => fastClk,         -- only for impl_fast
         -- Control Interface (clk doamin)
         autostart  => r.autostart,
         linkstart  => r.linkstart,
         linkdis    => r.linkdis,
         txdivcnt   => r.txdivcnt,
         tick_in    => r.tick_in,
         ctrl_in    => r.ctrl_in,
         time_in    => r.time_in,
         -- TX Interface (clk doamin)
         txwrite    => r.txValid,
         txflag     => r.txFlag,
         txdata     => r.txData,
         txrdy      => txReady,
         txhalff    => txhalff,
         -- TimeCode Status (clk doamin)
         tick_out   => tick_out,
         ctrl_out   => ctrl_out,
         time_out   => time_out,
         -- RX Interface (clk doamin)
         rxvalid    => rxValid,
         rxhalff    => rxhalff,
         rxflag     => rxFlag,
         rxdata     => rxData,
         rxread     => rxReady,
         -- Connection Status (clk doamin)
         started    => started,
         connecting => connecting,
         running    => running,
         errdisc    => errdisc,
         errpar     => errpar,
         erresc     => erresc,
         errcred    => errcred,
         -- Space Wire Ports
         spw_di     => spwDin,
         spw_si     => spwSin,
         spw_do     => spwDout,
         spw_so     => spwSout);

   comb : process (axilReadMaster, axilWriteMaster, ctrl_out, r, running,
                   rxData, rxFlag, rxValid, spwIbMaster, spwObSlave, statusCnt,
                   statusOut, sysRst, tick_out, time_out, txReady) is
      variable v      : RegType;
      variable axilEp : AxiLiteEndPointType;
   begin
      -- Latch the current value
      v := r;

      -- Reset the strobes
      v.cntRst        := '0';
      v.tick_in       := '0';
      v.rx_expecttick := '0';
      v.rx_gottick    := '0';
      v.tickerror     := '0';
      v.rxWordDrop    := '0';

      -- SpaceWire PHY Flow control
      v.rxReady := '0';
      if (txReady = '1') then
         v.txValid := '0';
      end if;

      -- AXI Stream Flow control
      v.spwIbSlave.tReady := '0';
      if (spwObSlave.tReady = '1') then
         v.spwObMasters(1).tValid := '0';
         v.spwObMasters(0).tValid := '0';
      end if;

      ---------------------------------------------------------------------------------
      --                               TimeCode Logic
      ---------------------------------------------------------------------------------
      -- Initiate timecode transmissions.
      v.tx_timecnt := r.tx_timecnt - 1;
      if (r.tx_timecnt = 0) then
         v.tx_timecnt := r.tx_timemax;
         v.tick_in    := r.sendtick;
      else
         v.tx_timecnt := r.tx_timecnt - 1;
      end if;
      if (r.tick_in = '1') then
         v.time_in       := r.time_in + 1;
         v.rx_expecttick := '1';
         v.rx_gottick    := '0';
      end if;

      -- Detect missing timecodes.
      if r.tick_in = '1' and r.rx_expecttick = '1' then
         -- This is bad; a new timecode is being generated while
         -- we have not even received the previous one yet.
         v.tickerror := '1';
      end if;

      -- Receive and check incoming timecodes.
      if tick_out = '1' then
         if (time_out + 1) /= r.time_in then
            -- Received time code does not match last transmitted code.
            v.tickerror := '1';
         end if;
         if r.rx_gottick = '1' then
            -- Already received the last transmitted time code.
            v.tickerror := '1';
         end if;
         v.rx_expecttick := '0';
         v.rx_gottick    := '1';
      end if;

      ---------------------------------------------------------------------------------
      --                               Transmit Logic
      ---------------------------------------------------------------------------------

      -- Check if we can move data
      if (v.txValid = '0') and (running = '1')then
         -- Check if we need to terminate the packet
         if (r.tLast = '1') then

            -- Reset the flags
            v.tLast := '0';

            -- Send the EOP/EEP
            v.txValid := '1';
            v.txFlag  := '1';

            -- Check for EOFE
            if (r.eofe = '1') then
               --  "00000001" for EEP.
               v.txdata := EEP_C;
            else
               -- "00000000" for EOP
               v.txdata := EOP_C;
            end if;

         -- Check if data on AXI stream bus
         elsif (spwIbMaster.tValid = '1') then

            -- Accept the data
            v.spwIbSlave.tReady := '1';

            -- Move the data
            v.txValid := '1';
            v.txFlag  := '0';
            v.txdata  := spwIbMaster.tData(7 downto 0);

            -- Save the metadata
            v.tLast := spwIbMaster.tLast;
            v.eofe  := ssiGetUserEofe(SPW_AXIS_CONFIG_C, spwIbMaster);

         end if;
      end if;

      ---------------------------------------------------------------------------------
      --                               Receive Logic
      ---------------------------------------------------------------------------------

      case r.state is
         ----------------------------------------------------------------------
         when IDLE_S =>
            -- Advance the output pipeline
            if (r.spwObMasters(1).tValid = '1') and (v.spwObMasters(0).tValid = '0') then
               v.spwObMasters(0) := r.spwObMasters(1);
            end if;

            -- Check if we need to move data
            if (rxValid = '1') and (v.spwObMasters(0).tValid = '0') then

               -- Accept the data
               v.rxReady := '1';

               -- Check for data flag and link up
               if (rxFlag = '0') and (running = '1')then

                  -- Move the data
                  v.spwObMasters(1)                   := axiStreamMasterInit(SPW_AXIS_CONFIG_C);
                  v.spwObMasters(1).tValid            := '1';
                  v.spwObMasters(1).tData(7 downto 0) := rxData;

                  -- Assert SSI SOF if SOF header bit set
                  ssiSetUserSof(SPW_AXIS_CONFIG_C, v.spwObMasters(1), '1');

                  -- Next state
                  v.state := MOVE_S;

               else

                  -- Set the flag
                  v.rxWordDrop := '1';

               end if;

            end if;
         ----------------------------------------------------------------------
         when MOVE_S =>
            -- Keep the caches copy
            v.spwObMasters(1).tvalid := r.spwObMasters(1).tvalid;

            -- Check if we need to move data
            if (rxValid = '1') and (v.spwObMasters(0).tValid = '0') then

               -- Accept the data
               v.rxReady := '1';

               -- Check for normal data
               if (rxFlag = '0') then

                  -- Advance the pipeline
                  v.spwObMasters(0) := r.spwObMasters(1);

                  -- Move the data
                  v.spwObMasters(1)                   := axiStreamMasterInit(SPW_AXIS_CONFIG_C);
                  v.spwObMasters(1).tValid            := '1';
                  v.spwObMasters(1).tData(7 downto 0) := rxData;

               -- Else "End of packet" flag detected
               else

                  -- Check for not EOP byte
                  if (rxData /= EOP_C) then
                     -- Set the EOFE flag
                     ssiSetUserEofe(SPW_AXIS_CONFIG_C, v.spwObMasters(1), '1');
                  end if;

                  -- Set tLast
                  v.spwObMasters(1).tLast := '1';

                  -- Next state
                  v.state := IDLE_S;

               end if;

            -- Check if link down
            elsif (running = '0') and (v.spwObMasters(0).tValid = '0') then

               -- Terminate the partial packet
               v.spwObMasters(1).tLast := '1';
               ssiSetUserEofe(SPW_AXIS_CONFIG_C, v.spwObMasters(1), '1');

               -- Next state
               v.state := IDLE_S;

            end if;
      ----------------------------------------------------------------------
      end case;

      -- Check if no no link,
      if running = '0' then
         -- we should not expect to receive time codes.
         v.rx_expecttick     := '0';
         -- Blowoff data if software can't be back pressured (default is Back pressure inbound AXI stream when link down)
         v.spwIbSlave.tReady := r.txBlowoff;
      end if;

      ---------------------------------------------------------------------------------
      --                         AXI-Lite Register Access
      ---------------------------------------------------------------------------------

      -- Determine the transaction type
      axiSlaveWaitTxn(axilEp, axilWriteMaster, axilReadMaster, v.axilWriteSlave, v.axilReadSlave);

      -- Map the read registers
      for i in STATUS_WIDTH_C-1 downto 0 loop
         axiSlaveRegisterR(axilEp, toSlv((4*i), 12), 0, muxSlVectorArray(statusCnt, i));
      end loop;
      axiSlaveRegisterR(axilEp, x"400", 0, statusOut);
      axiSlaveRegisterR(axilEp, x"600", 0, ctrl_out);
      axiSlaveRegisterR(axilEp, x"604", 0, time_out);

      axiSlaveRegister(axilEp, x"800", 0, v.autostart);
      axiSlaveRegister(axilEp, x"804", 0, v.linkstart);
      axiSlaveRegister(axilEp, x"808", 0, v.linkdis);
      axiSlaveRegister(axilEp, x"80C", 0, v.txdivcnt);
      axiSlaveRegister(axilEp, x"810", 0, v.sendtick);
      axiSlaveRegister(axilEp, x"814", 0, v.tx_timemax);
      axiSlaveRegister(axilEp, x"818", 0, v.txBlowoff);

      axiSlaveRegister(axilEp, x"FF8", 0, v.rollOverEn);
      axiSlaveRegister(axilEp, x"FFC", 0, v.cntRst);

      -- Closeout the transaction
      axiSlaveDefault(axilEp, v.axilWriteSlave, v.axilReadSlave, AXI_RESP_DECERR_C);

      ---------------------------------------------------------------------------------

      -- Check for change in timeout value
      if (v.tx_timemax /= r.tx_timemax) then
         v.tx_timecnt := v.tx_timemax;
      end if;

      -- Outputs
      rxReady        <= v.rxReady;
      spwIbSlave     <= v.spwIbSlave;
      spwObMaster    <= r.spwObMasters(0);
      axilWriteSlave <= r.axilWriteSlave;
      axilReadSlave  <= r.axilReadSlave;

      -- Synchronous Reset
      if (sysRst = '1') then
         -- Reset the register
         v := REG_INIT_C;
      end if;

      -- Register the variable for next clock cycle
      rin <= v;

   end process comb;

   seq : process (sysClk) is
   begin
      if (rising_edge(sysClk)) then
         r <= rin after TPD_G;
      end if;
   end process seq;

   U_SyncStatusVector : entity surf.SyncStatusVector
      generic map (
         TPD_G          => TPD_G,
         COMMON_CLK_G   => true,
         CNT_RST_EDGE_G => false,
         CNT_WIDTH_G    => CNT_WIDTH_G,
         WIDTH_G        => STATUS_WIDTH_C)
      port map (
         -- Input Status bit Signals (wrClk domain)
         statusIn(13) => r.rxWordDrop,
         statusIn(12) => tick_out,
         statusIn(11) => r.rx_gottick,
         statusIn(10) => r.rx_expecttick,
         statusIn(9)  => r.tickerror,
         statusIn(8)  => rxhalff,
         statusIn(7)  => txhalff,
         statusIn(6)  => started,
         statusIn(5)  => connecting,
         statusIn(4)  => running,
         statusIn(3)  => errdisc,
         statusIn(2)  => errpar,
         statusIn(1)  => erresc,
         statusIn(0)  => errcred,
         -- Output Status bit Signals (rdClk domain)
         statusOut    => statusOut,
         -- Status Bit Counters Signals (rdClk domain)
         cntRstIn     => r.cntRst,
         rollOverEnIn => r.rollOverEn,
         cntOut       => statusCnt,
         -- Clocks and Reset Ports
         wrClk        => sysClk,
         rdClk        => sysClk);

end mapping;
