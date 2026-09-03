class HomeController < ApplicationController
  def index
    @profiles = Profile.includes(:user).order(:id)
    @interaction_counts = Interaction.joins(:queue).group("queues.profile_id").count
  end
end
