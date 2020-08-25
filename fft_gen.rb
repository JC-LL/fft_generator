# -*- coding: utf-8 -*-
require 'pp'
require 'erb'

require_relative 'circuit'

PI=Math::PI

def bit_reversal x
  puts "bit_reversal..."
  indexes=(0..x.size-1).collect{|i| i.to_s(2).rjust(Math.log2(N),'0').reverse.to_i(2)}
  pp indexes.collect{|e| e.to_s(2)}
  indexes.collect{|i| x[i]}
end

def swap m,n,x
  puts "swapping bits #{m} and #{n}..."
  #pp x.collect{|i| i.component.name+i.name}
  nbbits_m1=Math.log2(N)-1
  indexes=(0..x.size-1).collect do |i|
    print "#{i} ->"
    str=i.to_s(2).rjust(nbbits_m1+1,'0')
    str[nbbits_m1-n],str[nbbits_m1-m]=str[nbbits_m1-m],str[nbbits_m1-n]
    puts "#{str.to_i(2)}"
    str.to_i(2)
  end
  pp indexes
  indexes.collect{|i| x[i]}
end 


def reorder inputs, stage
  puts "reordering #{inputs.size} inputs for next stage #{stage}..."
  pp inputs.collect{|i| i.component.name+i.name}
  swap 0,stage,inputs
end

def swap_composition inputs
  puts "\nfinal swap_composition for outputs..."
  nbits=Math.log2(inputs.size).to_i
  outputs=inputs
  for i in 0..nbits-2
    outputs=swap i, i+1, outputs
  end
  return outputs
end
  
class Butterfly < Circuit
  attr_accessor :position,:params

  def initialize id,params
    super(id)
    puts "butterfly #{id} at #{position}"
    # @params[:position]=position
    # @position=position
    @params.merge!(params)
    self.add Port.new("i0",:in)
    self.add i1=Port.new("i1",:in)
    self.add Port.new("o0",:out)
    self.add Port.new("o1",:out)
    @log2m1=Math.log2(N)-1
    c1,c2,c3,tw=twiddle_factor()
    puts "twiddle_factor #{position} #{c1} #{c2} #{c3} : #{tw}"
    i1.set_param :twiddle => tw
  end

  # def twiddle_factor
  #   s,r=@params[:position]
  #   c1=(r*2**(s+1)/N).floor
  #   c2=c1.to_s(2).rjust(@log2m1,'0')
  #   c3=c2.reverse.to_i(2)
  #   return [c1,c2,c3,w(c3)]
  # end

  def twiddle_factor
    s,r=@params[:position]
    high= r % (2**s)
    low = 2**(s+1)
    return [[s,r],high,low,ww(high,low)]
  end

  def ww(n,m)
    Math::E ** Complex(0,-2*PI*n/m)
  end

  def w(n)
    Math::E ** Complex(0,-2*PI*n/N)
  end

end

class Reversal < Circuit
  attr_accessor :homologue
  def initialize id,params
    super(id)
    @params.merge!(params)
    n=params[:size]
    for i in 0..n-1
      self.add Port.new("i#{i}",:in)
      self.add Port.new("o#{i}",:out)
    end
  end
end

