require 'test_helper'
require 'gds_api/publishing_api_v2'
require 'json'

describe GdsApi::PublishingApiV2 do
  include PactTest

  def content_item_for_content_id(content_id, attrs = {})
    {
      "base_path" => "/robots.txt",
      "content_id" => content_id,
      "title" => "Instructions for crawler robots",
      "description" => "robots.txt provides rules for which parts of GOV.UK are permitted to be crawled by different bots.",
      "format" => "special_route",
      "public_updated_at" => "2015-07-30T13:58:11.000Z",
      "publishing_app" => "static",
      "rendering_app" => "static",
      "routes" => [
        {
          "path" => attrs["base_path"] || "/robots.txt",
          "type" => "exact"
        }
      ],
      "update_type" => "major"
    }.merge(attrs)
  end

  before do
    @base_api_url = Plek.current.find("publishing-api")
    @api_client = GdsApi::PublishingApiV2.new('http://localhost:3093')

    @content_id = "bed722e6-db68-43e5-9079-063f623335a7"
  end

  describe "#put_content" do
    it "responds with 200 OK if the entry is valid" do
      content_item = content_item_for_content_id(@content_id)

      publishing_api
        .given("both content stores and the url-arbiter are empty")
        .upon_receiving("a request to create a content item without links")
        .with(
          method: :put,
          path: "/v2/content/#{@content_id}",
          body: content_item,
          headers: {
            "Content-Type" => "application/json",
          },
        )
        .will_respond_with(
          status: 200,
        )

      response = @api_client.put_content(@content_id, content_item)
      assert_equal 200, response.code
    end

    it "responds with 409 Conflict if the path is reserved by a different app" do
      content_item = content_item_for_content_id(@content_id, "base_path" => "/test-item", "publishing_app" => "whitehall")

      publishing_api
        .given("/test-item has been reserved in url-arbiter by the Publisher application")
        .upon_receiving("a request from the Whitehall application to create a content item at /test-item")
        .with(
          method: :put,
          path: "/v2/content/#{@content_id}",
          body: content_item,
          headers: {
            "Content-Type" => "application/json",
          }
        )
        .will_respond_with(
          status: 409,
          body: {
            "error" => {
              "code" => 409,
              "message" => Pact.term(generate: "Conflict", matcher:/\S+/),
              "fields" => {
                "base_path" => Pact.each_like("is already in use by the 'publisher' app", :min => 1),
              },
            },
          },
          headers: {
            "Content-Type" => "application/json; charset=utf-8"
          }
        )

      error = assert_raises GdsApi::HTTPConflict do
        @api_client.put_content(@content_id, content_item)
      end
      assert_equal "Conflict", error.error_details["error"]["message"]
    end

    it "responds with 422 Unprocessable Entity with an invalid item" do
      content_item = content_item_for_content_id(@content_id, "base_path" => "not a url path")

      publishing_api
        .given("both content stores and the url-arbiter are empty")
        .upon_receiving("a request to create an invalid content-item")
        .with(
          method: :put,
          path: "/v2/content/#{@content_id}",
          body: content_item,
          headers: {
            "Content-Type" => "application/json",
          },
        )
        .will_respond_with(
          status: 422,
          body: {
            "error" => {
              "code" => 422,
              "message" => Pact.term(generate: "Unprocessable entity", matcher:/\S+/),
              "fields" => {
                "base_path" => Pact.each_like("is invalid", :min => 1),
              },
            },
          },
          headers: {
            "Content-Type" => "application/json; charset=utf-8"
          }
        )

      error = assert_raises GdsApi::HTTPClientError do
        @api_client.put_content(@content_id, content_item)
      end
      assert_equal 422, error.code
      assert_equal "Unprocessable entity", error.error_details["error"]["message"]
    end
  end

  describe "#get_content" do
    it "responds with 200 and the content item when it exists" do
      content_item = content_item_for_content_id(@content_id)
      publishing_api
        .given("a content item exists with content_id: #{@content_id}")
        .upon_receiving("a request to return the content item")
        .with(
          method: :get,
          path: "/v2/content/#{@content_id}",
        )
        .will_respond_with(
          status: 200,
          body: {
            "content_id" => @content_id,
            "format" => Pact.like("special_route"),
            "publishing_app" => Pact.like("publisher"),
            "rendering_app" => Pact.like("frontend"),
            "locale" => Pact.like("en"),
            "routes" => Pact.like([{}]),
            "public_updated_at" => Pact.like("2015-07-30T13:58:11.000Z"),
            "details" => Pact.like({})
          },
          headers: {
            "Content-Type" => "application/json; charset=utf-8",
          },
        )

      response = @api_client.get_content(@content_id)
      assert_equal 200, response.code
      assert_equal content_item["format"], response["format"]
    end

    it "responds with 404 for a non-existent item" do
      publishing_api
        .given("both content stores and the url-arbiter are empty")
        .upon_receiving("a request for a non-existent content item")
        .with(
          method: :get,
          path: "/v2/content/#{@content_id}",
        )
        .will_respond_with(
          status: 404,
          body: {
            "error" => {
              "code" => 404,
              "message" => Pact.term(generate: "not found", matcher:/\S+/)
            },
          },
          headers: {
            "Content-Type" => "application/json; charset=utf-8",
          },
        )

      assert_nil @api_client.get_content(@content_id)
    end
  end

  describe "#publish" do
    it "responds with 200 if the publish command succeeds" do
      publishing_api
        .given("a draft content item exists with content_id: #{@content_id}")
        .upon_receiving("a publish request")
        .with(
          method: :post,
          path: "/v2/content/#{@content_id}/publish",
          body: {
            update_type: "major",
          },
          headers: {
            "Content-Type" => "application/json",
          },
        )
        .will_respond_with(
          status: 200
        )

      response = @api_client.publish(@content_id, "major")
      assert_equal 200, response.code
    end

    it "responds with 404 if the content item does not exist" do
      publishing_api
        .given("both content stores and url-arbiter empty")
        .upon_receiving("a publish request")
        .with(
          method: :post,
          path: "/v2/content/#{@content_id}/publish",
          body: {
            update_type: "major",
          },
          headers: {
            "Content-Type" => "application/json",
          },
        )
        .will_respond_with(
          status: 404
        )

      error = assert_raises GdsApi::HTTPClientError do
        @api_client.publish(@content_id, "major")
      end

      assert_equal 404, error.code
    end

    it "responds with 422 if the content item is not publishable" do
      publishing_api
        .given("a draft content item exists with content_id: #{@content_id} which does not have a publishing_app")
        .upon_receiving("a publish request")
        .with(
          method: :post,
          path: "/v2/content/#{@content_id}/publish",
          body: {
            update_type: "major",
          },
          headers: {
            "Content-Type" => "application/json",
          },
        )
        .will_respond_with(
          status: 422,
          body: {
            "error" => {
              "code" => 422,
              "fields" => {
                "publishing_app"=>["can't be blank"],
              },
            },
          }
        )

      error = assert_raises GdsApi::HTTPClientError do
        @api_client.publish(@content_id, "major")
      end

      assert_equal 422, error.code
      assert_equal ["can't be blank"], error.error_details["error"]["fields"]["publishing_app"]
    end

    it "responds with 422 if the update information is invalid" do
      publishing_api
        .given("a draft content item exists with content_id: #{@content_id}")
        .upon_receiving("an invalid publish request")
        .with(
          method: :post,
          path: "/v2/content/#{@content_id}/publish",
          body: {
            "update_type" => ""
          },
          headers: {
            "Content-Type" => "application/json",
          },
        )
        .will_respond_with(
          status: 422,
          body: {
            "error" => {
              "code" => 422,
              "message" => Pact.term(generate: "Unprocessable entity", matcher:/\S+/),
              "fields" => {
                "update_type" => Pact.each_like("is required", :min => 1),
              },
            },
          }
        )

      error = assert_raises GdsApi::HTTPClientError do
        @api_client.publish(@content_id, "")
      end

      assert_equal 422, error.code
      assert_equal "Unprocessable entity", error.error_details["error"]["message"]
    end

    it "responds with 400 if the content item is already published" do
      publishing_api
        .given("a published content item exists with content_id: #{@content_id}")
        .upon_receiving("a publish request")
        .with(
          method: :post,
          path: "/v2/content/#{@content_id}/publish",
          body: {
            update_type: "major",
          },
          headers: {
            "Content-Type" => "application/json",
          },
        )
        .will_respond_with(
          status: 400,
          body: {
            "error" => {
              "code" => 400, "message" => Pact.term(generate: "Cannot publish an already published content item", matcher:/\S+/),
            },
          }
        )

      error = assert_raises GdsApi::HTTPClientError do
        @api_client.publish(@content_id, "major")
      end

      assert_equal 400, error.code
      assert_equal "Cannot publish an already published content item", error.error_details["error"]["message"]
    end
  end

  describe "#get_links" do
    describe "when there's a links entry with links" do
      before do
        publishing_api
          .given("organisation links exist for content_id #{@content_id}")
          .upon_receiving("a get-links request")
          .with(
            method: :get,
            path: "/v2/links/#{@content_id}",
          )
          .will_respond_with(
            status: 200,
            body: {
              links: {
                organisations: ["20583132-1619-4c68-af24-77583172c070"]
              }
            }
          )
      end

      it "responds with the links" do
        response = @api_client.get_links(@content_id)
        assert_equal 200, response.code
        assert_equal ["20583132-1619-4c68-af24-77583172c070"], response.links[:organisations]
      end
    end

    describe "when there's an empty links entry" do
      before do
        publishing_api
          .given("empty links exist for content_id #{@content_id}")
          .upon_receiving("a get-links request")
          .with(
            method: :get,
            path: "/v2/links/#{@content_id}",
          )
          .will_respond_with(
            status: 200,
            body: {
              links: {
              }
            }
          )
      end

      it "responds with the empty link set" do
        response = @api_client.get_links(@content_id)
        assert_equal 200, response.code
        assert_equal OpenStruct.new({}), response.links
      end
    end

    describe "when there's no links entry" do
      before do
        publishing_api
          .given("no links exist for content_id #{@content_id}")
          .upon_receiving("a get-links request")
          .with(
            method: :get,
            path: "/v2/links/#{@content_id}",
          )
          .will_respond_with(
            status: 404
          )
      end

      it "responds with 404" do
        response = @api_client.get_links(@content_id)
        assert_nil response
      end
    end
  end
end
