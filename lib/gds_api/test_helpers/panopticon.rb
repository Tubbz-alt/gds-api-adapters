require 'json'

module GdsApi
  module TestHelpers
    module Panopticon
      PANOPTICON_ENDPOINT = 'https://panopticon.test.alphagov.co.uk'

      def stringify_hash_keys(input_hash)
        input_hash.inject({}) do |options, (key, value)|
          options[key.to_s] = value
          options
        end
      end

      def panopticon_has_metadata(metadata)
        metadata = stringify_hash_keys(metadata)

        json = JSON.dump(metadata)

        urls = []
        urls << "#{PANOPTICON_ENDPOINT}/artefacts/#{metadata['id']}.json" if metadata['id']
        urls << "#{PANOPTICON_ENDPOINT}/artefacts/#{metadata['slug']}.json" if metadata['slug']

        urls.each { |url| stub_request(:get, url).to_return(:status => 200, :body => json, :headers => {}) }

        return urls.first
      end

      def panopticon_has_no_metadata_for(slug)
        url = "#{PANOPTICON_ENDPOINT}/artefacts/#{slug}.json"
        stub_request(:get, url).to_return(:status => 404, :body => "", :headers => {})
      end

    end
  end
end
