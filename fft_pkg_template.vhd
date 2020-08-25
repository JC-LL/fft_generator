-- -----------------------------------------
--      automatically generated
--  date : <%= Time.now.strftime("%A %d %B %Y %H:%M") %>
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

  constant MAX_WIRES : natural := <%=N*(Math.log2(N)+1).to_i%>+<%=N%>;

  type sample_array  is array (0 to <%=N-1%>) of complex;

  type wire_array  is array (1 to MAX_WIRES) of complex;
  
  signal wire_probes : wire_array;
  
  <%twiddles.each do |bfly,tw|%>
  constant twiddle_<%=bfly%> : complex := ( to_sfixed(<%=tw.real%>,QM,-QN),to_sfixed(<%=tw.imag%>,QM,-QN) ); <%end %>
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
