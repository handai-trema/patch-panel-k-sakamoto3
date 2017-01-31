# Software patch-panel.
class PatchPanel < Trema::Controller
  def start(_args)
    @patch = Hash.new { |hash, key| hash[key]=[] }
    @mirror = Hash.new { |hash, key| hash[key]=[] }
    logger.info 'PatchPanel started.'
  end

  def switch_ready(dpid)
    @patch[dpid].each do |port_a, port_b|
      delete_flow_entries dpid, port_a, port_b
      add_flow_entries dpid, port_a, port_b
    end
  end

  def create_patch(dpid, port_a, port_b)
    add_flow_entries dpid, port_a, port_b
    @patch[dpid] << [port_a, port_b].sort
#    @patch[dpid].each do |port_c, port_d|
#      puts "saka #{port_c} | #{port_d}"
#    end
  end

  def delete_patch(dpid, port_a, port_b)
    delete_flow_entries dpid, port_a, port_b
    @patch[dpid].delete([port_a, port_b].sort)
  end

  def create_mirror(dpid, port_monitored, port_monitoring)
#    print(dpid)
#    print(port_monitored)
#    print(port_monitoring)
#    print("--")
    add_mirror_entries dpid, port_monitored, port_monitoring
    @mirror[dpid] << [port_monitored, port_monitoring].sort
  end

  def delete_mirror(dpid, port)
  end

  def list_pm()
    li = Array.new()
    li << @patch
    li << @mirror
    return li
  end

  private

  def add_flow_entries(dpid, port_a, port_b)
    send_flow_mod_add(dpid,
                      match: Match.new(in_port: port_a),
                      actions: SendOutPort.new(port_b))
    send_flow_mod_add(dpid,
                      match: Match.new(in_port: port_b),
                      actions: SendOutPort.new(port_a))
  end

  def delete_flow_entries(dpid, port_a, port_b)
    send_flow_mod_delete(dpid, match: Match.new(in_port: port_a))
    send_flow_mod_delete(dpid, match: Match.new(in_port: port_b))
  end

  def add_mirror_entries(dpid, port_monitored_src, port_monitoring)
    port_monitored_dst = 0
#    puts "douda"
#    puts "#{@patch[dpid][0][0]}"
#    puts "#{@patch[dpid][0][1]}"
#    puts "douda"
    @patch[dpid].each do |port_a, port_b|
      if port_a == port_monitored_src then
#        print(port_b)
#        print("bkita")
        port_monitored_dst = port_b
        break
      elsif port_b == port_monitored_src then
#        print(port_a)
#        print("akita")
        port_monitored_dst = port_a
        break
      end
    end
    print(port_monitored_dst)
    if port_monitored_dst == 0 then
#      puts "kityatta"
    else
#      puts "kityattane"
#      puts "#{port_monitored_src}"
      send_flow_mod_delete(dpid, match: Match.new(in_port: port_monitored_src))
      send_flow_mod_delete(dpid, match: Match.new(in_port: port_monitored_dst))
      send_flow_mod_add(dpid,
                        match: Match.new(in_port: port_monitored_src),
                        actions: [
                          SendOutPort.new(port_monitored_dst),
                          SendOutPort.new(port_monitoring)
                        ])
      send_flow_mod_add(dpid,
                        match: Match.new(in_port: port_monitored_dst),
                        actions: [
                          SendOutPort.new(port_monitored_src),
                          SendOutPort.new(port_monitoring)
                        ])
    end
  end

end
