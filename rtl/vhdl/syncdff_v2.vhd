--
--  Double flip-flop synchronizer.
--
--  This entity is used to safely capture asynchronous signals.
--
--  An implementation may assign additional constraints to this entity
--  in order to reduce the probability of meta-stability issues.
--  For example, an extra tight timing constraint could be placed on
--  the data path from syncdff_ff1 to syncdff_ff2 to ensure that
--  meta-stability of ff1 is resolved before ff2 captures the signal.
--
--  This package depends on https://github.com/slaclab/surf

library ieee;
use ieee.std_logic_1164.all;

library surf;
use surf.StdRtlPkg.all;

entity syncdff is
   generic (
      TPD_G : time := 1 ns);
   port (
      clk : in  sl;                     -- clock (destination domain)
      rst : in  sl;                     -- asynchronous reset, active-high
      di  : in  sl;                     -- input data
      do  : out sl);                    -- output data
end entity syncdff;

architecture mapping of syncdff is

begin

   U_Sync : entity surf.Synchronizer
      generic map (
         TPD_G          => TPD_G,
         RST_POLARITY_G => '1',         -- '1' for active HIGH reset,
         OUT_POLARITY_G => '1',         -- '1' for active HIGH
         RST_ASYNC_G    => true,        -- asynchronous reset
         STAGES_G       => 2)
      port map (
         clk     => clk,
         rst     => rst,
         dataIn  => di,
         dataOut => do);

end mapping;
