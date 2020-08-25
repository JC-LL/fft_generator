-- -----------------------------------------
--      automatically generated
--  date : Tuesday 25 August 2020 13:50
--  JC LE LANN - ENSTA Bretagne 2013
--    lelannje@ensta-bretagne.fr
-- -----------------------------------------
library ieee;

use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

library ieee_proposed;
use ieee_proposed.fixed_float_types.all;
use ieee_proposed.fixed_pkg.all;

package fft_pkg is

  constant QM : natural := 15;
  constant QN : natural := 7;

  type complex is record
    reel : sfixed(QM downto -QN);
    imag : sfixed(QM downto -QN);
  end record;

  constant COMPLEX_ZERO : complex := (to_sfixed(0.0,QM,-QN),to_sfixed(0.0,QM,-QN));
  
  function "+"(x : complex; y : complex) return complex;
  function "-"(x : complex; y : complex) return complex;
  function "*"(x : complex; y : complex) return complex;

  constant MAX_WIRES : natural := 32+8;

  type sample_array  is array (0 to 7) of complex;

  type wire_array  is array (1 to MAX_WIRES) of complex;
  
  signal wire_probes : wire_array;
  
  
  constant twiddle_b0_0 : complex := ( to_sfixed(1,QM,-QN),to_sfixed(0,QM,-QN) ); 
  constant twiddle_b0_1 : complex := ( to_sfixed(1,QM,-QN),to_sfixed(0,QM,-QN) ); 
  constant twiddle_b0_2 : complex := ( to_sfixed(1,QM,-QN),to_sfixed(0,QM,-QN) ); 
  constant twiddle_b0_3 : complex := ( to_sfixed(1,QM,-QN),to_sfixed(0,QM,-QN) ); 
  constant twiddle_b1_0 : complex := ( to_sfixed(1,QM,-QN),to_sfixed(0,QM,-QN) ); 
  constant twiddle_b1_1 : complex := ( to_sfixed(0,QM,-QN),to_sfixed(-1.0,QM,-QN) ); 
  constant twiddle_b1_2 : complex := ( to_sfixed(1,QM,-QN),to_sfixed(0,QM,-QN) ); 
  constant twiddle_b1_3 : complex := ( to_sfixed(0,QM,-QN),to_sfixed(-1.0,QM,-QN) ); 
  constant twiddle_b2_0 : complex := ( to_sfixed(1,QM,-QN),to_sfixed(0,QM,-QN) ); 
  constant twiddle_b2_1 : complex := ( to_sfixed(0.7071067811865476,QM,-QN),to_sfixed(-0.7071067811865475,QM,-QN) ); 
  constant twiddle_b2_2 : complex := ( to_sfixed(0,QM,-QN),to_sfixed(-1.0,QM,-QN) ); 
  constant twiddle_b2_3 : complex := ( to_sfixed(-0.7071067811865475,QM,-QN),to_sfixed(-0.7071067811865476,QM,-QN) ); 
end;

package body fft_pkg is

  function "+"(x : complex; y : complex) return complex is
    variable ret        : complex;
  begin
    ret.reel := resize(x.reel + y.reel,ret.reel);
    ret.imag := resize(x.imag + y.imag,ret.reel);
    return ret;
  end function;

  function "-"(x : complex; y : complex) return complex is
    variable ret        : complex;
  begin
    ret.reel := resize(x.reel - y.reel,ret.reel);
    ret.imag := resize(x.imag - y.imag,ret.reel);
    return ret;
  end function;

  function "*"(x : complex; y : complex) return complex is
    variable ret        : complex;
  begin
    ret.reel := resize((x.reel * y.reel) - (x.imag * y.imag),ret.reel);
    ret.imag := resize((x.reel * y.imag) + (x.imag * y.reel),ret.reel);
    return ret;
  end function;

  
end package body;