class SystemFFT < Circuit

  def initialize nsamples
    super(:fft)
    @nsamples=nsamples
    inputs = build_inputs()
    reversal=Reversal.new("rev",:size =>N)
    self.add reversal
    inputs.each_with_index do |input,idx|
      input.connect reversal.ports[:in][idx]
    end

    #inputs = bit_reversal(inputs)
    inputs = reversal.ports[:out]
    outputs=[]
    log2m1=Math.log2(@nsamples)-1
    @nb_stages=log2m1.to_i+1
    for stage in 0..log2m1
      puts "stage #{stage}".center(40,"=")
      outputs=[]
      (0..@nsamples-1).step(2) do |row|
        id="b"+stage.to_s+"_"+(row/2).to_s
        bfly= Butterfly.new(id,:position =>[stage,row/2])
        #blfy.position=[stage,row/2]
        self.add(bfly)
        inputs[row].connect bfly.ports[:in][0]
        inputs[row+1].connect bfly.ports[:in][1]
        outputs << bfly.ports[:out]
      end
      inputs=reorder(outputs.flatten!,stage+1) if stage !=Math.log2(N)-1
    end
    inputs=swap_composition(outputs.flatten!)
    
    inputs.each_with_index do |o,idx|
      pout=Port.new("y#{idx}",:out)
      self.add pout
      o.connect pout
    end
  end

  def build_inputs
    self.add *(0..@nsamples-1).collect{|e| Port.new("x#{e}",:in)}
  end

  def code str
    (@code ||=[]) << str
  end


  def get_twiddles
    bflies = self.components.select{|c| c.class==Butterfly}
    twiddles=bflies.inject({}) do |hres,c|
      hres[c.name]=approx(c.ports[:in].last.params[:twiddle])
      hres
    end
  end

  def approx cmp,ratio=1e4 #complex
    ret=cmp
    real=cmp.real
    imag=cmp.imag
    if imag !=0
      rapp=(real/imag).abs
      puts "rapport =#{rapp}"
      if rapp < 1
        rapp=1.0/rapp
        if rapp>ratio
          ret=Complex(0,imag)
        end
      else
        if rapp>ratio
          ret=Complex(real,0)
        end
      end
    end
    puts "approximation of #{cmp} -> #{ret}"
    return ret
  end

  def to_vhdl
    puts "generating VHDL...for circuit #{self.name}"
    gen_pkg()
    gen_entity()
    modify_tb()
  end

  def gen_entity
    #============================================================================
    puts "generating VHDL entity...#{self.name}"
    #port_decl =  self.ports[:in].collect{|p|  "    #{p.name} : in  complex;"}
    #port_decl << self.ports[:out].collect{|p| "    #{p.name} : out complex;"}
    port_decl =  "    x : in  sample_array;\n"
    port_decl << "    y : out sample_array;"
      
    #sig_decl  =  self.wires.collect{|w| "  signal #{w.name} : complex;"}
    sig_decl   =  "  signal w  : wire_array;\n"
    sig_decl  <<  "  signal xx : sample_array;"

    port_maps={}
    self.components.each do |c|
      port_maps[c.name]=[]
      c.ports[:in].each do |pin|
        port_maps[c.name] << {pin.name => pin.connections.last.name}
      end
      c.ports[:out].each do |pin|
        port_maps[c.name] << {pin.name => pin.connections.first.name}
      end
    end

    pp port_maps
    
    h={}
    port_maps_str=port_maps.each do |c,tab|
      h[c]=tab.collect{|e| e.values}.join(",")
    end
    inputs_connect=   "   --synthesis off\n"
    inputs_connect<<   "  wire_probes <= w;\n"
    inputs_connect<<   "  -- synthesis on\n\n"
    inputs_connect<<   "  inputs_w: for i in 0 to N-1 generate\n"
    inputs_connect<<  "    w(i+1)   <=  x(i); --for genericity of sw model only(not used)\n"
    inputs_connect<<  "    w(i+1+N) <= xx(i); --outputs of reversal\n"
    inputs_connect<<  "  end generate;\n"

    outputs_connect=   "  outputs_w: for i in 0 to N-1 generate\n"
    outputs_connect << "    y(i) <= w(MAX_WIRES-N+1 +i);\n" 
    outputs_connect << "  end generate;\n"


    map=(1..2*N).collect{|i| "w(#{i})"}.join(",")
    reversal = 
    "  REV_COMP : entity fft_lib.reversal(dataflow)
         generic map(N)
         port map(x,xx);\n"

    bflies = self.components.select{|c| c.class==Butterfly}
    arch_body =  bflies.collect do |c|
      s,r=c.params[:position]
      "  STAGE_#{s}_ROW_#{r} : entity fft_lib.butterfly(RTL)
         generic map(twiddle_factor => twiddle_#{c.name})
         port map(#{h[c.name]});\n"
    end
    #======================================================
    code "-- -----------------------------------------"
    code "--      Automatically generated"
    code "-- (c) JC LE LANN - ENSTA Bretagne 2013"
    code "--    lelannje@ensta-bretagne.fr"
    code "-- -----------------------------------------"
    code "library ieee;"
    code "use ieee.std_logic_1164.all;"
    code "use ieee.numeric_std.all;"
    code ""
    #code "library ieee_proposed;"
    #code "use ieee_proposed.fixed_float_types.all;"
    #code "use ieee_proposed.fixed_pkg.all;"
    code ""
    code "library fft_lib;"
    code "use fft_lib.fft_pkg.all;"
    code ""
    code "entity FFT is"
    code "  generic (N: natural := #{N});"
    code "  port("
    code port_decl
    code "  );"
    code "end FFT;"
    code ""
    code "architecture dataflow of FFT is"
    code ""
    code sig_decl
    code ""
    code "begin"
    code ""
    code inputs_connect
    code ""
    code reversal
    code "" 
    code arch_body
    code ""
    code outputs_connect
    code ""
    code "end dataflow;"
    #======================================================
    @code=@code.join("\n")
    @code=clean()
    filename=self.name.to_s+".vhd"
    f=File.open(filename,'w')
    f.puts @code
    f.close
  end

  def clean
    @code.gsub(/;\s+\)/,"\)")
  end

  def gen_pkg
    puts "generating package..."
    twiddles=get_twiddles()
    erb = ERB.new( File.open( "fft_pkg_template.vhd" ).read )
    code = erb.result( binding )
    filename = "fft_pkg.vhd"
    print "Creating #{filename}\n"
    File.open(filename, "w" ) do |f|
      f.write( code )
    end
  end

  def modify_tb
    tb=IO.read("fft_tb.vhd")
    tb[/constant N : natural := (\d+);/]="constant N : natural := #{N};"
    f=File.open("fft_tb.vhd","w")
    f.puts tb
    f.close
  end

  #==========================================================================
  def to_xpu stage
    puts "to_xpu experiment 1".center(80,'=')
    puts "mapping parameter : stage_start=#{stage}".center(80,'.')
    map_on_tasks(stage)
  end

  def map_on_tasks(stage_start)
    @xpu_arch=Circuit.new("xpu")
    step1_build_hierarchy(stage_start)
    step2_connect_inter_task()
    step3_connect_intra_task()
    @xpu_arch.to_dot
    #system("dot -Tpng xpu.dot -o xpu.png ; eog xpu.png")
  end
  
  def step1_build_hierarchy(stage_start)
    puts "building hierarchy".center(40,'=')
    @homologues={}
    @mapped_on={}

    @mapped_on[self]=@xpu_arch

    @xpu_arch=Circuit.new("xpu")
    nb_rows=2**(@nb_stages-stage_start-1)

    self.inputs.each do |port|
      name=port.name+"_"+port.connections.first.name.gsub("(",'').gsub(")",'')
      p = Port.new(name,port.dir)
      @xpu_arch.add p
      @mapped_on[port]=@xpu_arch
      @homologues[port]=p
    end
    self.outputs.each do |port|
      name=port.name+"_"+port.connections.first.name.gsub("(",'').gsub(")",'')
      p = Port.new(name,port.dir)
      @xpu_arch.add p
      @mapped_on[port]=@xpu_arch
      @homologues[port]=p
    end
    
    seq_task=Circuit.new("sequential")
    @xpu_arch.add(seq_task)
    self.inputs.each do |port|
      name=port.connections.first.name.gsub("(",'').gsub(")",'')
      p = Port.new(name,:in)
      seq_task.add p
      @homologues[port]=p
    end


    self.components.each do |comp|
      
      if comp.is_a? Butterfly
        stage,row=comp.position
        print "#{comp.name} -> #{comp.position} : "
        if stage >= stage_start
          tid=row % 2**stage_start
          task_id=("parallel_"+stage_start.to_s+"_"+nb_rows.to_s+"_"+tid.to_s).to_sym
          nb_ports=2**stage_start
          if (task=@xpu_arch.components.find{|c| c.name==task_id})==nil
            task = create_task(task_id)
            add_dedicated_ports(:in,task,comp)
          elsif stage == stage_start
            add_dedicated_ports(:in,task,comp)
          elsif stage == @nb_stages-1
            add_dedicated_ports(:out,task,comp)
          end
          butterfly=Butterfly.new(comp.name, :position => comp.position)
          @homologues[comp]=butterfly
          task.add(butterfly)
          @mapped_on[comp]=task
        else 
          puts "#{comp.class} mapped in sequential task"
          bfly=Butterfly.new(comp.name, :position => comp.position)
          # bfly.position=comp.position
          @homologues[comp]=bfly
          seq_task.add(bfly)
          @mapped_on[comp]=seq_task
          if stage == stage_start-1
            comp.outputs.each do |p|
              name=p.connections.first.name.gsub("(",'').gsub(")",'')
              p2=Port.new(name,:out)
              @homologues[p]=p2
              seq_task.add(p2)
            end
          end
        end
      elsif comp.is_a? Reversal
        puts "#{comp.class} mapped in sequential task"
        rev = Reversal.new("xpurev",:size=>N)
        seq_task.add(rev)
        @homologues[comp]=rev              
        @mapped_on[comp]=seq_task
      end
    end
  end

  def step2_connect_inter_task
    puts "step2_connect_inter_task".center(40,'=')
    # build a hash to accelerate detection of mapping during connect
    hash={}
    hash[:in]={}
    hash[:out]={}
    @xpu_arch.components.each do |c|
      c.inputs.each do |i|
        hash[:in][i.name[/.*(w\d+)/,1]]=c
      end
      c.outputs.each do |o|
        hash[:out][o.name[/.*(w\d+)/,1]]=c
      end
    end
    pp hash[:in].keys
    pp hash[:out].keys
    
    #===== now connect
    @xpu_arch.inputs.each do |i|
      id=i.name[/.*(w\d+)/,1]
      hash[:in][id].inputs.collect{|e| e.name}
      i.connect hash[:in][id].port_with_name(:in,id),"nw"
    end
    @xpu_arch.components.each do |c|
      c.outputs.each do |o|
        id=o.name[/.*(w\d+)/,1]
        if comp=hash[:in][id]
          o.connect comp.port_with_name(:in,id)
        else # target is one of xpu_arch outputs
          xoutput=@xpu_arch.outputs.find{|p| p.name=~/#{id}/}
          o.connect xoutput,"nw"
        end
      end
    end
  end

  #===========================================================
  def step3_connect_intra_task
    puts "step3_connect_intra_task".center(40,'=')
    print_mapping()
    self.components.each do |c|
      puts c.name.center(40,"-")
      task=@mapped_on[c]

      c.inputs.each do |sink_pin|
        wire = sink_pin.connections.first
        source_pin = wire.pin
        source = source_pin.component
        puts "#{source.name}.#{source_pin.name} ----#{wire.name}---> #{c.name}.#{sink_pin.name}"
        map_comp_source=@mapped_on[source]
        map_comp_sink  =@mapped_on[c]
        #puts "on #{map_comp_source.name} ---> on #{map_comp_sink.name}"
        if map_comp_source==map_comp_sink
          #connect them
          hsour=@homologues[source]
          hsink=@homologues[c]
          hsour_p=hsour.port_with_name(:out,source_pin.name)
          hsink_p=hsink.port_with_name(:in ,sink_pin.name)
          hsour_p.connect(hsink_p)
        else
          if source!=self
            puts "link between two (internal) tasks"
            wname=wire.name.gsub("(",'').gsub(")",'')
            puts inp=map_comp_sink.port_with_name(:in,wname)
            puts hsink=@homologues[c]
            puts sink_pin.name
            puts hsink_p=hsink.port_with_name(:in ,sink_pin.name)
            inp.connect(hsink_p)
          else
            puts "link between top-level and task"
          end
        end
      end

      c.outputs.each do |source_pin|
        wire = source_pin.connections.first
        sink_pin = wire.pout
        sink = sink_pin.component
        puts "#{c.name}.#{source_pin.name} ----#{wire.name}---> #{sink.name}.#{sink_pin.name}"
        map_comp_source=@mapped_on[c]
        map_comp_sink  =@mapped_on[sink]
        #puts "on #{map_comp_source.name} ---> on #{map_comp_sink.name}"
        if map_comp_source==map_comp_sink
          #connect them
          hsour=@homologues[c]
          hsink=@homologues[sink]
          hsour_p=hsour.port_with_name(:out,source_pin.name)
          hsink_p=hsink.port_with_name(:in ,sink_pin.name)
          hsour_p.connect(hsink_p)
        else
          if sink!=self
            puts "out/link between two (internal) tasks"
            wname=wire.name.gsub("(",'').gsub(")",'')
            sop=@homologues[c].port_with_name(:out,source_pin.name)
            puts "source:"+sop.name
            sik=map_comp_source.port_with_name(:out,wname)
            puts "sink:"+sik.name
            sop.connect(sik)
          else
            puts "link between top-level and task"
          end
        end
      end

      
    end
    @xpu_arch.components.each do |c|
      c.to_dot
      system("dot -Tpng #{c.name}.dot -o #{c.name}.png ; eog #{c.name}.png")
    end
  end

  

  def print_mapping
    @mapped_on.each do |k,v|
      puts "(#{k.class}) #{k.name} on #{v.name}"
    end
  end

  def add_dedicated_ports dir,task,comp
    input_name_list  = comp.inputs.collect{|i| i.connexions.first.name.gsub("(",'').gsub(")",'')}
    output_name_list = comp.outputs.collect{|i| i.connexions.first.name.gsub("(",'').gsub(")",'')}
    if dir==:in
      for i in input_name_list
        p = Port.new(i,:in)
        task.add(p)
      end
    else
      for o in output_name_list
        p = Port.new(o,:out)
        task.add(p)
      end
    end
  end

  def create_task task_id
    puts "creating XPU task #{task_id}"
    task=Circuit.new(task_id)
    @xpu_arch.add(task)
    return task
  end
end


#N=64
N=ARGV[0].to_i
fft=SystemFFT.new(N)

# c=Complex("0.0000001+i")
# fft.approx c
# gets

# c=Complex("1+0.00001i")
# fft.approx c
# gets

fft.to_dot
system("dot -Tpng fft.dot -o fft.png ; eog fft.png")
#start_parallel_row=3
start_parallel_row=ARGV[1].to_i



#fft.to_xpu(start_parallel_row)
fft.to_vhdl
system("more fft.vhd")
#system("./compile.x")

require_relative 'partitioner'
result=Partitioner.new(fft).group_by do |criteria|  
end
result.to_dot
#result.view
puts result.components.collect{|c| c.name}
