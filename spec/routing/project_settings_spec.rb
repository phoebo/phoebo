require 'rails_helper'

RSpec.describe 'routes for ProjectSettings', type: :routing do

  it do
    expect(get('/project_settings')).to route_to('project_settings#show')
  end

  it do
    expect(get('/project_settings/jan.noha')).to route_to(
      'project_settings#show',
      namespace: 'jan.noha'
    )
  end

  it do
    expect(get('/project_settings/jan.noha/awesome_project')).to route_to(
      'project_settings#show',
      namespace: 'jan.noha', project: 'awesome_project'
    )
  end

end
