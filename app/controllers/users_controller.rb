class UsersController < ApplicationController
  def new
    @user = User.new
    @profiles = other_profiles
  end

  def create
    @user = User.new(user_params)

    save_user { @user.save! }
  end

  def edit
    @user = User.find(params[:id])
    @profile = @user.profile
    @profiles = other_profiles
  end

  def update
    @user = User.find(params[:id])

    save_user { @user.update!(user_update_params) }
  end

  private

  # Saves the user and its questions together: either both land or neither does.
  def save_user
    action = @user.new_record? ? :new : :edit

    ActiveRecord::Base.transaction do
      yield
      sync_profile!
    end

    redirect_to root_path, notice: action == :new ? "User created" : "User updated"
  rescue ActiveRecord::RecordInvalid => e
    @profile = @user.profile
    @profiles = other_profiles
    @questions = submitted_question_records
    flash.now[:alert] = e.record.errors.full_messages.to_sentence
    render action, status: :unprocessable_entity
  end

  # A user only grows a profile once they're marked a converser; after that the
  # form always edits the profile's questions.
  def sync_profile!
    profile = @user.profile

    if profile.nil?
      return unless params[:converser] == "1"

      profile = @user.create_profile!
    end

    sync_questions!(profile)
  end

  # Replaces the profile's questions with the submitted rows: a row carrying an
  # id updates that question, a row without one creates it, and any question
  # left out of the form is deleted.
  def sync_questions!(profile)
    rows = submitted_questions
    existing = profile.questions.index_by(&:id)
    kept = rows.filter_map { |row| row[:id] if existing.key?(row[:id]) }

    profile.questions.where.not(id: kept).destroy_all

    rows.each_with_index do |row, index|
      question = existing[row[:id]] || profile.questions.new
      question.update!(
        text: row[:text],
        question_type: row[:question_type],
        config: config_for(row),
        position: index + 1
      )
    end
  end

  # Rebuilds the form's question rows from the submission so a validation error
  # doesn't throw away what was typed.
  def submitted_question_records
    submitted_questions.map do |row|
      Question.new(id: row[:id], text: row[:text], question_type: row[:question_type], config: config_for(row))
    end
  end

  # Profiles whose questions can be copied into the form.
  def other_profiles
    Profile.includes(:user, :questions).where.not(user_id: @user.id).to_a
  end

  def user_params
    params.require(:user).permit(:username, :name, :password, :password_confirmation)
  end

  # Leaving both password fields blank keeps the current password.
  def user_update_params
    attrs = user_params
    if attrs[:password].blank? && attrs[:password_confirmation].blank?
      attrs = attrs.except(:password, :password_confirmation)
    end
    attrs
  end

  # Returns the submitted questions as an array of hashes, ignoring blank rows.
  def submitted_questions
    Array(params[:questions]).filter_map do |q|
      q = q.respond_to?(:to_unsafe_h) ? q.to_unsafe_h : q
      text = q[:text].to_s.strip
      next if text.empty?

      {
        id: q[:id].presence&.to_i,
        text: text,
        question_type: q[:question_type].to_s,
        options: parse_options(q[:options])
      }
    end
  end

  def config_for(question)
    if %w[select radio].include?(question[:question_type])
      { "options" => question[:options] }
    else
      {}
    end
  end

  # Options arrive as a textarea/input value: one per line or comma-separated.
  def parse_options(raw)
    raw.to_s.split(/[\n,]+/).map(&:strip).reject(&:empty?)
  end
end
