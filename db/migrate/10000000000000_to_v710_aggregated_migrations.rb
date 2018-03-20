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

Dir["#{Rails.root}/db/migrate/tables/*.rb"].each { |file| require file }
Dir["#{Rails.root}/db/migrate/aggregated/*.rb"].each { |file| require file }

# This migration aggregates a set of former migrations
class ToV710AggregatedMigrations < ActiveRecord::Migration[5.1]
  class IncompleteMigrationsError < ::StandardError
  end

  @tables = [
    Tables::WorkPackages,
    Tables::Users,
    Tables::Categories,
    Tables::Relations,
    Tables::Statuses,
    Tables::Projects,
    Tables::TimeEntries,
    Tables::Sessions,
    Tables::Announcements,
    Tables::Attachments,
    Tables::AuthSources,
    Tables::Boards,
    Tables::Messages,
    Tables::CustomFields,
    Tables::Changes
  ]

  def self.tables
    @tables
  end

  def up
    raise_on_incomplete_3_0_migrations
    raise_on_incomplete_7_1_migrations

    intersection = aggregated_versions_7_1 & all_versions

    if intersection == aggregated_versions_7_1
      remove_applied_migration_entries
    else
      run_aggregated_migrations
    end
  end

  def down
    raise ActiveRecord::IrreversibleMigration, 'Use OpenProject v7.4 for the down migrations'
  end

  private

  # No migrations that this migration aggregates have already been
  # applied. In this case, run the aggregated migration.
  def run_aggregated_migrations
    create_tables

    create_changesets_table
    create_changesets_work_packages_table

    create_comments_table

    create_custom_fields_projects_table
    create_custom_fields_types_table
    create_custom_options_table
    create_custom_values_table

    create_enabled_modules_table
    create_enumerations_table

    create_group_users_table

    create_journals_table
    create_work_package_journals_table
    create_message_journals_table
    create_news_journals_table
    create_wiki_content_journals_table
    create_time_entry_journals_table
    create_changeset_journals_table
    create_attachment_journals_table
    create_attachable_journals_table
    create_customizable_journals_table

    create_roles_table
    create_role_permissions_table
    create_member_roles_table
    create_members_table

    create_news_table

    create_project_types_table
    create_planning_element_type_colors_table
    create_reportings_table
    create_available_project_statuses_table
    create_project_associations_table
    create_timelines_table

    create_projects_types_table

    create_queries_table

    create_repositories_table

    create_settings_table

    create_tokens_table

    create_types_table

    create_user_preference_table
    create_user_passwords_table

    create_versions_table

    create_watchers_table
    create_wiki_content_versions
    create_wiki_contents_table

    create_wiki_pages_table
    create_wiki_redirects_table
    create_wikis_table

    create_workflows_table

    create_delayed_jobs_table

    create_wiki_menu_items

    create_custom_styles_table
    create_design_colors_table
    create_enterprise_tokens_table
  end

  # All migrations that this migration aggregates have already
  # been applied. In this case, remove the information about those
  # migrations from the schema_migrations table and we're done.
  def remove_applied_migration_entries
    execute <<-SQL + (intersection.map { |version| <<-CONDITIONS }).join(' OR ')
        DELETE FROM
          #{quoted_schema_migrations_table_name}
        WHERE
    SQL
      #{version_column_for_comparison} = #{quote_value(version.to_s)}
    CONDITIONS
  end

  def raise_on_incomplete_3_0_migrations
    raise_on_incomplete_migrations(aggregated_versions_3_0, 'v2.4.0', 'ChiliProject')
  end

  def raise_on_incomplete_7_1_migrations
    raise_on_incomplete_migrations(aggregated_versions_7_1, 'v7.4.0', 'OpenProject')
  end

  def raise_on_incomplete_migrations(aggregated_versions, version_number, app_name)
    intersection = aggregated_versions & all_versions

    if !intersection.empty? && intersection != aggregated_versions

      missing = aggregated_versions - intersection

      # Only a part of the migrations that this migration aggregates
      # have already been applied. In this case, fail miserably.
      raise IncompleteMigrationsError, <<-MESSAGE.split("\n").map(&:strip!).join(' ') + "\n"
        It appears you are migrating from an incompatible version of
        #{app_name}. Yourdatabase has only some migrations from #{app_name} <
        #{version_number} Please update your database to the schema of #{app_name}
        #{version_number} and run the OpenProject migrations again. The following
        migrations are missing: #{missing}
      MESSAGE
    end
  end

  def create_tables
    self.class.tables.each do |table|
      table.create(self)
    end
  end

  def create_project_types_table
    create_table(:project_types) do |t|
      t.column :name, :string, default: '', null: false
      t.column :allows_association, :boolean, default: true, null: false
      t.column :position, :integer, default: 1, null: true

      t.timestamps
    end
  end

  def create_types_table
    create_table :types, id: :integer, force: true do |t|
      t.string :name, default: '', null: false
      t.integer :position, default: 1
      t.boolean :is_in_roadmap, default: true, null: false
      t.boolean :in_aggregation, default: true, null: false
      t.boolean :is_milestone, default: false, null: false
      t.boolean :is_default, default: false, null: false
      t.boolean :is_standard, default: false, null: false
      t.belongs_to :color, index: { name: :index_types_on_color_id }
      t.datetime :created_at, null: false
      t.datetime :updated_at, null: false
      t.text :attribute_visibility, hash: true
      t.text :attribute_groups
    end
  end

  def create_planning_element_type_colors_table
    create_table(:planning_element_type_colors) do |t|
      t.column :name, :string, null: false
      t.column :hexcode, :string, null: false, length: 7

      t.integer :position, default: 1, null: true

      t.timestamps
    end
  end

  def create_reportings_table
    create_table(:reportings) do |t|
      t.column :reported_project_status_comment, :text

      t.belongs_to :project
      t.belongs_to :reporting_to_project
      t.belongs_to :reported_project_status

      t.timestamps
    end
  end

  def create_available_project_statuses_table
    create_table(:available_project_statuses) do |t|
      t.belongs_to :project_type
      t.belongs_to :reported_project_status, index: { name: 'index_avail_project_statuses_on_rep_project_status_id' }

      t.timestamps
    end
  end

  def create_project_associations_table
    create_table(:project_associations) do |t|
      t.belongs_to :project_a
      t.belongs_to :project_b

      t.column :description, :text

      t.timestamps
    end
  end

  def create_timelines_table
    create_table :timelines, id: :integer do |t|
      t.string :name, null: false
      t.text :options

      t.belongs_to :project

      t.timestamps
    end
  end

  def create_versions_table
    create_table :versions, id: :integer, force: true do |t|
      t.integer 'project_id', default: 0, null: false
      t.string 'name', default: '', null: false
      t.string 'description', default: ''
      t.date 'effective_date'
      t.datetime 'created_on'
      t.datetime 'updated_on'
      t.string 'wiki_page_title'
      t.string 'status', default: 'open'
      t.string 'sharing', default: 'none', null: false
      t.date 'start_date'
    end

    add_index :versions, ['project_id'], name: 'versions_project_id'
    add_index :versions, ['sharing'], name: 'index_versions_on_sharing'
  end

  def create_watchers_table
    create_table :watchers, id: :integer, force: true do |t|
      t.string 'watchable_type', default: '', null: false
      t.integer 'watchable_id', default: 0, null: false
      t.integer 'user_id'
    end

    add_index :watchers, %i(user_id watchable_type), name: 'watchers_user_id_type'
    add_index :watchers, :user_id, name: 'index_watchers_on_user_id'
    add_index :watchers, %i(watchable_id watchable_type), name: 'index_watchers_on_watchable_id_and_watchable_type'
  end

  def create_wiki_content_versions
    create_table :wiki_content_versions, id: :integer, force: true do |t|
      t.integer 'wiki_content_id', null: false
      t.integer 'page_id', null: false
      t.integer 'author_id'
      t.binary 'data', limit: 16.megabytes
      t.string 'compression', limit: 6, default: ''
      t.string 'comments', default: ''
      t.datetime 'updated_on', null: false
      t.integer 'version', null: false
    end

    add_index :wiki_content_versions, ['updated_on'], name: 'index_wiki_content_versions_on_updated_on'
    add_index :wiki_content_versions, ['wiki_content_id'], name: 'wiki_content_versions_wcid'
  end

  def create_wiki_contents_table
    create_table :wiki_contents, id: :integer, force: true do |t|
      t.integer 'page_id', null: false
      t.integer 'author_id'
      t.text 'text', limit: 16.megabytes
      t.datetime 'updated_on', null: false
      t.integer 'lock_version', null: false
    end

    add_index :wiki_contents, :author_id, name: 'index_wiki_contents_on_author_id'
    add_index :wiki_contents, :page_id, name: 'wiki_contents_page_id'
    add_index :wiki_contents, %i[page_id updated_on]
  end

  def create_wiki_pages_table
    create_table :wiki_pages, id: :integer, force: true do |t|
      t.integer 'wiki_id', null: false
      t.string 'title', null: false
      t.datetime 'created_on', null: false
      t.boolean 'protected', default: false, null: false
      t.integer 'parent_id'
      t.string :slug, null: false
    end

    add_index :wiki_pages, :parent_id, name: 'index_wiki_pages_on_parent_id'
    add_index :wiki_pages, %i[wiki_id title], name: 'wiki_pages_wiki_id_title'
    add_index :wiki_pages, :wiki_id, name: 'index_wiki_pages_on_wiki_id'

    add_index :wiki_pages, %i[wiki_id slug], name: 'wiki_pages_wiki_id_slug', unique: true
  end

  def create_wiki_redirects_table
    create_table :wiki_redirects, id: :integer, force: true do |t|
      t.integer 'wiki_id', null: false
      t.string 'title'
      t.string 'redirects_to'
      t.datetime 'created_on', null: false
    end

    add_index :wiki_redirects, %i[wiki_id title], name: 'wiki_redirects_wiki_id_title'
    add_index :wiki_redirects, :wiki_id, name: 'index_wiki_redirects_on_wiki_id'
  end

  def create_wikis_table
    create_table :wikis, id: :integer, force: true do |t|
      t.integer 'project_id', null: false
      t.string 'start_page', null: false
      t.integer 'status', default: 1, null: false
    end

    add_index :wikis, ['project_id'], name: 'wikis_project_id'
  end

  def create_workflows_table
    create_table :workflows, id: :integer, force: true do |t|
      t.integer 'type_id', default: 0, null: false
      t.integer 'old_status_id', default: 0, null: false
      t.integer 'new_status_id', default: 0, null: false
      t.integer 'role_id', default: 0, null: false
      t.boolean 'assignee', default: false, null: false
      t.boolean 'author', default: false, null: false
    end

    add_index :workflows, :new_status_id, name: 'index_workflows_on_new_status_id'
    add_index :workflows, :old_status_id, name: 'index_workflows_on_old_status_id'
    add_index :workflows, %i[role_id type_id old_status_id], name: 'wkfs_role_tracker_old_status'
    add_index :workflows, :role_id, name: 'index_workflows_on_role_id'
  end

  def create_tokens_table
    create_table :tokens, id: :integer, force: true do |t|
      t.integer 'user_id', default: 0, null: false
      t.string 'action', limit: 30, default: '', null: false
      t.string 'value', limit: 40, default: '', null: false
      t.datetime 'created_on', null: false
    end

    add_index :tokens, :user_id, name: 'index_tokens_on_user_id'
  end

  def create_queries_table
    create_table :queries, id: :integer, force: true do |t|
      t.integer 'project_id'
      t.string 'name', default: '', null: false
      t.text 'filters'
      t.integer 'user_id', default: 0, null: false
      t.boolean 'is_public', default: false, null: false
      t.text 'column_names'
      t.text 'sort_criteria'
      t.string 'group_by'
      t.boolean :display_sums, default: false, null: false
      t.boolean :timeline_visible, default: false
      t.boolean :show_hierarchies, default: false
      t.integer :timeline_zoom_level, default: 0
    end

    add_index :queries, :project_id, name: 'index_queries_on_project_id'
    add_index :queries, :user_id, name: 'index_queries_on_user_id'
  end

  def create_repositories_table
    create_table :repositories, id: :integer, force: true do |t|
      t.integer 'project_id', default: 0, null: false
      t.string 'url', default: '', null: false
      t.string 'login', limit: 60, default: ''
      t.string 'password', default: ''
      t.string 'root_url', default: ''
      t.string 'type'
      t.string 'path_encoding', limit: 64
      t.string 'log_encoding', limit: 64
      t.string :scm_type, null: false
      t.integer :required_storage_bytes, :integer, limit: 8, null: false, default: 0
      t.datetime :storage_updated_at, :datetime
    end

    add_index :repositories, :project_id, name: 'index_repositories_on_project_id'
  end

  def create_settings_table
    create_table :settings, id: :integer, force: true do |t|
      t.string 'name', default: '', null: false
      t.text 'value'
      t.datetime 'updated_on'
    end

    add_index :settings, :name, name: 'index_settings_on_name'
  end

  def create_user_passwords_table
    create_table :user_passwords, id: :integer do |t|
      t.integer :user_id, null: false
      t.string :hashed_password, limit: 128, null: false
      t.string :salt, limit: 64, null: true
      t.string :type, null: false
      t.timestamps
    end

    add_index :user_passwords, :user_id
  end

  def create_group_users_table
    create_table :group_users, id: false, force: true do |t|
      t.integer :group_id, null: false
      t.integer :user_id, null: false
    end

    add_index :group_users, %i(group_id user_id), name: :group_user_ids, unique: true
  end

  def create_enabled_modules_table
    create_table :enabled_modules, id: :integer, force: true do |t|
      t.integer 'project_id'
      t.string 'name', null: false
    end

    add_index :enabled_modules, :project_id, name: 'enabled_modules_project_id'
    add_index :enabled_modules, :name, length: 8
  end

  def create_enumerations_table
    create_table :enumerations, id: :integer, force: true do |t|
      t.string 'name', limit: 30, default: '', null: false
      t.integer 'position', default: 1
      t.boolean 'is_default', default: false, null: false
      t.string 'type'
      t.boolean 'active', default: true, null: false
      t.integer 'project_id'
      t.integer 'parent_id'
    end

    add_index :enumerations, %i[id type], name: 'index_enumerations_on_id_and_type'
    add_index :enumerations, :project_id, name: 'index_enumerations_on_project_id'
  end

  def create_user_preference_table
    create_table :user_preferences, id: :integer, force: true do |t|
      t.integer 'user_id', default: 0, null: false
      t.text 'others'
      t.boolean :hide_mail, default: true
      t.string 'time_zone'
      t.boolean :impaired, default: false
    end

    add_index :user_preferences, :user_id, name: 'index_user_preferences_on_user_id'
  end

  def create_delayed_jobs_table
    create_table :delayed_jobs, id: :integer, force: true do |t|
      t.integer :priority, default: 0   # Allows some jobs to jump to the front of the queue
      t.integer :attempts, default: 0   # Provides for retries, but still fail eventually.
      t.text :handler                   # YAML-encoded string of the object that will do work
      t.text :last_error                # reason for last failure (See Note below)
      t.datetime :run_at                # When to run. Could be Time.zone.now for immediately, or sometime in the future.
      t.datetime :locked_at             # Set when a client is working on this object
      t.datetime :failed_at             # Set when all retries have failed (actually, by default, the record is deleted instead)
      t.string :locked_by               # Who is working on this object (if locked)
      t.string :queue
      t.timestamps
    end

    add_index :delayed_jobs, %i[priority run_at], name: 'delayed_jobs_priority'
  end

  def create_wiki_menu_items
    create_table :menu_items, id: :integer do |t|
      t.column :name, :string
      t.column :title, :string
      t.column :parent_id, :integer
      t.column :options, :text
      t.string :type

      t.belongs_to :navigatable
    end

    add_index :menu_items, %i(navigatable_id title)
    add_index :menu_items, :parent_id
  end

  def create_journals_table
    create_table :journals, id: :integer do |t|
      t.references :journable, polymorphic: true
      t.integer :user_id, default: 0, null: false
      t.text :notes
      t.datetime :created_at, null: false
      t.integer :version, default: 0, null: false
      t.string :activity_type
    end

    add_index :journals, :journable_id
    add_index :journals, :created_at
    add_index :journals, :journable_type
    add_index :journals, :user_id
    add_index :journals, :activity_type
    add_index :journals, %i[journable_type journable_id version], unique: true
  end

  def create_work_package_journals_table
    create_table :work_package_journals, id: :integer do |t|
      t.integer :journal_id, null: false
      t.integer :type_id, default: 0, null: false
      t.integer :project_id, default: 0, null: false
      t.string :subject, default: '', null: false
      t.text :description
      t.date :due_date
      t.integer :category_id
      t.integer :status_id, default: 0, null: false
      t.integer :assigned_to_id
      t.integer :priority_id, default: 0, null: false
      t.integer :fixed_version_id
      t.integer :author_id, default: 0, null: false
      t.integer :done_ratio, default: 0, null: false
      t.float :estimated_hours
      t.date :start_date
      t.integer :parent_id
      t.integer :responsible_id
    end

    add_index :work_package_journals, [:journal_id]
  end

  def create_message_journals_table
    create_table :message_journals, id: :integer do |t|
      t.integer :journal_id, null: false
      t.integer :board_id, null: false
      t.integer :parent_id
      t.string :subject, default: '', null: false
      t.text :content
      t.integer :author_id
      t.integer :replies_count, default: 0, null: false
      t.integer :last_reply_id
      t.boolean :locked, default: false
      t.integer :sticky, default: 0
    end

    add_index :message_journals, [:journal_id]
  end

  def create_news_journals_table
    create_table :news_journals, id: :integer do |t|
      t.integer :journal_id, null: false
      t.integer :project_id
      t.string :title, limit: 60, default: '', null: false
      t.string :summary, default: ''
      t.text :description
      t.integer :author_id, default: 0, null: false
      t.integer :comments_count, default: 0, null: false
    end

    add_index :news_journals, [:journal_id]
  end

  def create_wiki_content_journals_table
    create_table :wiki_content_journals, id: :integer do |t|
      t.integer :journal_id, null: false
      t.integer :page_id, null: false
      t.integer :author_id
      t.text :text, limit: (1.gigabyte - 1)
    end

    add_index :wiki_content_journals, [:journal_id]
  end

  def create_time_entry_journals_table
    create_table :time_entry_journals, id: :integer do |t|
      t.integer :journal_id, null: false
      t.integer :project_id, null: false
      t.integer :user_id, null: false
      t.integer :work_package_id
      t.float :hours, null: false
      t.string :comments
      t.integer :activity_id, null: false
      t.date :spent_on, null: false
      t.integer :tyear, null: false
      t.integer :tmonth, null: false
      t.integer :tweek, null: false
    end

    add_index :time_entry_journals, [:journal_id]
  end

  def create_changeset_journals_table
    create_table :changeset_journals, id: :integer do |t|
      t.integer :journal_id, null: false
      t.integer :repository_id, null: false
      t.string :revision, null: false
      t.string :committer
      t.datetime :committed_on, null: false
      t.text :comments
      t.date :commit_date
      t.string :scmid
      t.integer :user_id
    end

    add_index :changeset_journals, [:journal_id]
  end

  def create_attachment_journals_table
    create_table :attachment_journals, id: :integer do |t|
      t.integer :journal_id, null: false
      t.integer :container_id, default: 0, null: false
      t.string :container_type, limit: 30, default: '', null: false
      t.string :filename, default: '', null: false
      t.string :disk_filename, default: '', null: false
      t.integer :filesize, default: 0, null: false
      t.string :content_type, default: ''
      t.string :digest, limit: 40, default: '', null: false
      t.integer :downloads, default: 0, null: false
      t.integer :author_id, default: 0, null: false
      t.text :description
    end

    add_index :attachment_journals, [:journal_id]
  end

  def create_attachable_journals_table
    create_table :attachable_journals, id: :integer do |t|
      t.integer :journal_id, null: false
      t.integer :attachment_id, null: false
      t.string :filename, default: '', null: false
    end

    add_index :attachable_journals, :journal_id
    add_index :attachable_journals, :attachment_id
  end

  def create_customizable_journals_table
    create_table :customizable_journals, id: :integer do |t|
      t.integer :journal_id, null: false
      t.integer :custom_field_id, null: false
      t.text :value
    end

    add_index :customizable_journals, :journal_id
    add_index :customizable_journals, :custom_field_id
  end

  def create_roles_table
    create_table :roles, id: :integer, force: true do |t|
      t.string 'name', limit: 30, default: '', null: false
      t.integer 'position', default: 1
      t.boolean 'assignable', default: true
      t.integer 'builtin', default: 0, null: false
    end
  end

  def create_role_permissions_table
    create_table :role_permissions, id: :integer do |p|
      p.string :permission
      p.integer :role_id

      p.index :role_id

      p.timestamps
    end
  end

  def create_member_roles_table
    create_table :member_roles, id: :integer, force: true do |t|
      t.integer 'member_id', null: false
      t.integer 'role_id', null: false
      t.integer 'inherited_from'
    end

    add_index :member_roles, :member_id, name: 'index_member_roles_on_member_id'
    add_index :member_roles, :role_id, name: 'index_member_roles_on_role_id'

    add_index :member_roles, :inherited_from
  end

  def create_members_table
    create_table :members, id: :integer, force: true do |t|
      t.integer 'user_id', default: 0, null: false
      t.integer 'project_id', default: 0, null: false
      t.datetime 'created_on'
      t.boolean 'mail_notification', default: false, null: false
    end

    add_index :members, :project_id, name: 'index_members_on_project_id'
    add_index :members, %i[user_id project_id], name: 'index_members_on_user_id_and_project_id', unique: true
    add_index :members, :user_id, name: 'index_members_on_user_id'
  end

  def create_changesets_table
    create_table :changesets, id: :integer, force: true do |t|
      t.integer 'repository_id', null: false
      t.string 'revision', null: false
      t.string 'committer'
      t.datetime 'committed_on', null: false
      t.text 'comments'
      t.date 'commit_date'
      t.string 'scmid'
      t.integer 'user_id'
    end

    add_index :changesets, :committed_on, name: 'index_changesets_on_committed_on'
    add_index :changesets, %i[repository_id revision], name: 'changesets_repos_rev', unique: true
    add_index :changesets, %i[repository_id scmid], name: 'changesets_repos_scmid'
    add_index :changesets, :repository_id, name: 'index_changesets_on_repository_id'
    add_index :changesets, :user_id, name: 'index_changesets_on_user_id'

    add_index :changesets, %i[repository_id committed_on]
  end

  def create_changesets_work_packages_table
    create_table :changesets_work_packages, id: false, force: true do |t|
      t.integer :changeset_id, null: false
      t.integer :work_package_id, null: false
    end

    add_index :changesets_work_packages,
              %i[changeset_id work_package_id],
              unique: true,
              name: :changesets_work_packages_ids
  end

  def create_comments_table
    create_table :comments, id: :integer, force: true do |t|
      t.string 'commented_type', limit: 30, default: '', null: false
      t.integer 'commented_id', default: 0, null: false
      t.integer 'author_id', default: 0, null: false
      t.text 'comments'
      t.datetime 'created_on', null: false
      t.datetime 'updated_on', null: false
    end

    add_index :comments, :author_id, name: 'index_comments_on_author_id'
    add_index :comments, %i[commented_id commented_type], name: 'index_comments_on_commented_id_and_commented_type'
  end

  def create_custom_fields_projects_table
    create_table :custom_fields_projects, id: false, force: true do |t|
      t.integer 'custom_field_id', default: 0, null: false
      t.integer 'project_id', default: 0, null: false
    end

    add_index :custom_fields_projects,
              %i[custom_field_id project_id],
              name: 'index_custom_fields_projects_on_custom_field_id_and_project_id'
  end

  def create_projects_types_table
    create_table :projects_types, id: false, force: true do |t|
      t.integer :project_id, default: 0, null: false
      t.integer :type_id, default: 0, null: false
    end

    add_index :projects_types,
              :project_id,
              name: :projects_types_project_id
    add_index :projects_types,
              %i[project_id type_id],
              name: :projects_types_unique, unique: true
  end

  def create_custom_fields_types_table
    create_table :custom_fields_types, id: false, force: true do |t|
      t.integer 'custom_field_id', default: 0, null: false
      t.integer 'type_id', default: 0, null: false
    end

    add_index :custom_fields_types,
              %i[custom_field_id type_id],
              name: :custom_fields_types_unique,
              unique: true
  end

  def create_custom_options_table
    create_table :custom_options, id: :integer do |t|
      t.integer :custom_field_id
      t.integer :position
      t.boolean :default_value
      t.text :value
      t.datetime :created_at, :datetime
      t.datetime :updated_at, :datetime
    end
  end

  def create_custom_values_table
    create_table :custom_values, id: :integer, force: true do |t|
      t.string 'customized_type', limit: 30, default: '', null: false
      t.integer 'customized_id', default: 0, null: false
      t.integer 'custom_field_id', default: 0, null: false
      t.text 'value'
    end

    add_index :custom_values, :custom_field_id, name: 'index_custom_values_on_custom_field_id'
    add_index :custom_values, %i[customized_type customized_id], name: 'custom_values_customized'
  end

  def create_news_table
    create_table :news, id: :integer, force: true do |t|
      t.integer 'project_id'
      t.string 'title', limit: 60, default: '', null: false
      t.string 'summary', default: ''
      t.text 'description'
      t.integer 'author_id', default: 0, null: false
      t.datetime 'created_on'
      t.integer 'comments_count', default: 0, null: false
    end

    add_index :news, :author_id, name: 'index_news_on_author_id'
    add_index :news, :created_on, name: 'index_news_on_created_on'
    add_index :news, :project_id, name: 'news_project_id'

    add_index :news, %i[project_id created_on]
  end

  def create_custom_styles_table
    create_table :custom_styles, id: :integer do |t|
      t.string :logo
      t.string :favicon
      t.string :touch_icon

      t.timestamps
    end
  end

  def create_design_colors_table
    create_table :design_colors, id: :integer do |t|
      t.string :variable
      t.string :hexcode

      t.timestamps
    end

    add_index :design_colors, :variable, unique: true
  end

  def create_enterprise_tokens_table
    create_table :enterprise_tokens, id: :integer do |t|
      t.text :encoded_token

      t.timestamps
    end
  end

  def aggregated_versions_3_0
    @aggregated_versions_3_0 ||= Aggregated::To_3_0.normalized_migrations
  end

  def aggregated_versions_7_1
    @aggregated_versions_3_0 ||= Aggregated::To_7_1.normalized_migrations
  end

  def all_versions
    @all_versions ||= ActiveRecord::Migrator.get_all_versions
  end

  def schema_migrations_table_name
    ActiveRecord::Migrator.schema_migrations_table_name
  end

  def quoted_schema_migrations_table_name
    ActiveRecord::Base.connection.quote_table_name(schema_migrations_table_name)
  end

  def quoted_version_column_name
    ActiveRecord::Base.connection.quote_table_name('version')
  end

  def version_column_for_comparison
    "#{quoted_schema_migrations_table_name}.#{quoted_version_column_name}"
  end

  def quote_value(s)
    ActiveRecord::Base.connection.quote(s)
  end
end
