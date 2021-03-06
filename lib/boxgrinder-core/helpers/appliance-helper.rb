#
# Copyright 2010 Red Hat, Inc.
#
# This is free software; you can redistribute it and/or modify it
# under the terms of the GNU Lesser General Public License as
# published by the Free Software Foundation; either version 3 of
# the License, or (at your option) any later version.
#
# This software is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the GNU
# Lesser General Public License for more details.
#
# You should have received a copy of the GNU Lesser General Public
# License along with this software; if not, write to the Free
# Software Foundation, Inc., 51 Franklin St, Fifth Floor, Boston, MA
# 02110-1301 USA, or see the FSF site: http://www.fsf.org.

require 'yaml'

module BoxGrinder
  class ApplianceHelper
    def initialize(options = {})
      @log = options[:log] || Logger.new(STDOUT)
    end

    def read_definitions(definition_file, content_type = nil)
      @log.debug "Reading definition from '#{definition_file}' file..."

      definition_file_extension = File.extname(definition_file)
      configs = []

      appliance_config =
              case definition_file_extension
                when '.appl', '.yml', '.yaml'
                  read_yaml(definition_file)
                when '.xml'
                  read_xml(definition_file)
                else
                  unless content_type.nil?
                    case content_type
                      when 'application/x-yaml', 'text/yaml'
                        read_yaml(definition_file)
                      when 'application/xml', 'text/xml', 'application/x-xml'
                        read_xml(definition_file)
                    end
                  else
                    raise 'Unsupported file format for appliance definition file'
                  end
              end

      configs << appliance_config

      appliance_config.appliances.reverse.each do |appliance_name|
        configs << read_definitions("#{File.dirname(definition_file)}/#{appliance_name}#{definition_file_extension}").first
      end unless appliance_config.appliances.nil? or !appliance_config.appliances.is_a?(Array)

      [ configs.flatten, appliance_config ]
    end

    def read_yaml(file)
      begin
        definition = YAML.load_file(file)
        raise if definition.nil?
      rescue
        raise "File '#{file}' could not be read."
      end

      return definition if definition.is_a?(ApplianceConfig)

      appliance_config = ApplianceConfig.new

      appliance_config.name         = definition['name'] unless definition['name'].nil?
      appliance_config.summary      = definition['summary'] unless definition['summary'].nil?

      definition['variables'].each { |key, value| appliance_config.variables[key] = value } unless definition['variables'].nil?

      appliance_config.appliances   = definition['appliances'] unless definition['appliances'].nil?
      appliance_config.repos        = definition['repos'] unless definition['repos'].nil?

      appliance_config.version      = definition['version'].to_s unless definition['version'].nil?
      appliance_config.release      = definition['release'].to_s unless definition['release'].nil?

      unless definition['packages'].nil?
        appliance_config.packages.includes     = definition['packages']['includes'] unless definition['packages']['includes'].nil?
        appliance_config.packages.excludes     = definition['packages']['excludes'] unless definition['packages']['excludes'].nil?
      end

      unless definition['os'].nil?
        appliance_config.os.name      = definition['os']['name'].to_s unless definition['os']['name'].nil?
        appliance_config.os.version   = definition['os']['version'].to_s unless definition['os']['version'].nil?
        appliance_config.os.password  = definition['os']['password'].to_s unless definition['os']['password'].nil?
      end

      unless definition['hardware'].nil?
        appliance_config.hardware.arch        = definition['hardware']['arch'] unless definition['hardware']['arch'].nil?
        appliance_config.hardware.cpus        = definition['hardware']['cpus'] unless definition['hardware']['cpus'].nil?
        appliance_config.hardware.memory      = definition['hardware']['memory'] unless definition['hardware']['memory'].nil?
        appliance_config.hardware.network     = definition['hardware']['network'] unless definition['hardware']['network'].nil?
        appliance_config.hardware.partitions  = definition['hardware']['partitions'] unless definition['hardware']['partitions'].nil?
      end

      definition['post'].each { |key, value| appliance_config.post[key] = value } unless definition['post'].nil?

      appliance_config
    end

    def read_xml(file)
      raise "Reading XML files is not supported right now. File '#{file}' could not be read"
    end
  end
end
