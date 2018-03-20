#-- encoding: UTF-8

#-- copyright
# OpenProject is a project management system.
# Copyright (C) 2012-2018 the OpenProject Foundation (OPF)
#
# This program is free software; you can redistribute it and/or
# modify it under the terms of the GNU General Public License version 3.
#
# OpenProject is a fork of ChiliProject, which is a fork of Redmine. The copyright follows:
# Copyright (C) 2006-2017 Jean-Philippe Lang
# Copyright (C) 2010-2013 the ChiliProject Team
#
# This program is free software; you can redistribute it and/or
# modify it under the terms of the GNU General Public License
# as published by the Free Software Foundation; either version 2
# of the License, or (at your option) any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with this program; if not, write to the Free Software
# Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston, MA  02110-1301, USA.
#
# See docs/COPYRIGHT.rdoc for more details.
#++

module Tables; end

class Tables::Base
  def self.create(migration)
    migration.say_with_time "Create #{table_name} table" do
      table(migration)
      indices(migration)
    end
  end

  def self.table_name
    raise NotImplementedError
  end

  def self.id_options
    { id: :integer }
  end

  def self.create_table(migration, &block)
    migration.create_table table_name, id_options.merge(bulk: true), &block
  end

  def self.create_indices(migration, &block)
    migration.change_table table_name, bulk: true, &block
  end

  def self.table(_migration)
    raise NotImplementedError
  end

  def self.indices(_migration)
    raise NotImplementedError
  end
end
