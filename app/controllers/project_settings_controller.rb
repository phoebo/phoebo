class ProjectSettingsController < ApplicationController
  before_filter :authenticate_user!
  before_filter :load_project_set

  def show
    # Nested form is skipped otherwise
    @project_set.settings = ProjectSettings.new unless @project_set.settings
  end

  def update
    update_params = project_set_params

    # Sanitize params
    allowed_param_ids = @project_set.params.pluck(:id)
    update_params[:params_attributes].select! do |_, params_attributes|
      ret = true

      # Skip empty keys
      ret = false if params_attributes[:name].blank?

      # Cross-check @project_set param ids
      if params_attributes[:id]
        ret = false unless allowed_param_ids.include?(params_attributes[:id].to_i)
      end

      # Skip secret params with no value (****)
      if params_attributes[:secret] == 'true'
        ret = false unless params_attributes[:value].match(/[^\*]/)
      end

      ret
    end

    @project_set.update(update_params)

    if @project_set.valid?
      flash[:success] = 'Settings has been updated.'
      redirect_to @url
    else
      render 'show'
    end
  end

  private

  def load_project_set
    case
    when params[:namespace] && params[:project]
      @project = ProjectInfo.find_by_path(
        params[:namespace], params[:project],
        for_user: current_user,
        project_set_init: true
      )

      if @project
        @url = project_settings_path(params[:namespace], params[:project])
        @project_set = @project.project_set
      else
        head :not_found and return
      end

    when params[:namespace]
      # TODO: Not implemented yet
      head :not_found and return

      # @url = namespace_settings_path(params[:namespace])
      # @project_set = ProjectSet.find_or_initialize_by(
      #   kind: ProjectSet.kinds[:with_namespace_id],
      #   filter_pattern: 123
      # )
    else
      unless current_user.is_admin
        head :forbidden and return
      end

      @url = projects_settings_path
      @project_set = ProjectSet.find_or_initialize_by(
        kind: ProjectSet.kinds[:all_projects]
      )
    end
  end

  def project_set_params
    permitted = {}

    # Settings
    permitted[:settings_attributes] = [
      :cpu, :memory
    ]

    # Basic params attributes
    permitted[:params_attributes] = [
      :name, :value, :secret
    ]

    # Params attribtes for update
    if @project_set.persisted?
      permitted[:params_attributes] += [
        :id, :_destroy
      ]
    end

    params.require(:project_set).permit(permitted)
  end
end