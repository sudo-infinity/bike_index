class Admin::NewsController < Admin::BaseController
  before_filter :find_blog, only: [:show, :edit, :update, :destroy]
  before_filter :set_dignified_name

  def index
    @blogs = Blog.order("created_at asc")
  end

  def new
    @blog = Blog.new(published_at: Time.now,
      user_id: current_user.id,
      is_listicle: current_user.is_content_admin
    )
    @users = User.all
  end

  def image_edit
    @listicle = Listicle.find(params[:id])
    @blog = @listicle.blog
  end

  def show
    redirect_to edit_admin_news_url
  end

  def edit
    @users = User.all
  end

  def update
    body = "blog"
    title = params[:blog][:title]
    body = params[:blog][:body]
    if @blog.update_attributes(params[:blog])
      @blog.reload
      if @blog.listicles.present?
        @blog.listicles.pluck(:id).each { |id| ListicleImageSizeWorker.perform_in(1.minutes, id) }
      end
      flash[:notice] = "Blog saved!"
      redirect_to edit_admin_news_url(@blog)
    else
      @users = User.blog_admin
      render action: :edit
    end
  end

  def create
    @blog = Blog.create({
      title: params[:blog][:title],
      user_id: current_user.id,
      body: "No content yet, write some now!",
      published_at: Time.now,
      is_listicle: params[:blog][:is_listicle]
    })
    if @blog.save
      flash[:notice] = "Blog created!"
      redirect_to edit_admin_news_url(@blog)
    else
      flash[:error] = "Blog error! #{@blog.errors.full_messages.to_sentence}"
      redirect_to new_admin_news_index_url
    end
  end

  def destroy
    @blog.destroy
    redirect_to admin_news_index_url
  end

  protected

  def set_dignified_name
    @dignified_name = "short form creative non-fiction"
    @dignified_name = "collection of vignettes" if @blog && @blog.is_listicle
  end

  def find_blog
    @blog = Blog.find_by_title_slug(params[:id])
  end
end
