module RightScale
  module Firewall
    # Helper Module for for sys_firewall cookbook
    module Helper
      require 'yaml'
      require 'net/http'
      require 'time'
      require 'uri'

      # Determine if a string has a single valid URI
      #
      # @param [String] path
      #   FQDN path to a remote file
      #
      # @return [TrueClass, FalseClass]
      #
      def self.valid_uri?(path)
        ::URI.extract(path).length == 1 ? true : false
      end

      # Do an HTTP Header check to determine if the local file mtime is more
      # recent than the remote file 'If-Modified-Since' HTTP header.
      #
      # @param [String] local_file_path
      #   path to local file
      # @param [String] remote_file_path
      #   path to remote file
      #
      # @return [TrueClass, FalseClass]
      #
      def self.modified_file?(local_file_path, remote_file_path)
        remote_uri = ::URI.parse(remote_file_path)
        res = nil

        if ::File.exists?(local_file_path)
          headers = {
            'If-Modified-Since' => ::File.mtime(local_file_path).httpdate
          }
          con = Net::HTTP.start(remote_uri.host)
          res = con.head(remote_uri.path, headers).code
        end

        res != '304' ? true : false
      end

      # Helper method that parses a local YAML file, massages the contents to
      # the proper format, and expand combined entries into single entries
      #
      # @param [String] rule_file_path
      #   local filesystem path to the YAML file
      #
      # @return [Array]
      #   return an Array of Hashes
      #
      def self.get_rules(rule_file_path)
        rules = []
        raw_entries = YAML.load(File.open(rule_file_path).read)
        raw_entries.each do |rule|
          ip = rule[:ip_address]
          rule[:ip_address] = (ip == '' || ip.downcase =~ /any|all/) ? nil : ip
          rule[:protocol] = rule[:protocol] == 'both' ? %w(tcp udp) : [rule[:protocol]]
          rule[:ports] = rule[:ports].to_s.split(/\s*,\s*/)
          if rule[:ports].include?('any')
            rule[:ports] = ['any']
          else
            rule[:ports].map! { |p| p.to_i if p.to_i > 0 && p.to_i <= 65_536 }
            rule[:ports].compact!
          end
          rule[:protocol].each do |proto|
            rule[:ports].each do |port|
              rules << {
                :ip_address => rule[:ip_address],
                :port => port,
                :protocol => proto,
                :enable => rule[:enable],
                :target => rule[:target],
              }
            end
          end
        end
        rules
      end
    end
  end
end
