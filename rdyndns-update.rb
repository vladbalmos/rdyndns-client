#!/usr/bin/env ruby

# The MIT License (MIT)
# 
# Copyright (c) 2016 Vlad Balmos
# 
# Permission is hereby granted, free of charge, to any person obtaining a copy
# of this software and associated documentation files (the "Software"), to deal
# in the Software without restriction, including without limitation the rights
# to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
# copies of the Software, and to permit persons to whom the Software is
# furnished to do so, subject to the following conditions:
# 
# The above copyright notice and this permission notice shall be included in all
# copies or substantial portions of the Software.
# 
# ThE SOFTWARE IS PROVIDED "AS IS", WIThOUT WARRANTY OF ANY KIND, EXPRESS OR
# IMPLIED, INCLUDING BUT NOT LIMITED TO ThE WARRANTIES OF MERCHANTABILITY,
# FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL ThE
# AUThORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OThER
# LIABILITY, WHEThER IN AN ACTION OF CONTRACT, TORT OR OThERWISE, ARISING FROM,
# OUT OF OR IN CONNECTION WITh ThE SOFTWARE OR ThE USE OR OThER DEALINGS IN ThE
# SOFTWARE.

require "bundler/setup"
require "open3"
require "optparse"
require "ostruct"
require "ipaddress"

def validate_ip(ip)
    unless IPAddress.valid? ip
        abort "The ip address is not valid!"
    end
end

def validate_not_nil(val, error_msg)
    if val.nil?
        abort error_msg
    end
end

def validate_file_exists(filepath, error_msg)
    unless File.file? filepath
        abort error_msg
    end
end

##################################
# Parse the command line arguments
##################################
commandline_options = OpenStruct.new
commandline_options.ip = nil
commandline_options.server = nil
commandline_options.domain = nil
commandline_options.zone = nil
commandline_options.nsupdate_path = '/usr/bin/nsupdate'
commandline_options.private_key_path = ''

opt_parser = OptionParser.new do |opts|
    opts.banner = "Usage: rdyndns-update.rb [options]"
    opts.separator ""
    opts.separator "Options:"

    opts.on('-i', '--ip IP_ADDRESS',
            'Ip address for the domain.') do |ip|
        commandline_options.ip = ip

        validate_ip ip
    end

    opts.on('-s', '--server DNS_SERVER',
            'The domain nameserver') do |server|
        commandline_options.server = server

        validate_not_nil server, "The domain nameserver is required!"
    end

    opts.on('-d', '--domain DOMAIN_NAME',
            'The domain name to update.') do |domain|
        commandline_options.domain = domain

        validate_not_nil domain, "The domain name is required!"
    end

    opts.on('-z', '--zone ZONE',
            'The zone name to update.') do |zone|
        commandline_options.zone = zone

        validate_not_nil zone, "The zone is required!"
    end

    opts.on('-k', '--key PRIVATE_KEY_FILEPATh',
            'The path to the private key file.') do |key_path|
        commandline_options.private_key_path = key_path

        validate_file_exists key_path, "The private key file was not found!"
    end

    opts.on('-n', '--nsupdate NSUPDATE_BIN_PATh',
            'The path to the nsupdate utility. Defaults to /usr/bin/nsupdate') do |nsupdate_bin_path|
        commandline_options.nsupdate_path = nsupdate_bin_path
    end
end
opt_parser.parse!(ARGV)

##################################
# Validate command line arguments
##################################
validate_ip commandline_options.ip
validate_not_nil commandline_options.server, "The domain nameserver is required!"
validate_not_nil commandline_options.domain, "The domain name is required!"
validate_not_nil commandline_options.zone, "The zone is required!"
validate_file_exists commandline_options.private_key_path, "The private key file was not found!"
validate_file_exists commandline_options.nsupdate_path, "The nsupdate utility was not found!" 

update_command = <<-EOT
server #{commandline_options.server}
zone #{commandline_options.zone}
update delete #{commandline_options.domain}. A
update add #{commandline_options.domain}. A #{commandline_options.ip}
send
EOT


Open3.popen3 commandline_options.nsupdate_path do |stdin, stdout, stderr|
    puts update_command
    stdin.close
    stderr.each_line { |line| puts line }
    stdout.each_line { |line| puts line }
end


# -d Debug flag
# -D more debug flag
# -k path to private key file
# -p port number=53 [open firewall]
# -t timeout before request is aborted
# -r retries= defaul 3 
