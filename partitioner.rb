require_relative 'circuit'

class Partitioner

  def initialize c
    @circuit=c
  end

  def group_by &criteria    
    partition= @circuit.components.group_by(&criteria)
    puts "size= #{partition.size}"
    result=Circuit.new("result")
    @circuit.all_ports.each do |p| 
      np=Port.new(p.name,p.dir)
      result.add(np)
      np.set_param(p.params)
    end

    @processed_wires=[]

    partition.each do |part,elements|
       pc=Circuit.new(part.to_s)
       elements.each do |c|
        cclone=Object::const_get(c.class.to_s).new(c.name,c.params)
        if cclone.all_ports.size==0 #ports not in constructor
          c.all_ports.each { |p| cclone.add Port.new(p.name,p.dir) }
        end
        pc.add cclone
       end
       result.add(pc)
    end

    partition.each do |part,circuits|
      partc=result.component_with_name(part.to_s)
      circuits.each do |c|

        c.inputs.each do |inp|
          inpclone=partc.component_with_name(c.name).port_with_name(:in,inp.name)
          w=inp.connections.first #strong limitation
          @processed_wires << w
          w_name=w.name.gsub("(",'').gsub(")",'')
          sor=w.pin.component
          sik=inp.component
          if circuits.include?(sor) and circuits.include?(sik) #sor and sik in same part
            pso=partc.component_with_name(sor.name).port_with_name(:out,w.pin.name)
            psi=partc.component_with_name(sik.name).port_with_name(:in,w.pout.name)
            pso.connect(psi)
          else #sor and sik in different partitions / or top @circuit
            if sor==@circuit
              port_so=result.port_with_name(:in,w.pin.name)
              port_si=partc.component_with_name(sik.name).port_with_name(:in,w.pout.name)
              tmp=Port.new(w_name,:in)
              tmp.set_param(port_so.params)
              partc.add(tmp)
              port_so.connect(tmp)
              tmp.connect(port_si)
            else
              part_sor_name=partition.select{|part, circuits| circuits.find{|c| c.name==sor.name}!=nil}.keys.first.to_s
              part_sor=result.component_with_name(part_sor_name)
              raise "NIL" if part_sor==nil
              part_sik=partc
              comp_sor=part_sor.component_with_name(sor.name)
              comp_sik=part_sik.component_with_name(sik.name)
              raise "NIL" if comp_sik==nil
              port_sor=comp_sor.port_with_name(:out,w.pin.name)
              port_sik=comp_sik.port_with_name(:in,w.pout.name)
              tmp1=Port.new(w_name,:out)
              tmp1.set_param(port_sor.params)
              tmp2=Port.new(w_name,:in)
              tmp2.set_param(port_sik.params)
              part_sor.add(tmp1)
              part_sik.add(tmp2)
              port_sor.connect(tmp1) 
              tmp1.connect(tmp2)
              tmp2.connect(port_sik)
            end
          end
        end #c.inputs.each
        
        c.outputs.each do |outp|
          w=outp.connections.first #strong limitation
          @processed_wires.collect{|w| w.name}
          if not (@processed_wires.include? w)
            @processed_wires << w
            w_name=w.name.gsub("(",'').gsub(")",'')
            sor=outp.component
            sik=w.pout.component
            if circuits.include?(sor) and circuits.include?(sik) #sor and sik in same part
              pso=partc.component_with_name(sor.name).port_with_name(:out,w.pin.name)
              psi=partc.component_with_name(sik.name).port_with_name(:in,w.pout.name)
              pso.connect(psi)
            else
              if sik==@circuit
                port_si=result.port_with_name(:out,w.pout.name)
                port_so=partc.component_with_name(sor.name).port_with_name(:out,w.pin.name)
                tmp=Port.new(w_name,:out)
                tmp.set_param(port_so.params)
                partc.add(tmp)
                port_so.connect(tmp)
                tmp.connect(port_si)
              else # treated by inputs loop?
              end
            end
          end
        end #c.outputs.each

      end
    end

    return result
  end
end
