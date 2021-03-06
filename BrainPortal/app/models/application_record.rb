
#
# CBRAIN Project
#
# Copyright (C) 2008-2018
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

class ApplicationRecord < ActiveRecord::Base #:nodoc:

  Revision_info=CbrainFileRevision[__FILE__] #:nodoc:

  self.abstract_class = true

  ###################################################################
  # ActiveRecord Added Behavior For MetaData
  ###################################################################

  include ActRecMetaData # module in lib/act_rec_meta_data.rb

  ###################################################################
  # ActiveRecord Added Behavior For Logging
  ###################################################################

  include ActRecLog # module in lib/act_rec_log.rb

  ############################################################################
  # Pretty Type methods
  ############################################################################

  include CBRAINExtensions::ActiveRecordExtensions::PrettyType

  ###################################################################
  # ActiveRecord Added Behavior For Single Table Inheritance
  ###################################################################

  include CBRAINExtensions::ActiveRecordExtensions::SingleTableInheritance

  ###################################################################
  # ActiveRecord Added Behavior For Single Table Inheritance
  ###################################################################

  include CBRAINExtensions::ActiveRecordExtensions::AbstractModelMethods

  ###################################################################
  # ActiveRecord Added Behavior For Serialization
  ###################################################################

  include CBRAINExtensions::ActiveRecordExtensions::Serialization

  ###################################################################
  # ActiveRecord Added Behavior For Core Models
  ###################################################################

  include CBRAINExtensions::ActiveRecordExtensions::CoreModels

  ###################################################################
  # ActiveRecord Added Behavior For Hiding Attributes
  ###################################################################

  include CBRAINExtensions::ActiveRecordExtensions::HiddenAttributes
  include CBRAINExtensions::ActiveRecordExtensions::ApiAttrVisible

  # This method is used when .for_api() is invoked on
  # a relation, to limit the number of records returned
  # if not limit was specified.
  def self.default_api_limit #:nodoc:
    1000
  end

end

