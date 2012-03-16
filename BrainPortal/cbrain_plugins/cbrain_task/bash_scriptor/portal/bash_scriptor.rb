
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

# PortalTask model BashScriptor
class CbrainTask::BashScriptor < PortalTask

  Revision_info=CbrainFileRevision[__FILE__]

  # RDOC comments here, if you want, although the method
  # is created with #:nodoc: in this template.
  def self.default_launch_args #:nodoc:
    # Example: { :my_counter => 1, :output_file => "ABC.#{Time.now.to_i}" }
    { 
      :num_files_per_task => 1, # only used for internal serializing on portal side
      :time_estimate_per_file => 60  # in seconds
    }
  end

  def self.properties #:nodoc:
    { :no_presets => true, :use_parallelizer => true }
  end

  # RDOC comments here, if you want, although the method
  # is created with #:nodoc: in this template.
  def before_form
    params   = self.params
    ids      = params[:interface_userfile_ids]
    cb_error "This task can ONLY be launched by the administrator.\n" unless self.user.has_role? :admin_user
    ""
  end

  # RDOC comments here, if you want, although the method
  # is created with #:nodoc: in this template.
  def after_form #:nodoc:
    params = self.params
    #cb_error "Some error occurred."
    cb_error "This task can ONLY be launched by the administrator.\n" unless self.user.has_role? :admin_user
    if self.new_record? && (params[:num_files_per_task].blank? || params[:num_files_per_task].to_i < 1)
      params_errors.add(:num_files_per_task, "must be a number greater than 1.")
    end
    ""
  end

  def final_task_list #:nodoc:
    params     = self.params
    file_ids   = (params[:interface_userfile_ids] || []).dup
    ser_factor = (params[:num_files_per_task].presence || 1).to_i
    tot_files  = file_ids.size

    task_list = []

    offset_cnt = 0
    while file_ids.size > 0
      task   = self.clone
      subset = file_ids.slice!(0,ser_factor)
      task.params[:interface_userfile_ids] = subset
      desc = task.description.blank? ? "" : task.description.strip + "\n\n"
      subset[0,4].each do |id|
        file = Userfile.find(id) rescue nil
        next unless file
        desc += file.name + "\n"
      end
      desc += "\n(#{subset.size} files"
      desc +=   ", range: #{offset_cnt+1}..#{offset_cnt+subset.size} of #{tot_files}" if tot_files > 1
      desc += ")\n"
      task.description = desc
      task.params.delete :num_files_per_task # keep it clean, as no longer needed.
      task_list << task
      offset_cnt += ser_factor
    end

    task_list
  end

  def untouchable_params_attributes #:nodoc:
    { :output_userfile_ids => true }
  end

end

