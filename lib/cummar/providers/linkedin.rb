#!/usr/bin/env ruby
#
# This file is part of cummar. Copyright (C) 2013 and above Shogun <shogun@cowtech.it>.
# Licensed under the MIT license, which can be found at https://choosealicense.com/licenses/mit.
#

module Cummar
  module Providers
    class Linkedin < Base
      def name
        "LinkedIn"
      end

      def has_authentication_data?
        configuration["token"].present? && configuration["token_secret"].present?
      end

      def save_authentication(auth_data)
        store_oauth(auth_data)
        save_configuration(configuration)
      end

      def contacts
        begin
          @contacts = read_cache

          if !@contacts then
            client = get_client
            @contacts = sort(fetch_contacts(client).map {|connection| build_contact(connection) }.compact)
            write_cache(@contacts)
          end

          @contacts
        rescue => e
          clear_authentication if e.is_a?(::LinkedIn::Errors::UnauthorizedError)
          raise e
        end
      end

      def profile_for(contact)
        contact.record["public_profile_url"]
      end

      def supported_fields
        ["social", "photo"]
      end

      private
        def get_client
          client = ::LinkedIn::Client.new(configuration["app_key"], configuration["app_secret"])
          client.authorize_from_access(configuration["token"], configuration["token_secret"])
          client
        end

        def fetch_contacts(client)
          rv = []
          start = 0
          count = 100

          while start do
            connections = client.connections(fields: ["id", "formatted-name", "picture-url", "public-profile-url"], start: start, count: count)["all"]

            if connections then
              rv += connections
              start += count
            else
              start = nil
            end
          end

          rv
        end

        def build_contact(user)
          id = user["id"]

          nick = if user["public_profile_url"] then
            user["public_profile_url"].gsub(/#{Regexp.quote("http://www.linkedin.com/")}[^\/]+\/([^\/]+)(\/.+)?/, "\\1")
          else
            id
          end

          if id != "private" then
            Cummar::RemoteContact.new(record: user, provider: "linkedin", id: id, name: user["formatted_name"], nick: nick, photo: user["picture_url"])
          else
            nil
          end
        end

        def clear_authentication
          configuration["token"] = ""
          configuration["token_secret"] = ""
          save_configuration(configuration)
        end
    end
  end
end