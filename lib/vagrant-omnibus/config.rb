#
# Copyright (c) 2013, Seth Chisamore
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.
#

require 'rubygems/dependency'
require 'rubygems/dependency_installer'
require 'vagrant'

module VagrantPlugins
  #
  module Omnibus
    # @author Seth Chisamore <schisamo@opscode.com>
    class Config < Vagrant.plugin('2', :config)
      # @return [String]
      #   The version of Chef to install.
      attr_accessor :chef_version

      def initialize
        @chef_version = UNSET_VALUE
        @logger = Log4r::Logger.new('vagrantplugins::omnibus::config')
      end

      def finalize!
        if @chef_version == UNSET_VALUE
          @chef_version = nil
        elsif @chef_version.to_s == 'latest'
          # resolve `latest` to a real version
          @chef_version = retrieve_latest_chef_version
        end
      end

      def validate(machine)
        errors = []

        unless valid_chef_version?(chef_version)
          msg = <<-EOH
'#{chef_version}' is not a valid version of Chef.

A list of valid versions can be found at: http://www.opscode.com/chef/install/
          EOH
          errors << msg
        end

        { 'Omnibus Plugin' => errors }
      end

      private

      # Query RubyGems.org's Ruby API and retrive the latest version of Chef.
      def retrieve_latest_chef_version
        available_gems =
          dependency_installer.find_gems_with_sources(chef_gem_dependency)
        spec, _source =
        if available_gems.respond_to?(:last)
          # DependencyInstaller sorts the results such that the last one is
          # always the one it considers best.
          spec_with_source = available_gems.last
          spec_with_source
        else
          # Rubygems 2.0 returns a Gem::Available set, which is a
          # collection of AvailableSet::Tuple structs
          available_gems.pick_best!
          best_gem = available_gems.set.first
          best_gem && [best_gem.spec, best_gem.source]
        end

        spec && spec.version.to_s
      end

      # Query RubyGems.org's Ruby API to see if the user-provided Chef version
      # is in fact a real Chef version!
      def valid_chef_version?(version)
        return true
        is_valid = false
        begin
          available = dependency_installer.find_gems_with_sources(
            chef_gem_dependency(version)
          )
          is_valid = true unless available.empty?
        rescue ArgumentError => e
          @logger.debug("#{version} is not a valid Chef version: #{e}")
        end
        is_valid
      end

      def dependency_installer
        @dependency_installer ||= Gem::DependencyInstaller.new
      end

      def chef_gem_dependency(version = nil)
        Gem::Dependency.new('chef', version)
      end
    end
  end
end
