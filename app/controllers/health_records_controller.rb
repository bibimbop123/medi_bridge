class HealthRecordsController < ApplicationController
  before_action :authenticate_user!
  before_action :set_health_record, only: %i[show edit update destroy translate toggle_view]

    helper_method :language_name  # NOTE: Be careful with indentation

  def index
    @health_records = current_user.health_records.order(created_at: :desc)
  end

  def show
    @current_view_language = session[:view_language] || @health_record.language
    @translation = @health_record.translation_for(@current_view_language) if @current_view_language != @health_record.language
    @available_translations = @health_record.translations.pluck(:language)
  end

def translate # NOTE: another indentation error (use a linter)
  target_locale = params[:target_locale] || current_user.preferred_language || 'en'
  
  if @health_record.has_translation?(target_locale)
    redirect_to @health_record, notice: "Translation already exists for #{language_name(target_locale)}"
    return
  end
  
  result = TranslateServices::TranslationService.new(
    health_record: @health_record,
    target_locale: target_locale
  ).call
  
  if result&.success?
    # Set session to show the new translation
    session[:view_language] = target_locale
    redirect_to @health_record, notice: "Translation to #{language_name(target_locale)} completed!"
  else
    redirect_to @health_record, alert: "Translation failed. Please try again."
  end
end


  def toggle_view
    session[:view_language] = params[:language] || @health_record.language
    redirect_to @health_record
  end

  def new
    @health_record = current_user.health_records.new
  end

  def create
    @health_record = current_user.health_records.new(health_record_params)
    if @health_record.save
      redirect_to @health_record, notice: "Health record created."
    else
      render :new, status: :unprocessable_entity
    end
  end

  def update
    if @health_record.update(health_record_params)
      redirect_to @health_record, notice: "Health record updated."
    else
      render :edit, status: :unprocessable_entity
    end
  end

  def destroy
    @health_record = HealthRecord.find(params[:id])
    @health_record.destroy
    
    respond_to do |format|
      format.html { redirect_to health_records_path, notice: 'Record was successfully deleted.' }
      format.json { head :no_content }
    end
  end

  private

  def set_health_record
    @health_record = current_user.health_records.find(params[:id])
  end

  def health_record_params
    params.require(:health_record).permit(:record_type, :language, :document)
  end

  def language_name(code) 
    # NOTE: nice cool implementation of translations
    HealthRecord::SUPPORTED_LANGUAGES.find { |_, c| c == code }&.first || code
  end
end