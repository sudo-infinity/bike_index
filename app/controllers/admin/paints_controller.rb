class Admin::PaintsController < Admin::BaseController
  before_filter :find_paint, only: [:show, :edit, :update, :destroy]

  def index
    @paints = Paint.includes(:bikes).order("created_at asc")
  end

  # def new
  # end

  # def create
  # end

  def show
    redirect_to edit_admin_paint_url(@paint)
  end

  def edit
    @bikes = @paint.bikes
  end

  def update
    if @paint.update_attributes(params[:paint])
      flash[:notice] = "Paint updated!"
      if @paint.reload.color_id.present?
        bikes = @paint.bikes.where(primary_frame_color_id: Color.find_by_name('Black').id)
        bikes.each { |b| b.update_attributes(primary_frame_color_id: @paint.color_id) }
      end
      redirect_to admin_paints_url
    else
      render action: :edit
    end
  end

  def destroy
    if @paint.bikes.present?
      flash[:error] = "Not allowed! Bikes use that paint! How the fuck did you delete that anyway?"
    else
      @paint.destroy
      flash[:notice] = "Paint deleted!"
    end
    redirect_to admin_paints_url
  end

  protected

  def find_paint
    @paint = Paint.find(params[:id])
  end
end