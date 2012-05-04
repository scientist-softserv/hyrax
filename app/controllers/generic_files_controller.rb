class GenericFilesController < ApplicationController
  include Hydra::Controller
  include Hydra::AssetsControllerHelper  # This is to get apply_depositor_metadata method
  include Hydra::FileAssetsHelper
  include PSU::Noid

  # actions: audit, index, create, new, edit, show, update, destroy
  before_filter :authenticate_user!, :only=>[:create, :new]
  before_filter :enforce_access_controls, :only=>[:edit, :update, :show, :audit, :index, :destroy]
  before_filter :find_by_id, :only=>[:audit, :edit, :show, :update, :destroy]
  prepend_before_filter :normalize_identifier, :only=>[:audit, :edit, :show, :update, :destroy] 

  # routed to /files/new
  def new
    @generic_file = GenericFile.new 
    @noid_s = PSU::IdService.mint
    @dc_metadata = [
      ['Based Near', 'based_near'],
      ['Contributor', 'contributor'],
      ['Creator', 'creator'], 
      ['Date Created', 'date_created'], 
      ['Description', 'description'],
      ['Identifier', 'identifier'],
      ['Language', 'language'], 
      ['Publisher', 'publisher'], 
      ['Rights', 'rights'],
      ['Subject', 'subject'], 
      ['Tag', 'tag'], 
      ['Title', 'title'],
      ['Related URL', 'related_url']
    ]
  end

  # routed to /files/:id/edit
  def edit
    @terms = @generic_file.get_terms
  end

  # routed to /files/:id
  def index
    @generic_files = GenericFile.find(:all, :rows => GenericFile.count)
    render :json => @generic_files.collect { |p| p.to_jq_upload }.to_json
  end

  # routed to /files/:id (DELETE)
  def destroy
    @generic_file.delete
    flash[:notice] = render_to_string(:partial=>'generic_files/asset_deleted_flash', :locals => { :generic_file => @generic_file })
    redirect_to dashboard_path
  end

  # routed to /files (POST)
  def create
    create_and_save_generic_file 
    logger.info "?????? #{@generic_file.inspect} #{@generic_file.batch}"
    if @generic_file
      respond_to do |format|
        format.html {
          render :json => [@generic_file.to_jq_upload].to_json,
            :content_type => 'text/html',
            :layout => false
        }
        format.json {
          render :json => [@generic_file.to_jq_upload].to_json
        }
      end
    else
      puts "respond bad"
      render :json => [{:error => "custom_failure"}], :status => 304
    end
  end

  # routed to /files/:id
  def show
  end

  # routed to /files/:id/audit (POST)
  def audit
    render :json=>@generic_file.audit
  end
 
  # routed to /files/:id (PUT)
  def update
    if params.has_key?(:revision) and params[:revision] !=  @generic_file.content.latest_version.versionID
      revision = @generic_file.content.get_version(params[:revision])
      @generic_file.add_file_datastream(revision.content, :dsid => 'content')
    end
    add_posted_blob_to_asset(@generic_file, params[:filedata]) if params.has_key?(:filedata) 
    @generic_file.update_attributes(params[:generic_file].reject { |k,v| %w{ Filedata Filename revision}.include? k})
    @generic_file.date_modified = Time.now.ctime
    @generic_file.save
    redirect_to dashboard_path, :notice => render_to_string(:partial=>'generic_files/asset_updated_flash', :locals => { :generic_file => @generic_file })
  end

  protected
  def find_by_id
    @generic_file = GenericFile.find(params[:id])
  end

  def create_and_save_generic_file      
    if params.has_key?(:files)
      @generic_file = GenericFile.new
      file = params[:files][0]
      add_posted_blob_to_asset(@generic_file,file)
      apply_depositor_metadata(@generic_file)
      @generic_file.date_uploaded = Time.now.ctime
      @generic_file.date_modified = Time.now.ctime
      if params.has_key?(:batch_id)
        @generic_file.add_relationship("isPartOf", "info:fedora/#{params[:batch_id]}")
      else
        puts "unable to find batch to attach to"
      end
      @generic_file.save      
      return @generic_file
    else
      return @generic_file
    end
  end
end
