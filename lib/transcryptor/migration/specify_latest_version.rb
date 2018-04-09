# frozen_string_literal: true

module Transcryptor
  class Migration
    # :specify_latest_version! is called after model initialization
    # and sets encrypted field version to the latest one
    module SpecifyLatestVersion
      def specify_latest_version!
        migrated_fields = Transcryptor::Migration.migrations[self.class]
        migrated_fields.each do |field, versions|
          latest_v  = versions[:latest_version].to_i
          next if public_send("#{field}_version")

          public_send("#{field}_version=", latest_v)
        end
      end
      private :specify_latest_version!
    end
  end
end
