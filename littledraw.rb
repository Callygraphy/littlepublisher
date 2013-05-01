require 'rubygems'
require 'sinatra'
require 'data_mapper' # metagem, requires common plugins too.
require 'slim'
require 'rufus/scheduler'
require 'pony'
require 'chronic'

#scheduler for email notifications

scheduler = Rufus::Scheduler.start_new

# Set password here

set :username,'littlepublisher'
set :token,'6ff2b8421a6f24ae8cdc13cbbfd7f3d2'
set :password,'littlepublisher'

helpers do
  def admin? ; request.cookies[settings.username] == settings.token ; end
  def protected! ; halt [ 401, 'Not Authorized' ] unless admin? ; end
end


#database stuff

DataMapper::setup(:default, "sqlite3://#{Dir.pwd}/littledraw2.db")

class Post
    include DataMapper::Resource
    property :id, Serial
    property :pubdate, String
    property :url, Text
    property :caption, Text
    property :created_at, DateTime
end

DataMapper.finalize

Post.auto_upgrade!


# email notifications


#scheduler.cron '0 22 * * sun#1,sun#2,sun#3,sun#4' do
#scheduler.every '10m' do
#  date = Time.now
#  puts 'email sent'
#  Pony.mail(:to => 'cally.gatehouse@gmail.com', :from => 'noreply@littledraw.co.uk',
#            :subject => 'littledraw content for this week',
#            :html_body => '<h1>Hello there!</h1>', :body => "In case you can't read html, Hello there.")
# end
#end



get '/email/' do
    thisSat = Chronic.parse('this saturday')
    nextSat = Chronic.parse('saturday next week')
    @weekOne = thisSat.strftime("%F")
    @posts = Post.first(:pubdate => @weekOne)
end

# Little printer stuff

get '/sample/' do
    @posts = Post.get(1)
    date = Time.now
    @today = date.strftime("%F")
    
    if @posts == nil
        redirect to('/oops/')
    end

    slim :edition, :layout => false do
        slim :lp_layout
    end
end

get '/edition/' do
    
    date = Time.now
    @saturday = date.wday
    return unless @saturday == 6 #I know this a roundabout way of doing this but date.saturday? doesn't work on dreamhost
    @today = date.strftime("%F")
    @posts = Post.first(:pubdate => @today)
    # etag Digest::MD5.hexdigest("ld"+@today) #comment out etags when in development, else your page won't refresh
    
    if @posts == nil
        redirect to('/oops/')
    end
    slim :edition, :layout => false do
        slim :lp_layout
    end

end

#Admin section

get '/admin/' do
    slim :admin
end

post '/login' do
    if params['username']==settings.username&&params['password']==settings.password
        response.set_cookie(settings.username,settings.token)
        redirect '/upload/'
        else
        "Username or Password incorrect"
    end
end

get('/logout'){ response.set_cookie(settings.username, false) ; redirect '/' }


get '/upload/' do
    protected!
    @posts = Post.all
    slim :uploader
end

post '/upload/' do
    File.open('public/uploads/' + params['myfile'][:filename], "w") do |f|
        f.write(params['myfile'][:tempfile].read)
    end
    
    Post.create(:pubdate =>"#{params['pubdate']}", :url =>"#{params['myfile'][:filename]}", :caption => "#{params['caption']}" )
    
    redirect to('/upload/')
end

get '/preview/:idnumber' do
    protected!
    @posts = Post.get("#{params[:idnumber]}")
    slim :preview    
end

delete '/preview/:idnumber' do
    Post.get("#{params[:idnumber]}").destroy
    redirect to('/upload/')
end

post '/preview/:idnumber' do
    Post.create(:pubdate =>"#{params['pubdate']}", :url =>"#{params['myfile'][:filename]}", :caption => "#{params['caption']}" )
    redirect to('/preview/"#{params[:idnumber]}"')
end

# last resort

get '/oops/' do    
    "ooops!"
end


__END__

@@layout
doctype html
html
    head
        meta charset="utf-8"
        title littlepublisher
        link rel="stylesheet" media="screen, projection" href="/styles.css"

    body
        == yield

@@lp_layout
doctype html
html
    head
        meta charset="utf-8"
        title little publisher
        link rel="stylesheet" media="screen, projection" href="http://littledraw.co.uk/ld_styles.css"

    body
        == yield

@@edition
doctype html
html
    head
        meta charset="utf-8"
        title little publisher
        link rel="stylesheet" media="screen, projection" href="http://littledraw.co.uk/ld_styles.css"

    body
        img src="http://littledraw.co.uk/images/logo.jpg"
        img src="http://littledraw.co.uk/images/cross.png"
        h1 = @posts.caption
        img src="http://littledraw.co.uk/images/cross.png"
        img src="http://littledraw.co.uk/uploads/#{@posts.url}"
        img src="http://littledraw.co.uk/images/cross.png"
        div id="footer"


@@uploader
div class="row"    
    div class="span6 offset1"   
        h1 Upload a file
        form method="post" enctype='multipart/form-data'
          p select file
          input type='file' name='myfile'
          br
          p caption
          textarea name='caption'
          br
          p date to be published
          input type='date' name='pubdate'
          br
          input type='submit' value='Upload!'
    div class="span4"
        h2 existing editions
        ul.editions
        - @posts.each do |post|
            li.post #{post.caption} on #{post.pubdate}
            a href="/preview/#{post.id}" Preview
    
    
    
@@preview
div class="admin"
    div id="preview"    
        img src="http://littledraw.co.uk/images/logo.jpg"
        img src="http://littledraw.co.uk/images/cross.png"
        h1 = @posts.caption
        img src="http://littledraw.co.uk/images/cross.png"
        img src="/uploads/#{@posts.url}"
        img src="http://littledraw.co.uk/images/cross.png"
        div id="footer"

    div id="edit"
        h1 update
        form.post method="post" enctype='multipart/form-data'
            p select file
            input type='file' name='myfile' value='#{@posts.url}'
            br
            p caption
            textarea name='caption' = @posts.caption
        #input type='text' name='caption' value='#{@posts.caption}'
            br
            p date to be published
            input type='date' name='pubdate' value='#{@posts.pubdate}'
            br
            input type='submit' value='Update'
        
        br
        
        form.delete method="POST"
        input type="hidden" name="_method" value="DELETE"
        input type="submit" value="Delete"  title="Delete"
   
@@admin
div class="admin"
form.post action="/login" method="post"
    p Username:
    input type='text' name='username'
    p Password:
    input type='password' name='password'
    input type='submit' value='login'    
    