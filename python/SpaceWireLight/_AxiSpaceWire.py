##############################################################################
## Copyright (c) 2020, The Board of Trustees of the Leland Stanford Junior
## University, through SLAC National Accelerator Laboratory (subject to receipt
## of any required approvals from the U.S. Dept. of Energy). All rights reserved.
## Redistribution and use in source and binary forms, with or without
## modification, are permitted provided that the following conditions are met:
##
## (1) Redistributions of source code must retain the above copyright notice,
##     this list of conditions and the following disclaimer.
##
## (2) Redistributions in binary form must reproduce the above copyright notice,
##     this list of conditions and the following disclaimer in the documentation
##     and/or other materials provided with the distribution.
##
## (3) Neither the name of the Leland Stanford Junior University, SLAC National
##     Accelerator Laboratory, U.S. Dept. of Energy nor the names of its
##     contributors may be used to endorse or promote products derived from this
##     software without specific prior written permission.
##
## THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS" AND
## ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED
## WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE
## DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT OWNER, THE UNITED STATES GOVERNMENT,
## OR CONTRIBUTORS BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL,
## EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT
## OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS
## INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN
## CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING
## IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY
## OF SUCH DAMAGE.
##
## You are under no obligation whatsoever to provide any bug fixes, patches, or
## upgrades to the features, functionality or performance of the source code
## ("Enhancements") to anyone; however, if you choose to make your Enhancements
## available either publicly, or directly to SLAC National Accelerator Laboratory,
## without imposing a separate written license agreement for such Enhancements,
## then you hereby grant the following license: a non#exclusive, royalty#free
## perpetual license to install, use, modify, prepare derivative works, incorporate
## into other computer software, distribute, and sublicense such Enhancements or
## derivative works thereof, in binary and source code form.
##############################################################################

import pyrogue as pr

