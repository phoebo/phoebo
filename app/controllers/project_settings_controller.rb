class ProjectSettingsController < ApplicationController
  before_filter :authenticate_user!
  before_filter :load_project_set

  def show
    # Nested form is skipped otherwise
    @project_binding.settings = ProjectSettings.new unless @project_binding.settings
  end

  def update
    update_params = project_binding_params

    # Sanitize settings
    if update_params[:settings_attributes][:id]
      if !@project_binding.settings || update_params[:settings_attributes][:id] != "#{@project_binding.settings.id}"
        update_params[:settings_attributes].delete(:id)
      end
    end

    # Sanitize params
    allowed_param_ids = @project_binding.params.pluck(:id)
    update_params[:params_attributes].select! do |_, params_attributes|
      ret = true

      # Skip empty keys
      ret = false if params_attributes[:name].blank?

      # Cross-check @project_binding param ids
      if params_attributes[:id]
        ret = false unless allowed_param_ids.include?(params_attributes[:id].to_i)
      end

      # Skip secret params with no value (****)
      if params_attributes[:secret] == 'true'
        params_attributes.delete(:value) unless params_attributes[:value].match(/[^\*]/)
      end

      ret
    end

    @project_binding.update_attributes(update_params)

    if @project_binding.valid?
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
        @project_binding = @project.bindings[:project]
        @parent_accessor = @project.bindings.parent
      else
        head :not_found and return
      end

    when params[:namespace]
      # TODO: Not implemented yet
      head :not_found and return
      # @url = namespace_settings_path(params[:namespace])
    else
      unless current_user.is_admin
        head :forbidden and return
      end

      accessor = ProjectAccessor.new

      @url = projects_settings_path
      @project_binding = accessor[:default]
      @parent_accessor = accessor.parent
    end
  end

  def project_binding_params
    permitted = {}

    # Settings
    permitted[:settings_attributes] = [
      :id, :cpu, :memory
    ]

    # Basic params attributes
    permitted[:params_attributes] = [
      :name, :value, :secret
    ]

    # Params attribtes for update
    if @project_binding.persisted?
      permitted[:params_attributes] += [
        :id, :_destroy
      ]
    end

    params.require(:project_binding).permit(permitted)
  end
end