#
# Cookbook Name:: sys_firewall
#
# Copyright RightScale, Inc. All rights reserved.
# All access and use subject to the RightScale Terms of Service available at
# http://www.rightscale.com/terms.php and, if applicable, other agreements
# such as a RightScale Master Subscription Agreement.

rightscale_marker

if node[:sys_firewall][:enabled] == 'enabled'

  local_rule_file = '/etc/sys_firewall/firewall_rules.yaml'
  remote_rule_file = node[:sys_firewall][:rule_list][:file]

  if RightScale::Firewall::Helper.valid_uri?(remote_rule_file)
    if RightScale::Firewall::Helper.modified_file?(local_rule_file, remote_rule_file)

      directory '/etc/sys_firewall' do
        owner 'root'
        group 'root'
        mode 00644
        action :nothing
      end.run_action(:create)

      remote_file local_rule_file do
        source remote_rule_file
        backup false
        action :nothing
      end.run_action(:create)

      rules = RightScale::Firewall::Helper.get_rules(local_rule_file)
      rules.each do |rule|
        sys_firewall rule[:port] do
          port      rule[:port]
          ip_addr   rule[:ip_address]
          protocol  rule[:protocol]
          enable    rule[:enable]
          target    rule[:target]
          action    :update
        end
      end

      execute '/usr/sbin/rebuild-iptables'

    else
      log "  WARN: Rules file hasn't changed since the last run, skipping"
    end
  else
    log "  ERROR: #{remote_rule_file} is not a valid remote URI"
  end
else
  log '  WARN: Firewall is not enabled'
end
