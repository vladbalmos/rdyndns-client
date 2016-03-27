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
require "yaml"

DEFAULT_NSUPDATE_PATH = '/usr/bin/nsupdate'
DEFAULT_TTL = 60

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
    unless File.file? filepath.to_s
        abort error_msg
    end
end

def validate_is_int(value, error_msg)
    unless value.is_a? Numeric || value < 1
        abort error_msg
    end
end

def get_options_from_config(config_filepath)
    cfg = YAML.load_file config_filepath

    unless cfg.key? 'nsupdate'
        cfg['nsupdate'] = DEFAULT_NSUPDATE_PATH
    end

    unless cfg.key? 'ttl'
        cfg['ttl'] = DEFAULT_TTL
    end

    return cfg
end

def prepare_options(commandline_options)
    if !commandline_options.config_path.nil?
        options = get_options_from_config commandline_options.config_path
    else
        options = commandline_options.to_h
    end

    validate_ip commandline_options.ip
    options['ip'] = commandline_options.ip
    validate_not_nil options['server'], "The domain nameserver is required!"
    validate_not_nil options['domain'], "The domain name is required!"
    validate_not_nil options['zone'], "The zone is required!"
    validate_is_int options['ttl'], "The ttl must be an integer greater than 0."
    validate_file_exists options['private_key_path'], "The private key file was not found!"
    validate_file_exists options['nsupdate'], "The nsupdate utility was not found!" 

    return options
end

def make_nsupdate_command(options)
    puts options

    command = "#{options['nsupdate']}"
    command += " -k #{options['private_key_path']}"

    if options['nsupdate_debug_flag']
        command += " -d"
    end

    if options['nsupdate_port'].to_i > 0
        command += " -p #{options['nsupdate_port']}"
    end

    if options['nsupdate_timeout'].to_i > 0
        command += " -t #{options['nsupdate_timeout']}"
    end

    return command
end

##################################
# Parse the command line arguments
##################################
commandline_options = OpenStruct.new
commandline_options.ip = nil
commandline_options.server = nil
commandline_options.domain = nil
commandline_options.zone = nil
commandline_options.private_key_path = nil
commandline_options.config_path = nil
commandline_options.ttl = DEFAULT_TTL
commandline_options.nsupdate = DEFAULT_NSUPDATE_PATH
commandline_options.nsupdate_debug_flag = false
commandline_options.nsupdate_port = nil
commandline_options.nsupdate_timeout = nil

opt_parser = OptionParser.new do |opts|
    opts.banner = "Usage: rdyndns-update.rb --ip=IP_ADDRESS [--config=/path/to/config || [options]]"
    opts.separator ""
    opts.separator "Options:"

    opts.on('-i', '--ip IP_ADDRESS',
            'Ip address for the domain.') do |ip|
        commandline_options.ip = ip

        validate_ip ip
    end

    opts.on('-c', '--config CONFIG_PATH',
            'Optional configuration file path in YAML format. Must contain the same keys as the command line arguments.') do |config_path|
        commandline_options.config_path = config_path

        validate_file_exists config_path, "The configuration file was not found!"
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

    opts.on('-n', '--nsupdate NSUPDATE_BIN_PATH',
            'The path to the nsupdate utility. Defaults to /usr/bin/nsupdate') do |nsupdate_bin_path|
        commandline_options.nsupdate = nsupdate_bin_path
    end

    opts.on('--nsupdate_debug', 'Enable nsupdate debugging.') do
        commandline_options.nsupdate_debug = true
    end

    opts.on('--nsupdate_port PORT', 'Set the remote port for the NS.') do |port|
        commandline_options.nsupdate_port = port

        validate_is_int port, "The port must be an integer greater than 0."
    end

    opts.on('--nsupdate_timeout TIMEOUT', 'Maximum time (in seconds) an update request can take before it is aborted.') do |timeout|
        commandline_options.nsupdate_timeout = timeout

        validate_is_int timeout, "The timeout must be an integer greater than 0."
    end

    opts.on('-t', '--ttl SECONDS',
            'TTL value. Defaults to 60 seconds.') do |ttl|
        commandline_options.ttl = ttl
    end

    opts.on_tail("-h", "--help", "Show this message") do
        puts opts
        exit
    end
end
opt_parser.parse!(ARGV)

###############################
# Validate and prepare options
###############################
options = prepare_options commandline_options

update_command = <<-EOT
server #{options['server']}
zone #{options['zone']}
update delete #{options['domain']}. A
update add #{options['domain']}. #{options['ttl']} A #{options['ip']}
send
EOT


nsupdate_command = make_nsupdate_command options

Open3.popen3 nsupdate_command do |stdin, stdout, stderr|
    stdin.puts update_command
    stdin.close
    stderr.each_line { |line| puts line }
    stdout.each_line { |line| puts line }
end
