class ServicesController < ApplicationController
  before_action :authenticate_user!, except: [:show]
  before_action :set_curator, only: [:destroy]
  before_action :set_service, only: [:show, :edit, :annotate, :quote, :update, :destroy]

  def index
    @services = Service.includes(points: [:case]).all
    if @query = params[:query]
      @services = Service.search_by_name(@query)
    end
  end

  def new
    @service = Service.new
  end

  def create
    @service = Service.new(service_params)
    if @service.save
      redirect_to services_path
    else
      render :new
    end
  end

  def annotate
    puts 'annotate!'
    @points = @service.points.where('"status" in (\'approved\', \'pending\')').where('"case_id" is not null')
    puts @points.length.to_s + ' points:'
    @points.each do |p|
      puts p.id.to_s + ': ' + p.title + ' (' + p.quoteDoc.to_s + ')'
    end
    @documents = @service.documents
    puts @documents.length.to_s + ' docs for service_id ' + @service.id.to_s
  end

  def quote
    puts 'quote!'
    puts params
    point = Point.find(params[:quotePointId])
    document = @service.documents.where('"name" = ?', params[:quoteDoc])[0]
    point.update(
      quoteDoc: params[:quoteDoc],
      quoteRev: params[:quoteRev],
      quoteStart: params[:quoteStart],
      quoteEnd: params[:quoteEnd],
      quoteText: document.text[params[:quoteStart].to_i, params[:quoteEnd].to_i - params[:quoteStart].to_i]
    )
    if (point.save)
      redirect_to service_path(params[:id]) + '/annotate'
    else
      puts point.errors.full_messages
    end
  end

  def show
    if current_user
      case params[:scope]
      when nil
        @points = @service.points
      when 'pending'
        @points = @service.points.where(status: 'pending')
      when 'archived-versions'
        @versions = @service.versions
      end
    else
      @points = @service.points.where(status: 'approved')
    end

    @versions = @service.versions

    if @query = params[:topic]
      @points = @points.where(topic_id: params[:topic][:id])
    end
  end

  def edit
  end

  def update
    @service.update(service_params)
    redirect_to service_path(@service)
  end

  def destroy
    if @service.points.any?
      flash[:alert] = "Users have contributed valuable insight to this service!"
      redirect_to service_path(@service)
    else
      @service.destroy
      flash[:notice] = "Service has been removed!"
      redirect_to services_path
    end
  end

  private

  def set_service
    @service = Service.includes(points: [:case]).find(params[:id] || params[:service_id])
  end

  def service_params
    params.require(:service).permit(:name, :url, :query, :wikipedia, :is_comprehensively_reviewed)
  end

  def set_curator
    unless current_user.curator?
      render :file => "public/401.html", :status => :unauthorized
    end
  end
end
