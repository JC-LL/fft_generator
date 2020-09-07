-- -----------------------------------------
--      Automatically generated
-- (c) JC LE LANN - ENSTA Bretagne 2013
--    lelannje@ensta-bretagne.fr
-- -----------------------------------------
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use ieee.math_real.all;

library fft_lib;
use fft_lib.fft_pkg.all;

entity reversal is
  generic (N : natural := 8);
  port(
    x : in  sample_array;
    y : out sample_array);
end reversal;

architecture dataflow of reversal is

  function log2_float(val : natural) return natural is
  begin
    return integer(ceil(log2(real(val))));
  end function;

  constant LOG2_N : natural := log2_float(N);

  function reverse(a : in std_logic_vector)
    return std_logic_vector is
    variable result : std_logic_vector(a'range);
    alias aa        : std_logic_vector(a'reverse_range) is a;
  begin
    for i in aa'range loop
      result(i) := aa(i);
    end loop;
    return result;
  end;  -- function reverse_any_vector /  Jonathan Bromley

  function reverse_index(i : in natural)
    return natural is
    variable result : natural;
  begin
    return to_integer(unsigned(reverse(std_logic_vector(to_unsigned(i, LOG2_N)))));
  end;
  
begin

  GEN : for i in 0 to N-1 generate
    y(i) <= x( reverse_index(i) );
  end generate GEN;
  
end dataflow;
