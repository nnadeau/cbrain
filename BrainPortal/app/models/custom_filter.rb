#
# CBRAIN Project
#
# Custom filter model
#
# Original author: Tarek Sherif 
#
# $Id$
#

#This model represents a user defined filter. The class is not meant
#to be used directly, but instead to be subclassed for the particular
#resource to be filtered. The most critical aspect in the subclass 
#is it's redifinition of the method filter_scope.
#
#=*IMPORTANT*: Naming conventions
#[*Controller*] The name of the subclass should be the camelcased name of
#               of the filtered resource as it appears in its controller. E.g.
#               UserfileCustomFilter filters on the UserfilesController,
#               TaskCustomFilter filters on the TasksController. Alternatively,
#               the method filtered_class_controller can be redifined to return the
#               the name of the controller being filtered on.
#[<b>Partial for new and edit actions</b>] This should saved in app/view/custom_filter/ and
#                                          should match the underscored version of the class
#                                          name. E.g. _userfile_custom_filter.html.erb for
#                                          UserfileCustomFilter.
#[<b>Type parameter</b>] A type paramter will be sent to the new and create actions of the
#                        CustomFilterController. This parameter should match the part of 
#                        of the class name excluding "CustomFilter". E.g. for UserfileCustomFilter,
#                        the type parameter should be "userfile".
#
#=Attributes:
#[*name*] A string representing the name of the filter.
#[*data*] A hash containing the filter parameters.
#= Associations:
#*Belongs* *to*:
#* User
class CustomFilter < ActiveRecord::Base
      
  Revision_info=CbrainFileRevision[__FILE__]

  serialize_as_indifferent_hash :data
      
  belongs_to    :user
    
  validates_presence_of   :name
  validates_uniqueness_of :name, :scope  => [:user_id, :type]
  validates_format_of     :name,  :with => /^[\w\-\=\.\+\?\!\s]*$/, 
                                  :message  => 'only the following characters are valid: alphanumeric characters, spaces, _, -, =, +, ., ?, !'

  validate :check_filter_date
  
  def check_filter_date
    return true if self.data["date_attribute"].blank?
    
    if self.data["absolute_or_relative_from"] == "abs" && self.data["abs_from"].blank?
      errors.add(:base, "You should enter an absolute 'from' date or de-select radio button")
    end
	  
    if self.data["absolute_or_relative_to"] == "abs" && self.data["abs_to"].blank?
      errors.add(:base, "You should enter an absolute 'to' date or de-select radio button")
    end

    if self.data["absolute_or_relative_to"] == "rel" && self.data["absolute_or_relative_from"] == "rel" && self.data["rel_date_from"] == self.data["rel_date_to"]
      errors.add(:base, "You should choose 2 differents relatives dates")
    end
    
  end

  #Main method used for custom filtering. Should be redefined in subclasses to 
  #modify +scope+ according to the filter parameters and return it.
  def filter_scope(scope)
    raise "Using filter_scope in CustomFilter base class. Should be used from a subclass."
  end
  
  #Returns the name of the controller of the resource being filtered.
  def filtered_class_controller
    @filtered_class_controller ||= self.class.to_s.sub(/CustomFilter$/, "").tableize
  end
  
  #Wrapper for the data attribute. Ensures it's always initialized.
  def data
    unless read_attribute(:data)
       write_attribute(:data, {})
    end
    read_attribute(:data) 
  end
  
  #Virtual attribute for mass assigning to the data hash.
  def data=(new_data)
    write_attribute(:data, new_data)
  end

  #Return +scope+ modified to filter the CbrainTask entry's dates.
  def scope_date(scope)

    date_at = self.data["date_attribute"] # assignation ... 
    return scope if date_at !~ /^(updated_at|created_at)$/

    offset = Time.now.in_time_zone.utc_offset.seconds

    abs_from         = self.data["abs_from"]
    abs_to           = self.data["abs_to"]
    rel_from         = self.data["rel_date_from"]
    rel_to           = self.data["rel_date_to"]
    mode_is_abs_from = self.data['absolute_or_relative_from'] == "abs"
    mode_is_abs_to   = self.data['absolute_or_relative_to']   == "abs"

    if mode_is_abs_from
      user_start = DateTime.parse(abs_from)
    else
      user_start = Time.now - rel_from.to_i
    end

    if mode_is_abs_to
      user_end = DateTime.parse(abs_to)
    else
      user_end = Time.now - rel_to.to_i
    end

    need_switching = user_start > user_end
    user_start,user_end = user_end,user_start if need_switching
    user_end            = user_end + 1.day    if ( !need_switching && mode_is_abs_to ) || (need_switching && mode_is_abs_from)

    target_table = self.target_filtered_table
    scope = scope.scoped(:conditions  => ["#{target_table}.#{date_at} >= ?", user_start - offset])
    scope = scope.scoped(:conditions  => ["#{target_table}.#{date_at} <= ?", user_end   - offset])
    
    scope
    
  end
  
  private
  
  #Convert number codes for inequalities into 
  #the string representation:
  # 0: "="
  # 1: "<"
  # 2: ">"
  def inequality_type(number_code)
    case number_code.to_s
    when "1"
      "<"
    when "2"
      ">"
    when "<"   #Next two cases to maintain compatibility with 
      "<"      #the old format.
    when ">"
      ">"
    else
      "="
    end
  end
end
