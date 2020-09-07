library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use work.fft_pkg.all;

entity butterfly is
  generic (
    twiddle_factor : complex);
  port (
    i0, i1 : in  complex;
    o0, o1 : out complex);
end butterfly;

architecture RTL of butterfly is
begin  
  o0 <= i0 + i1*twiddle_factor;
  o1 <= i0 - i1*twiddle_factor;
end RTL;
