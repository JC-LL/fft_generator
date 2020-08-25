--  JC LE LANN - ENSTA Bretagne 2013
library ieee, std;

use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use std.textio.all;

library ieee_proposed;
use ieee_proposed.fixed_float_types.all;
use ieee_proposed.fixed_pkg.all;

library fft_lib;
use fft_lib.fft_pkg.all;

entity fft_tb is
end fft_tb;

architecture bhv of fft_tb is
  
  constant N : natural := 8;

  constant HALF_PERIOD : time      := 20 ns;
  signal   clk         : std_logic := '0';
  signal   reset_n     : std_logic;
  signal   running     : boolean   := true;
  --
  --type samples_t is array(0 to N-1) of complex;
  signal   x           : sample_array;  --samples_t;
  signal   y           : sample_array;  --samples_t;
  signal   samples     : sample_array;  --samples_t;
  signal   go          : std_logic := '0';
  shared variable num    : natural := 0;
  
begin  -- bhv
  
  SIG_GEN : for i in 0 to N-1 generate
    x(i) <= samples(i) when go = '1' else COMPLEX_ZERO;
    --x(i) <= COMPLEX_ZERO;
  end generate;

  DUT : entity fft_lib.FFT(dataflow)
    generic map(N => N)
    port map (
      x => x,
      y => y);

  clk     <= not(clk) after HALF_PERIOD when running else '0';
  reset_n <= '0', '1' after 103 ns;

  stimuli : process
    file F          : text;
    variable status : file_open_status;
    variable L      : line;
    variable ok     : boolean;
    variable sample : real;
    variable set : natural :=0;
  begin
    report "starting simulation...";
    report "opening file samples.txt...";
    FILE_OPEN(status, F, "samples.txt", read_mode);
    if status /= open_ok then
      report "failed to open datafile" severity failure;
    else
      report "waiting for reset_n...";
      wait until reset_n = '1';
      report "sending stimuli...";
      while not ENDFILE(F) loop
        wait until rising_edge(clk);
        READLINE(F, L);
        --report "reading line " & integer'image(num);
        READ(L, sample, ok);
        if not(ok) then
          report "line " & integer'image(num) & ": error reading name";
        end if;
        --report "reading time sample " & integer'image(num);
        samples(num) <= (to_sfixed(sample, QM, -QN), to_sfixed(0.0, QM, -QN));
        wait for 1 ns;
        report "sample(" & integer'image(num) & ")= " & to_string(samples(num).reel);
        num          := (num+1) rem N;
        if num = 0 then
          go <= '1';
          set:=set+1;
          report "reading samples set " & integer'image(set);
          wait until rising_edge(clk);
          go <= '0';
        end if;
      end loop;
    end if;
    for i  in 0 to 10 loop
       wait until rising_edge(clk);
    end loop;  -- i 
    report "end of simulation";
    running <= false;
    wait;
  end process;

  -----------------------------------------------------------------------------
  -- For each set of temporal samples, we need to collect the outputs (freq)
  -- but also, for debug : the values on each wire !
  -----------------------------------------------------------------------------
  collect_result : process
    file outfile,probing    : text;
    variable status1,status2 : file_open_status;
    variable buf1,buf2    : line;
    variable set : natural :=0;
  begin
    report "opening file result.txt...";
    FILE_OPEN(status1, outfile, "result.txt", write_mode);
    FILE_OPEN(status2, probing, "wires.txt", write_mode);
    
    if status1 /= open_ok then
      report "failed to open datafile" severity failure;
    elsif status2 /= open_ok then
      report "failed to open wires" severity failure;
    else
      report "waiting for reset_n...";
      wait until reset_n = '1';
      INF_LOOP:while true loop
        wait until falling_edge(clk);
        if go = '1' then                --combinatorial computation
          set := set+1;
          
          report "writing freq samples set " & integer'image(set);
          for i in 0 to N-1 loop 
            write(buf1, to_string(y(i).reel));
            write(buf1, ' ');
            write(buf1, to_string(y(i).imag));
            writeline(outfile, buf1);
          end loop;  -- i
          writeline(outfile, buf1);
          
          report "writing wire probes set " & integer'image(set);
          for i in 1 to MAX_WIRES loop 
            write(buf2, to_string(wire_probes(i).reel));
            write(buf2, ' ');
            write(buf2, to_string(wire_probes(i).imag));
            writeline(probing, buf2);
          end loop;  -- i
          writeline(probing, buf2);
          
        end if;
      end loop;
      file_close(outfile); 
    end if;
  end process;
  
end bhv;
