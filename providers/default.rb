#
# Cookbook Name:: sys_firewall
#
# Copyright RightScale, Inc. All rights reserved.
# All access and use subject to the RightScale Terms of Service available at
# http://www.rightscale.com/terms.php and, if applicable, other agreements
# such as a RightScale Master Subscription Agreement.

# @resource sys_firewall

require "timeout"

# Updates firewall rules on a server
action :update do

  # Set local variables from attributes
  port = new_resource.port ? new_resource.port : new_resource.name
  raise "  ERROR: port must be set" if port == ""
  protocol = new_resource.protocol
  to_enable = new_resource.enable
  ip_addr = new_resource.ip_addr
  machine_tag = new_resource.machine_tag
  ip_tag = new_resource.ip_tag
  target = new_resource.target.upcase
  # For backwards compatibility use the private ip tag if the ip_tag
  # was not passed
  ip_tag = "server:private_ip_0" unless ip_tag
  collection_name = new_resource.collection

  log "  Using machine tags #{machine_tag} and #{ip_tag} to determine" +
    " IP address." if machine_tag 

  # The IP address is either selected explicitly using the ip_addr parameter
  # or by the value of the passed tags.  The parameter ip_addr is always set
  # with the default of 'any'.  Set to nil if the machine tag parameter is
  # passed.
  ip_addr.downcase!
  ip_addr = nil if (ip_addr == "any") && machine_tag # tags win, so clear 'any'
  raise "ERROR: ip_addr param - #{ip_addr} - cannot be used with machine_tag param - #{machine_tag}." if machine_tag && ip_addr

  # Tell user what is going on
  msg = "#{to_enable ? "Enabling" : "Disabling"} firewall rule to"
  msg << " #{target}"
  msg << ( port == 'any' ? " any port" : " port #{port}" )
  msg << " for address #{ip_addr}" if ip_addr
  msg << " using protocol #{protocol}." if protocol
  log msg

  # Update rules
  if node[:sys_firewall][:enabled] != "enabled"
    log "Firewall not enabled. Not adding rule for #{port}."
  else
    if machine_tag
      # See cookbooks/rightscale/providers/server_collection.rb for 
      # the "rightscale_server_collection" resource.
      rightscale_server_collection collection_name do
        tags machine_tag
        mandatory_tags ip_tag
      end
    end

    ruby_block 'Adding firewall rule' do
      block do
        ip_list = []

        # Add specific ip address
        ip_list << ip_addr if ip_addr

        # Add tagged servers
        if machine_tag
          valid_ip_regex =
            '\b(([0-9]|[1-9][0-9]|1[0-9]{2}|2[0-4][0-9]|25[0-5])\.){3}' +
            '([0-9]|[1-9][0-9]|1[0-9]{2}|2[0-4][0-9]|25[0-5])\b'
          ip_list = node[:server_collection][collection_name].collect do |_, tags|
            # See cookbooks/rightscale/libraries/helper.rb for
            # the "get_tag_value" definition.
            RightScale::Utils::Helper.get_tag_value(ip_tag, tags, valid_ip_regex)
          end
        end

        ip_list.each do |ip|
          Chef::Log.info "  Updating iptables rule for IP Address: #{ip}"

          rule = "port_#{port}"
          rule << "_#{ip.gsub('/', '_')}_#{protocol}"

          # Programatically execute template resource
          # See cookbooks/sys/libraries/helper.rb for the 
          # "run_template" definition.
          template_updated = RightScale::System::Helper.run_template(
            "/etc/iptables.d/#{rule}", # destination_file
            "iptables_port.erb", # source
            "sys_firewall", # cookbook
            { # variables
              :port => (port == "any") ? nil : port,
              :protocol => protocol,
              :target => target,
              :ip_addr => (ip == "any") ? nil : ip
            },
            to_enable, # enable
            "/usr/sbin/rebuild-iptables", # command to run
            node,
            @run_context
          )
          # Reload sysctl if the template is updated. Reloading sysctl is
          # required here as rebuilding iptables resets certain sysctl values
          # that were changed from the default value.
          RightScale::System::Helper.reload_sysctl if template_updated
        end
      end
    end
  end
end

# Updates request to server to update its firewall rules
action :update_request do

  # Deal with attributes
  port = new_resource.port ? new_resource.port : new_resource.name
  protocol = new_resource.protocol
  to_enable = new_resource.enable
  ip_addr = new_resource.ip_addr
  raise "ERROR: client_ip must be specified." unless ip_addr
  machine_tag = new_resource.machine_tag
  raise "ERROR: machine_tag must be specified." unless machine_tag

  # Tell user what is going on
  msg = "Requesting port #{port} be #{to_enable ? "opened" : "closed"}"
  msg << " only for #{ip_addr}." if ip_addr
  msg << " on servers with tag: #{machine_tag}."
  msg << " using protocol #{protocol}." if protocol
  log msg

  # Setup attributes
  attrs = {:sys_firewall => {:rule => Hash.new}}
  attrs[:sys_firewall][:rule][:port] = port
  attrs[:sys_firewall][:rule][:protocol] = protocol
  attrs[:sys_firewall][:rule][:enable] = (to_enable == true) ? "enable" : "disable"
  attrs[:sys_firewall][:rule][:ip_address] = ip_addr

  # Use RightNet to update firewall rules on all tagged servers
  # See http://support.rightscale.com/12-Guides/Chef_Cookbooks_Developer_Guide/Chef_Resources#RemoteRecipe for the "remote_recipe" resource.
  remote_recipe "Request firewall update" do
    recipe "sys_firewall::setup_rule"
    recipients_tags machine_tag
    attributes attrs
  end
end