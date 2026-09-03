class InteractionsController < ApplicationController
  before_action :set_queue, only: %i[new create]
  before_action :set_interaction, only: %i[edit update start finish remove]

  def new
    @interaction = @queue.interactions.new
    build_missing_answers
  end

  def create
    @interaction = @queue.interactions.new(interaction_params)

    if @interaction.save
      redirect_to queue_path(@queue), notice: "Interaction added."
    else
      flash.now[:alert] = @interaction.errors.full_messages.to_sentence
      render :new, status: :unprocessable_entity
    end
  end

  def edit
    build_missing_answers
  end

  def update
    if @interaction.update(interaction_params)
      redirect_to queue_path(@interaction.queue), notice: "Interaction updated."
    else
      build_missing_answers
      flash.now[:alert] = @interaction.errors.full_messages.to_sentence
      render :edit, status: :unprocessable_entity
    end
  end

  def start
    if @interaction.startable?
      @interaction.in_progress!
      redirect_to queue_path(@interaction.queue), notice: "Interaction started."
    else
      redirect_to queue_path(@interaction.queue), alert: "Another interaction is already in progress."
    end
  end

  def finish
    if @interaction.in_progress?
      @interaction.finished!
      redirect_to queue_path(@interaction.queue), notice: "Interaction finished."
    else
      redirect_to queue_path(@interaction.queue), alert: "Only an in-progress interaction can be finished."
    end
  end

  def remove
    @interaction.deleted!
    redirect_to queue_path(@interaction.queue), notice: "Interaction removed."
  end

  private

  def set_queue
    @queue = ProfileQueue.includes(profile: :questions).find(params[:queue_id])
  end

  def set_interaction
    @interaction = Interaction.includes(answers: :question).find(params[:id])
  end

  def interaction_params
    params.require(:interaction).permit(
      :name,
      answers_attributes: %i[id question_id value question_text]
    )
  end

  # A blank answer for every profile question that hasn't been answered yet, so
  # a new interaction gets the full set and an existing one picks up questions
  # added since it was created.
  def build_missing_answers
    answered = @interaction.answers.map(&:question_id).compact

    @interaction.queue.profile.questions.each do |question|
      next if answered.include?(question.id)

      @interaction.answers.new(question: question, question_text: question.text)
    end
  end
end
