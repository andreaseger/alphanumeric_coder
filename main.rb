require 'rubygems'
require 'sinatra'
require "sinatra/reloader" if development?
require 'ostruct'
require 'fastercsv'
require 'rack-flash'
require 'sinatra/redirect_with_flash'

require 'lib/db'

use Rack::Flash
enable :sessions

configure do
	Coder = OpenStruct.new(
	  :tempfile => ENV['TEMPFILE'] || 'codes.csv',
		:admin_password => ENV['ADMIN_PASSWORD'] || 'changeme',
		:admin_cookie_key => 'coder_admin',
		:admin_cookie_value => ENV['ADMIN_COOKIE_VALUE'] || '51d6d976913ace58'
	)
	ALPHABET = ('A'..'Z').to_a + ('0'..'9').to_a
end

helpers do
	def admin?
		request.cookies[Coder.admin_cookie_key] == Coder.admin_cookie_value
	end

	def auth
		redirect '/auth' unless admin?
	end
end

def generate(count)
  count.times do
    DB.sadd('codes', 10.times.map{ ALPHABET.choice }.join)
  end
end
def save_in_csv(per_row)
  row = []
  all = DB.smembers 'codes'
  FasterCSV.open(Coder.tempfile, "wb") do |csv|
    all.each do |c|
      row.push(c)
      if row.count == per_row
        csv << row
        row = []
      end
    end
    csv << row unless row == []
  end
end

layout :layout

get '/generate' do
  auth
  erb :generate
end

post '/generate' do
  auth
  count = params[:count]
  if count == ""
    redirect '/generate', :error => 'enter the count of new Codes to generate'
  elsif count =~ /^\d{1,8}$/
    DB.del('codes') unless params[:append]
    generate(params[:count].to_i)
    redirect '/', :notice => "#{DB.scard('codes')} Code generiert"
  else
    redirect '/generate', :error => 'only numbers allowed (max=8-digits)'
  end
end

get '/' do
  @count = DB.scard 'codes'
  flash[:error] = 'Not authenticated <a href="/auth">Login</a>' unless admin?
  erb :get_csv
end

get '/download' do
  auth
  per_row = params[:columns]
  if per_row == ""
    per_row = 10
  elsif per_row =~ /^\d{1,2}$/
    per_row = per_row.to_i
  else
    redirect '/', :error => 'only numbers allowed (max=99)'
  end
  save_in_csv(per_row)
  send_file(Coder.tempfile, :disposition => 'attachment', :filename => File.basename(Coder.tempfile))  
end

### auth
get '/auth' do
	erb :auth
end

post '/auth' do
  if params[:password] == Coder.admin_password
	  response.set_cookie(Coder.admin_cookie_key, Coder.admin_cookie_value) 
	  flash[:notice] = 'successfull logged in'
	else
	  flash[:error] = 'log in failed'
	end
	redirect '/'
end

enable :inline_templates

__END__

@@layout
<html xmlns="http://www.w3.org/1999/xhtml">
<head>
	<meta http-equiv="content-type" content="text/html; charset=utf-8" />
	<title>Code Generator</title>
	<link href="/main.css" rel="stylesheet" type="text/css" />
</head>
<body>
  <% unless flash[:error].nil? %><div id="flash_error"><%=flash[:error]%></div><% end %>
  <% unless flash[:notice].nil? %><div id="flash_notice"><%=flash[:notice]%></div><% end %>
  <ul id="nav">
    <li><a href="/">download codes</a></li>
    <li><a href="/generate">generate codes</a></li>
  </ul>
  <div id="content">
	  <%= yield %>
  </div>
</body>
</html>

@@ get_csv
<h2>Download</h2>
<p>
  <%=@count%> unique Codes in the DB<br />
  delete the existing codes and <a href="/generate">generate</a> new ones.
</p>
<% if admin? %>
  <% unless @count == 0 %>
    <p>
      Download will start shortly after you click the button
    </p>
    <form action="/download">
     	<input type="text" id="Columns" name="columns" />(defaults to 10)
	    <input type="submit" value="Create/Download CSV" />
    </form>
    <script type="text/javascript">document.forms[0].columns.focus()</script>
  <% end %>
<% else %>
  <a href="/auth">Login</a> to download the codes
<% end %>

@@ generate
<head>
<script src="gen_validatorv4.js" type="text/javascript"></script>
</head>
<h2>Generate Codes</h2>
<p>This can take a few minutes</p>
<form action="/generate" method="post" id="generater_form">
  <p>
    <label name=count>Count</label>
	  <input type="text" name="count"/>
	</p>
  <p>
    <input type="checkbox" name="append">Append new Codes?</input>
  </p>
	<input type="submit" value="Generate" />
</form>
<script type="text/javascript">document.forms[0].count.focus()</script>


@@ auth
<h2>Login</h2>
<form action="/auth" method="post">
	<input type="password" name="password" />
	<input type="submit" value="Login" />
</form>
<script type="text/javascript">document.forms[0].password.focus()</script>
