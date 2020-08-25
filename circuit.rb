require 'pp'

VERBOSE=true

class Circuit

  attr_accessor :name,:ports,:components,:wires,:params,:father
  def initialize name
    @name=name
    @ports={:in=>[],:out=>[]}
    @components=[]
    @params={}
    @father=nil
    @wires=[]
  end

  def inputs
    @ports[:in]
  end

  def outputs
    @ports[:out]
  end
  
  def port_with_name dir,name
    @ports[dir].find{|e| e.name==name}
  end

  def component_with_name name
    @components.find{|e| e.name==name}
  end

  def all_ports
    @ports.values.flatten
  end

  def add *elems
    elems.each do |e|
      puts "adding #{e.class} #{e.name} to #{self.name}..." if VERBOSE
      case e
      when Port
        @ports[e.dir] << e
        e.circuit=self
      when Circuit
        e.father=self
        @components << e
      when Wire
        @wires << e
      end
    end
  end

  def to_dot
    str =  "digraph G {\n"
    str << "   graph [rankdir = LR];\n"
    str << "   node[shape=record];\n"
    @components.each do |c|
      inputs_str ="{"+c.ports[:in].collect{|e| "<#{e.name}>#{e.name}"}.join("|")+"}"
      outputs_str="{"+c.ports[:out].collect{|e| "<#{e.name}>#{e.name}"}.join("|")+"}"
      str << "   #{c.name}[  label=\"{ #{inputs_str}| #{c.name} | #{outputs_str} }\"];\n"
    end
    @ports[:in].each do |p|
      str << "   #{p.name};"
    end
    @ports[:out].each do |p|
      str << "   #{p.name};"
    end
    
    @ports[:in].each do |p|
      p.connections.each do |wire|
        pin=wire.pout
        c=p.circuit==self ? "#{p.name}" : "#{p.circuit.name}:#{p.name}"
        if not(pin.circuit.name==self.name and pin.name==c)
          str << "   #{c} -> #{pin.circuit.name}:#{pin.name}[ label=\"#{wire.name}\"];\n"
        end
      end
    end
    @components.each do |c|
      c.ports[:out].each do |p|
        p.connections.each do |wire| #pin
          pout=wire.pout
          c=pout.circuit==self ? "#{pout.name}" : "#{pout.circuit.name}:#{pout.name}"
          if c!=p.circuit.name+":"+p.name
            str << "   #{p.circuit.name}:#{p.name} -> #{c}[label=\"#{wire.name}\"];\n"
          end
        end
      end
    end
    str << "}\n"
    File.open("#{self.name}.dot",'w') do |f|
      f.puts str
    end
  end

  def print_info
    puts "#{self.name}".center(40,'+')
    puts "inputs : (#{inputs.size})"
    inputs.each{|i|  puts "\t- #{i.name}"}
    puts "outputs : (#{outputs.size})"
    outputs.each{|i|  puts "\t- #{i.name}"}
    puts "sub-components : (#{components.size})"
    components.each{|i|  puts "\t- #{i.name}"}
  end

  def view
    system("rm -rf #{name}.dot #{name}.png")
    to_dot()
    system("dot -Tpng #{name}.dot -o #{name}.png ; eog #{name}.png")
  end

end

class Wire
  attr_accessor :name,:pin,:pout,:id
  @@id=0

  def initialize pin,pout,prefix="w"
    @@id+=1
    @id=@@id
    # @name="#{pin.circuit.name}_#{pin.name}_#{pout.name}"
    @name=prefix+"(#{@@id})"
    @pin,@pout=pin,pout
    if @pin.circuit.father
      @pin.circuit.father.add self
    elsif @pout.circuit.father
      @pout.circuit.father.add self
    else
      #in --> out directly on father !
    end
  end

  def Wire.reset
    @@id=0
  end

  def Wire.get_id
    @@id
  end

end

class Port
  attr_accessor :name,:dir,:circuit,:connections,:params

  def initialize name,dir
    @name,@dir=name,dir
    @connections=[]
    @params={}
  end

  def connect port,wire_prefix="w"
    puts port.circuit  if @verbose
    puts "connecting #{self.circuit.name}.#{self.name} -> #{port.circuit.name}.#{port.name}"  if @verbose
    if not @connections.find{|w| w.pout==port}
      @connections << (w=Wire.new(self,port,wire_prefix))
      port.connections << w
    end
  end

  def set_param h
    @params.merge!(h)
  end

  alias :component :circuit
  alias :connexions :connections
end


