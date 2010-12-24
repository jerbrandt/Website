class ApplicationController < ActionController::Base
  protect_from_forgery

  # make these available to the views
  helper_method :active_section?, :construct_blog_path, :encrypt, :decrypt

  def layout
    request.xhr? ? false : 'application'
  end

  def minimal_layout
    @frame = :minimal
    layout
  end

  def active_section(section)
    @active_section = section
  end

  def active_section?(section)
    @active_section && @active_section.to_s.eql?(section)
  end

  def redirect_unless_admin
    unless user_signed_in? && current_user.admin?
      flash[:error] = 'You are not permitted to view that page.'
      redirect_to (request.env["HTTP_REFERER"].present? ? request.env["HTTP_REFERER"] : root_path)
    end
  end

  def construct_blog_path(obj, action='index', context=nil)
    if obj.present?
      raise "Invalid Context -- #{obj.context}" unless obj.valid_context?
      context = obj.context
    elsif context.present?
      raise "Invalid Context -- #{context}" unless Blog::VALID_CONTEXTS.include?(context.to_s)
    else
      raise "Invalid"
    end
    
    case action.to_s.intern
    when :index, :create, :delete then send("#{context.pluralize}_path")
    when :new, :edit              then send("#{action.to_s}_#{context.singularize}_path")
    when :show, :update           then send("#{context.singularize}_path", obj.respond_to?(:title_for_url) ? obj.title_for_url : obj.id)
    end
  end

  # Because of the widespead use of the 'seller_listings/form' partial, we need a @seller_listing object on
  # probably 80% of our pages. Additionally, that object needs to have user info when possible to pre-populate
  # the fields
  def set_seller_listing
    if user_signed_in?
      @seller_listing = SellerListing.new(:user_id => current_user.id)
    else
      @seller_listing = SellerListing.new()
      @seller_listing.user = User.new
    end
  end

  # See check for @noindex in application.haml for relevance
  def set_noindex
    @noindex = params[:page].to_i>1
  end

  # Rules
  # 1. the 'path' parameter is the ONLY parameter we accept. The main function of this is to weed out tracking
  #    parameters. This means we construct canonical paths using a white list (things we accept, i.e. page) and not a
  #    black list (things we do not accept, i.e. YSMKEY). This may introduce a maintenance nightmare going forward as
  #    any new accepted parameter will have to be added to this. However, for the foreseeable future, pagination is
  #    the only instance where params should be passed. In all other cases, params should be passed in the path itself
  # 2. Page 1 of any paginated page is actually the page itself, so no page param is needed
  def canonical_path
    # root_url ends in a slash, request.path starts with one, we need to strip one of them out!
    url = "#{root_url.gsub(/\/$/,'')}#{request.path}"

    # rule #1 && rule #2
    if params['page'] && params['page'].to_i != 1
      url = url + "?page=#{params[:page]}"
    end

    url
  end

  def encrypt(*args)
    YAML::dump(args).encrypt(:symmetric, :password => KEYS['encryption']['password'])
  end
  
  def decrypt(str)
    YAML::load(str.decrypt(:symmetric, :password => KEYS['encryption']['password']))
  end
end

