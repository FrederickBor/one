#!/usr/bin/ruby

require 'sequel'
require 'yaml'

# ------------------------------------------------------------------------------
# SQlite Interface for the status probes. It stores the last known state of
# each domain and the number of times the domain has been reported as missing
#
# IMPORTANT. This class needs to include/require a DomainList module with
# the state_info method.
# ------------------------------------------------------------------------------
class VirtualMachineDB

    # Default configuration attributes for the Database probe
    DEFAULT_CONFIGURATION = {
        :times_missing => 3,
        :obsolete      => 720,
        :db_path       => "#{__dir__}/../status.db",
        :period        => 0,
        :missing_state => "POWEROFF"
    }

    def self.unlink_db(hyperv, opts = {})
        conf = VirtualMachineDB.load_conf(hyperv, opts)

        File.unlink(conf[:db_path])
    end

    def initialize(hyperv, opts = {})
        @conf = VirtualMachineDB.load_conf(hyperv, opts)
        @db   = Sequel.connect("sqlite://#{@conf[:db_path]}")

        bootstrap

        @dataset = @db[:states]
    end

    # Deletes obsolete VM entries
    def purge
        limit = Time.now.to_i - (@conf[:obsolete] * 60) # conf in minutes

        @dataset.where { timestamp < limit }.delete
    end

    # Returns the VM status that changed compared to the DB info as well
    # as VMs that have been reported as missing more than missing_times
    def to_status
        status_str = ''

        time = Time.now.to_i
        last = @dataset.max(:timestamp)
        vms  = DomainList.state_info

        monitor_ids = []

        if last
            force_update = time > (last + 3 * @conf[:period].to_i)
        else
            force_update = false
        end

        # ----------------------------------------------------------------------
        # report state changes in vms
        # ----------------------------------------------------------------------
        vms.each do |_uuid, vm|
            vm_db = @dataset.first(:id => vm[:id])

            monitor_ids << vm[:id].to_i

            if vm_db.nil?
                @dataset.insert({
                    :id        => vm[:id].to_i,
                    :name      => vm[:name],
                    :timestamp => time,
                    :missing   => 0,
                    :state     => vm[:state],
                    :hyperv    => @conf[:hyperv]
                })

                status_str << vm_to_status(vm)
                next
            end

            @dataset.where(:id => vm[:id]).update(:state     => vm[:state],
                                                  :missing   => 0,
                                                  :timestamp => time)

            if vm_db[:state] != vm[:state] || force_update
                status_str << vm_to_status(vm)
            end
        end

        # ----------------------------------------------------------------------
        # check missing VMs
        # ----------------------------------------------------------------------
        (@dataset.map(:id) - monitor_ids).each do |id|
            vm_db = @dataset.first(:id => id)

            next if vm_db.nil?

            miss = vm_db[:missing]

            # TODO: report once or replace this with %times
            if miss == @conf[:times_missing] || force_update
                status_str << vm_to_status(vm_db, @conf[:missing_state])

                @dataset.where(:id => id).delete if force_update
            end

            @dataset.where(:id => id).update(:timestamp => time,
                                             :missing   => miss + 1)
        end

        status_str
    end

    #  TODO describe DB schema
    #
    #
    def bootstrap
        return if @db.table_exists?(:states)

        @db.create_table :states do
            Integer :id, primary_key: true
            String  :name
            Integer :timestamp
            Integer :missing
            String  :state
            String  :hyperv
        end
    end

    private

    def vm_to_status(vm, state = vm[:state])
        "VM = [ ID=\"#{vm[:id]}\", DEPLOY_ID=\"#{vm[:name]}\", " \
        "STATE=\"#{state}\" ]\n"
    end

    # Load configuration file and parse user provided options
    def self.load_conf(hyperv, opts)
        conf_path = "#{__dir__}/../../etc/im/#{hyperv}-probes.d/probe_db.conf"
        etc_conf  = YAML.load_file(conf_path) rescue nil

        conf = DEFAULT_CONFIGURATION.clone

        conf.merge! etc_conf if etc_conf

        conf.merge! opts

        conf[:hyperv] = hyperv

        conf
    end

end