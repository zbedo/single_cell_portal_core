require "test_helper"

describe AnalysisConfigurationsController do
  let(:analysis_configuration) { analysis_configurations :one }

  it "gets index" do
    get analysis_configurations_url
    value(response).must_be :success?
  end

  it "gets new" do
    get new_analysis_configuration_url
    value(response).must_be :success?
  end

  it "creates analysis_configuration" do
    expect {
      post analysis_configurations_url, params: { analysis_configuration: {  } }
    }.must_change "AnalysisConfiguration.count"

    must_redirect_to analysis_configuration_path(AnalysisConfiguration.last)
  end

  it "shows analysis_configuration" do
    get analysis_configuration_url(analysis_configuration)
    value(response).must_be :success?
  end

  it "gets edit" do
    get edit_analysis_configuration_url(analysis_configuration)
    value(response).must_be :success?
  end

  it "updates analysis_configuration" do
    patch analysis_configuration_url(analysis_configuration), params: { analysis_configuration: {  } }
    must_redirect_to analysis_configuration_path(analysis_configuration)
  end

  it "destroys analysis_configuration" do
    expect {
      delete analysis_configuration_url(analysis_configuration)
    }.must_change "AnalysisConfiguration.count", -1

    must_redirect_to analysis_configurations_path
  end
end
