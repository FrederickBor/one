# -------------------------------------------------------------------------- #
# Copyright 2002-2020, OpenNebula Project, OpenNebula Systems                #
#                                                                            #
# Licensed under the Apache License, Version 2.0 (the "License"); you may    #
# not use this file except in compliance with the License. You may obtain    #
# a copy of the License at                                                   #
#                                                                            #
# http://www.apache.org/licenses/LICENSE-2.0                                 #
#                                                                            #
# Unless required by applicable law or agreed to in writing, software        #
# distributed under the License is distributed on an "AS IS" BASIS,          #
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.   #
# See the License for the specific language governing permissions and        #
# limitations under the License.                                             #
#--------------------------------------------------------------------------- #

ONE_LOCATION ||= ENV['ONE_LOCATION']

if !ONE_LOCATION
    RUBY_LIB_LOCATION ||= '/usr/lib/one/ruby'
    GEMS_LOCATION     ||= '/usr/share/one/gems'
    ETC_LOCATION      ||= '/etc/one/'
    VAR_LOCATION      ||= '/var/lib/one/'
else
    RUBY_LIB_LOCATION ||= ONE_LOCATION + '/lib/ruby'
    GEMS_LOCATION     ||= ONE_LOCATION + '/share/gems'
    ETC_LOCATION      ||= ONE_LOCATION + '/etc/'
    VAR_LOCATION      ||= ONE_LOCATION + '/var/'
end

if File.directory?(GEMS_LOCATION)
    Gem.use_paths(GEMS_LOCATION)
    $LOAD_PATH.reject! {|l| l =~ /(vendor|site)_ruby/ }
end

$LOAD_PATH << RUBY_LIB_LOCATION

require 'yaml'
require 'rexml/document'


require_relative './vcenter_cluster'
require_relative './monitord_client'

#---------------------------------------------------------------------------
#
#
#---------------------------------------------------------------------------
class VcenterMonitorManager
    #---------------------------------------------------------------------------
    # Constants
    #    BASE_TIMER: for monitor loop, periods CANNOT be less than this value
    #    DEFAULT_CONFIGURATION
    #---------------------------------------------------------------------------
    BASE_TIMER = 10

    DEFAULT_CONFIGURATION = {
        :system_host  => 600,
        :monitor_host => 120,
        :state_vm     => 30,
        :monitor_vm   => 30,
        :beacon_host  => 30,
        :address      => '127.0.0.1',
        :port         => 4124
    }.freeze

    # Minimum interval for vCenter probes
    # They run in the front-end and are RAM consuming
    # so this is the minimum grain for the intervals
    MINIMUM_INTERVAL = 30


    #---------------------------------------------------------------------------
    #
    #---------------------------------------------------------------------------
    def initialize
        @clusters = ClusterSet.new

        @clusters.bootstrap

        @mutex = Mutex.new
        @conf  = DEFAULT_CONFIGURATION.clone

        # Create timer thread to monitor vcenters
        Thread.new { timer }
    end

    #---------------------------------------------------------------------------
    #
    #---------------------------------------------------------------------------
    def update_conf(conf64)
        conftxt = Base64.decode64(conf64)
        conf    = REXML::Document.new(conftxt).root
        @mutex.synchronize do
            @conf = {
                :system_host  => conf.elements['PROBES_PERIOD/SYSTEM_HOST'].text.to_i,
                :monitor_host => conf.elements['PROBES_PERIOD/MONITOR_HOST'].text.to_i,
                :state_vms    => conf.elements['PROBES_PERIOD/STATE_VM'].text.to_i,
                :monitor_vm   => conf.elements['PROBES_PERIOD/MONITOR_VM'].text.to_i,
                :beacon_host  => conf.elements['PROBES_PERIOD/BEACON_HOST'].text.to_i,
                :address      => conf.elements['NETWORK/MONITOR_ADDRESS'].text.to_s,
                :port         => conf.elements['NETWORK/PORT'].text.to_s
            }

            @conf.each{ |k,v| @conf[k] = 30 if v.is_a?(Integer) && v < MINIMUM_INTERVAL }
        end

        @conf[:address] = '127.0.0.1' if @conf[:address] == 'auto'
    rescue StandardError
        @mutex.synchronize { @conf = DEFAULT_CONF.clone }
    end

    #---------------------------------------------------------------------------
    #  ACTION from OpenNebula Information Driver:
    #    - start: monitor process for a cluster
    #    - stop: monitor process for a cluster
    #---------------------------------------------------------------------------
    def start(hid, conf)
        update_conf(conf)

        @clusters.add(hid, @conf.clone)
    end

    def stop(hid, _)
        @clusters.del(hid)
    end

    #---------------------------------------------------------------------------
    #  Periodic timer to trigger monitor updates
    #---------------------------------------------------------------------------
    def timer
        loop do
            conf = @mutex.synchronize { @conf.clone }
            @clusters.monitor(conf)

            sleep BASE_TIMER
        end
    end

end

#---------------------------------------------------------------------------
# This class receives inputs reading on the fifo, sends monitor messages
# to monitord client and trigger operations on the Vcenter logic thread
# --------------------------------------------------------------------------
class IOThread
    IO_FIFO = '/tmp/vcenter_monitor.fifo'

    def initialize(vcentermm)
        @vcentermm = vcentermm
    end

    def command_loop
        loop do
            fifo = File.open(IO_FIFO)

            fifo.each_line do |line|
                action, hid, conf = line.split

                @vcentermm.send(action.to_sym, hid.to_i, conf)
            end
        end
    end

end

Thread.new do
    exit unless system('pgrep oned')
    sleep 5
end

vcentermm = VcenterMonitorManager.new

io = IOThread.new(vcentermm)

io.command_loop