class AxiSpaceWire(pr.Device):
    def __init__(self,
                 description     = "Container for AxiSpaceWire",
                 statusCountBits = 16,
                 **kwargs):
        super().__init__(description=description, **kwargs)

        self.add(pr.RemoteVariable(
            name         = "CreditErrorCnt",
            description  = "Increments when credit error detected. Triggers a reset and reconnect of the link",
            offset       = 4*0,
            bitSize      = statusCountBits,
            mode         = "RO",
            pollInterval = 1,
        ))

        self.add(pr.RemoteVariable(
            name         = "EscapeErrorCnt",
            description  = "Increments when Invalid escape sequence detected in state Run",
            offset       = 4*1,
            bitSize      = statusCountBits,
            mode         = "RO",
            pollInterval = 1,
        ))

        self.add(pr.RemoteVariable(
            name         = "ParityErrorCnt",
            description  = "Increments when Parity error detected in state Run",
            offset       = 4*2,
            bitSize      = statusCountBits,
            mode         = "RO",
            pollInterval = 1,
        ))

        self.add(pr.RemoteVariable(
            name         = "DisconnectErrorCnt",
            description  = "Increments when Disconnect detected in state Run",
            offset       = 4*3,
            bitSize      = statusCountBits,
            mode         = "RO",
            pollInterval = 1,
        ))

        self.add(pr.RemoteVariable(
            name         = "RunningCnt",
            description  = "Increments when transitions into the Run state",
            offset       = 4*4,
            bitSize      = statusCountBits,
            mode         = "RO",
            pollInterval = 1,
        ))

        self.add(pr.RemoteVariable(
            name         = "ConnectingCnt",
            description  = "Increments when transitions into the Connecting state",
            offset       = 4*5,
            bitSize      = statusCountBits,
            mode         = "RO",
            pollInterval = 1,
        ))

        self.add(pr.RemoteVariable(
            name         = "StartedCnt",
            description  = "Increments when transitions into the Started state",
            offset       = 4*6,
            bitSize      = statusCountBits,
            mode         = "RO",
            pollInterval = 1,
        ))

        self.add(pr.RemoteVariable(
            name         = "TxPauseCnt",
            description  = "Increments when TX FIFO is half full",
            offset       = 4*7,
            bitSize      = statusCountBits,
            mode         = "RO",
            pollInterval = 1,
        ))

        self.add(pr.RemoteVariable(
            name         = "RxPauseCnt",
            description  = "Increments when RX FIFO is half full",
            offset       = 4*8,
            bitSize      = statusCountBits,
            mode         = "RO",
            pollInterval = 1,
        ))

        self.add(pr.RemoteVariable(
            name         = "TickErrorCnt",
            description  = "Increments when tick error detected",
            offset       = 4*9,
            bitSize      = statusCountBits,
            mode         = "RO",
            pollInterval = 1,
        ))

        self.add(pr.RemoteVariable(
            name         = "RxExpectTickCnt",
            description  = "Increments when an expected tick is received",
            offset       = 4*10,
            bitSize      = statusCountBits,
            mode         = "RO",
            pollInterval = 1,
        ))

        self.add(pr.RemoteVariable(
            name         = "RxGotTickCnt",
            description  = "Increments when a tick is received",
            offset       = 4*11,
            bitSize      = statusCountBits,
            mode         = "RO",
            pollInterval = 1,
        ))

        self.add(pr.RemoteVariable(
            name         = "TickOutCnt",
            description  = "Increments when TimeCode was just received",
            offset       = 4*12,
            bitSize      = statusCountBits,
            mode         = "RO",
            pollInterval = 1,
        ))

        self.add(pr.RemoteVariable(
            name         = "RxWordDrop",
            description  = "Increments anytime a RX word is dropped",
            offset       = 4*13,
            bitSize      = statusCountBits,
            mode         = "RO",
            pollInterval = 1,
        ))

        self.add(pr.RemoteVariable(
            name         = "RunningState",
            description  = "Run state",
            offset       = 0x400,
            bitSize      = 1,
            bitOffset    = 4,
            mode         = "RO",
            base         = pr.Bool,
            pollInterval = 1,
        ))

        self.add(pr.RemoteVariable(
            name         = "ConnectingState",
            description  = "Connecting state",
            offset       = 0x400,
            bitSize      = 1,
            bitOffset    = 5,
            mode         = "RO",
            base         = pr.Bool,
            pollInterval = 1,
        ))

        self.add(pr.RemoteVariable(
            name         = "StartedState",
            description  = "Started state",
            offset       = 0x400,
            bitSize      = 1,
            bitOffset    = 6,
            mode         = "RO",
            base         = pr.Bool,
            pollInterval = 1,
        ))

        self.add(pr.RemoteVariable(
            name         = "TxPause",
            description  = "TX FIFO is half full",
            offset       = 0x400,
            bitSize      = 1,
            bitOffset    = 7,
            mode         = "RO",
            base         = pr.Bool,
            pollInterval = 1,
        ))

        self.add(pr.RemoteVariable(
            name         = "RxPause",
            description  = "RX FIFO is half full",
            offset       = 0x400,
            bitSize      = 1,
            bitOffset    = 8,
            mode         = "RO",
            base         = pr.Bool,
            pollInterval = 1,
        ))

        self.add(pr.RemoteVariable(
            name         = "CtrlOut",
            description  = "Control bits of the last received TimeCode",
            offset       = 0x600,
            bitSize      = 2,
            mode         = "RO",
            pollInterval = 1,
        ))

        self.add(pr.RemoteVariable(
            name         = "TimeOut",
            description  = "Counter value of the last received TimeCode",
            offset       = 0x604,
            bitSize      = 2,
            mode         = "RO",
            pollInterval = 1,
        ))

        self.add(pr.RemoteVariable(
            name         = "AutoStart",
            description  = "Enables automatic link start on receipt of a NULL token",
            offset       = 0x800,
            bitSize      = 1,
            base         = pr.Bool,
            mode         = "RW",
        ))

        self.add(pr.RemoteVariable(
            name         = "LinkStart",
            description  = "Enables spontaneous link start",
            offset       = 0x804,
            bitSize      = 1,
            base         = pr.Bool,
            mode         = "RW",
        ))

        self.add(pr.RemoteVariable(
            name         = "LinkDisable",
            description  = "Do not start link and/or disconnect current link",
            offset       = 0x808,
            bitSize      = 1,
            base         = pr.Bool,
            mode         = "RW",
        ))

        self.add(pr.RemoteVariable(
            name         = "TxPrescaler",
            description  = "Scaling factor minus 1 for TX bitrate",
            offset       = 0x80C,
            bitSize      = 8,
            mode         = "RW",
        ))

        self.add(pr.RemoteVariable(
            name         = "Sendtick",
            description  = "Enable sending time codes",
            offset       = 0x810,
            bitSize      = 1,
            base         = pr.Bool,
            mode         = "RW",
        ))

        self.add(pr.RemoteVariable(
            name         = "SendtickTimeout",
            description  = "Number of system clock cycles between sending timecodes",
            offset       = 0x814,
            bitSize      = 32,
            mode         = "RW",
        ))

        self.add(pr.RemoteVariable(
            name         = "LinkDownBlowOff",
            description  = "When TRUE, blows off the inbound AXI stream (require from back pressuring software) when the link is down",
            offset       = 0x818,
            bitSize      = 1,
            base         = pr.Bool,
            mode         = "RW",
        ))

        self.add(pr.RemoteVariable(
            name         = "RollOverEn",
            description  = "Status Counter rollover enable bitmask",
            offset       = 0xFF8,
            bitSize      = 13,
            mode         = "RW",
        ))

        self.add(pr.RemoteVariable(
            name         = "CntRst",
            description  = "Status Counter Reset",
            mode         = 'WO',
            offset       = 0xFFC,
            hidden       = True,
        ))

    def hardReset(self):
        self.CntRst.set(0x1)

    def softReset(self):
        self.CntRst.set(0x1)

    def countReset(self):
        self.CntRst.set(0x1)
