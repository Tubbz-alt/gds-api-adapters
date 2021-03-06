require "test_helper"
require "gds_api/performance_platform/data_in"
require "gds_api/test_helpers/performance_platform/data_in"

describe GdsApi::PerformancePlatform::DataIn do
  include GdsApi::TestHelpers::PerformancePlatform::DataIn

  before do
    @base_api_url = GdsApi::TestHelpers::PerformancePlatform::DataIn::PP_DATA_IN_ENDPOINT
    @api = GdsApi::PerformancePlatform::DataIn.new(@base_api_url)
  end

  it "can submit a day aggregate for service feedback for a particular slug" do
    request_details = { "some" => "data" }

    stub_post = stub_service_feedback_day_aggregate_submission("some-slug", request_details)

    @api.submit_service_feedback_day_aggregate("some-slug", request_details)

    assert_requested(stub_post)
  end

  it "can submit entries counts for corporate content problem reports" do
    entries = %w[some entries]

    stub_post = stub_corporate_content_problem_report_count_submission(entries)

    @api.corporate_content_problem_report_count(entries)

    assert_requested(stub_post)
  end

  it "can submit the corporate content urls with the most problem reports" do
    entries = %w[some entries]

    stub_post = stub_corporate_content_urls_with_the_most_problem_reports_submission(entries)

    @api.corporate_content_urls_with_the_most_problem_reports(entries)

    assert_requested(stub_post)
  end

  it "throws an exception when the support app isn't available" do
    stub_pp_isnt_available
    assert_raises(GdsApi::HTTPServerError) { @api.submit_service_feedback_day_aggregate("doesnt_matter", {}) }
  end

  it "throws an exception when the the bucket for that slug hasn't been defined" do
    stub_service_feedback_bucket_unavailable_for("some_transaction")
    assert_raises(GdsApi::PerformancePlatformDatasetNotConfigured) { @api.submit_service_feedback_day_aggregate("some_transaction", {}) }
  end
end
