
#
# CBRAIN Project
#
# Copyright (C) 2008-2012
# The Royal Institution for the Advancement of Learning
# McGill University
#
# This program is free software: you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation, either version 3 of the License, or
# (at your option) any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with this program.  If not, see <http://www.gnu.org/licenses/>.  
#

# A task starting a VM from a disk image.
require 'net/ssh'

class CbrainTask::StartVM < ClusterTask

  Revision_info = CbrainFileRevision[__FILE__]

  include RestartableTask
  include RecoverableTask

  #to follow the boot process of the VM 
  after_status_transition '*', 'On CPU', :starting

  def setup #:nodoc:
    validate_params # defined in common, will raise an exception if params aren't valid.
    true
  end
  
  def cluster_commands #:nodoc:
    [ "echo This will never execute" ] # if the cluster commands are
    # empty, task will jump directly
    # to state data ready.
  end
  
  def save_results #:nodoc:
    addlog("No result to save.")
    # we consider the task successful if the VM booted. 
    return true if params[:vm_status] == "booted"
    addlog "VM is not active and never booted. I don't know why, sorry."
    return false
  end

  # Taken from Civet task.
  def mybool(value) #:nodoc:
    return false if value.blank?
    return false if value.is_a?(String)  and value == "0"
    return false if value.is_a?(Numeric) and value == 0
    return true
  end

  # Hook called when the VM task gets on CPU. 
  # Monitors the VM until it boots. Then mounts shared directories with sshfs. 
  def starting(init_status) #:nodoc:
    params = self.params

    #update VM params
    params[:vm_local_ip] = scir_session.get_local_ip(id)
    if params[:vm_local_ip].blank? 
      addlog "Cannot get VM local IP. Terminate VM task (id = #{id})."
      update_vm_status("unreachable")
      save!
      terminate
    end
    update_vm_status("booting")
    save! #will launch an exception if save fails   

    #monitor VM until it's booted
    CBRAIN.spawn_with_active_records("Monitor VM")  do
      begin
        start_time = Time.now
        #Monitor booting process
        monitor_to_boot(start_time)
        mount_directories
        addlog("VM has booted")
        update_vm_status("booted")
        save!
      rescue => ex
        addlog "#{ex.class} #{ex.message}"
      end	
    end
  end

  def update_vm_status(new_status) #:nodoc:
    params[:vm_status] = new_status
    params[:vm_status_time] = Time.now
  end

  # Mounts cache and task directories.
  def mount_directories 
    addlog("Mounting shared directories")
    mount_cache_dir
    mount_task_dir
  end

  # Monitors the VM until booted. 
  def monitor_to_boot(start_time) #:nodoc:
    while !booted? do
      elapsed = Time.now - start_time
      if elapsed > params[:vm_boot_timeout].to_f
      then
        addlog("Boot timeout reached. Terminating VM task (id = #{id}).")
        update_vm_status("unreachable")
        save!
        terminate
        return 
      end
      sleep 5
    end
  end

  # Checks if the VM has booted. 
  def booted? 
    addlog("Trying to ssh #{params[:vm_user]}@#{params[:vm_local_ip]}")
    master = get_ssh_master_for_vm
    return true
  rescue => ex
    addlog "Error: #{ex.message}"
    return false
  end

  # Mounts the cache directory in the VM.
  def mount_cache_dir
    full_cache_dir = RemoteResource.current_resource.dp_cache_dir
    if full_cache_dir.blank? 
      addlog("No cache directory configured")
      return
    end
    local_cache_dir = File.basename(full_cache_dir)
    mount_dir(full_cache_dir,local_cache_dir)
    return true
  rescue => ex
    addlog("Cannot mount cache directory (#{ex.message}). Terminating VM task.")
    terminate
    return false
  end

  # Mounts the task directory in the VM. 
  def mount_task_dir
    bourreau_shared_dir = bourreau.cms_shared_dir
    mount_dir bourreau_shared_dir,File.basename(bourreau_shared_dir)
    return true
  rescue => ex
    addlog "Cannot mount task directory (#{ex.message}). Killing VM task."
    terminate
    return false
  end

  # Mounts a directory in the VM.
  # local_dir is the VM directory.
  # remote_dir is the directory on the Bourreau machine.
  def mount_dir(remote_dir,local_dir)
    return unless !is_mounted? remote_dir,local_dir
    user = ENV['USER'] #quite unix-specific...
    
    sshfs_command = "mkdir #{local_dir} -p ; umount #{local_dir} ; sshfs -p #{params[:vm_ssh_tunnel_port]} -C -o nonempty -o follow_symlinks -o reconnect -o ServerAliveInterval=15 -o StrictHostKeyChecking=no #{user}@localhost:#{remote_dir} #{local_dir}"
    addlog "Mounting dir: #{sshfs_command}"
    addlog run_command_in_vm(sshfs_command) 
    # leave time to fuse to mount the dir
    sleep 5
    raise "Couldn't mount local directory #{local_dir} as #{remote_dir} in VM" unless is_mounted?(remote_dir,local_dir)
  end

  # Checks if a directory is mounted in the VM.
  def is_mounted?(remote_dir,local_dir)
    @last_checks = Hash.new unless !@last_checks.blank?
    t = Time.now
    file_name = ".testmount.#{Process.pid}"
    if File.exist?(file_name)
      last_checked = File.mtime(file_name)
      if (t - last_checked < 5) && !@last_checks[combine(remote_dir,local_dir)].blank?
        addlog "NOT checking if local directory #{remote_dir} is mounted in #{local_dir} in VM (did it #{t-last_checked}s ago."
        return @last_checks[combine(remote_dir,local_dir)]
      end
    end
    
    addlog "Checking if local directory #{remote_dir} is mounted in #{local_dir} in VM"
    begin
      file = File.open(remote_dir+"/"+file_name, "w")
      file.write(t.to_s) 
    rescue IOError => e
      raise e
    ensure
      file.close unless file == nil
    end                  
    time_read = run_command_in_vm("cat #{local_dir}/#{file_name}")
    result = ( t.to_s == time_read.to_s ) ? true : false
    @last_checks[combine(remote_dir,local_dir)] = result
    return result
  ensure
    File.delete(remote_dir+"/"+file_name)
  end

  # Returns a key unique to a combination of directories.
  # Uses ; because this char is not supposed to be included in a directory name. 
  def combine(a,b) #:nodoc:
    return "#{a};;;#{b}"
  end

  def get_ssh_master_for_vm
    user   = params[:vm_user]
    ip     = params[:vm_local_ip]
    port   = params[:ssh_port]
    master = SshMaster.find_or_create(user,ip,port)

    # Tunnel used to sshfs from the VM to the host.
    master.add_tunnel(:reverse,params[:vm_ssh_tunnel_port].to_i,'localhost',22) unless ( master.get_tunnels(:reverse).size !=0) 
    CBRAIN.with_unlocked_agent 
    master.start
    raise "Cannot establish connection with VM id #{id} (#{master.ssh_shared_options})" unless master.is_alive?
    return master
  end

  def run_command_in_vm(command)
    master = self.get_ssh_master_for_vm
    result = master.remote_shell_command_reader(command) {|io| io.read}
    return result 
  end


end      
