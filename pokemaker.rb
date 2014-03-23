#!/usr/bin/env ruby

require "rubygems"
require "sinatra"

require "dm-core"
require "dm-migrations"
require "dm-types"
require "dm-serializer"
require "extlib"
require "digest/sha1"
require "haml"
require "sass"
require "base64"
require "permutation"
require "rio"

require "ostruct"

require "./lib/gtscrypt.rb"
require "./lib/models.rb"
require "./lib/poketext.rb"
require "./lib/pokedex.rb"

INITIAL_USER_ID=123456
INITIAL_ADMIN_USER="admin"
INITIAL_ADMIN_PASSWORD="pokemaker"

DataMapper.setup(:default, "sqlite:./pokegts.db")
DataMapper.setup(:pokedex, "sqlite:./pokedex.db")

set :port, 80
enable :sessions

DataMapper.auto_upgrade!

helpers do

	def pidgenhash(pid)
		return Digest::SHA1.hexdigest(pid)
	end

	def saverawpkmr(pkm,b64=false)
		pkm = Base64.decode64(pkm.gsub("-","+").gsub("_","/")) if b64 == true
		decrypt = GTSCrypt.new pkm
		data = decrypt.decrypt
		return data[4..data.size].to_s
	end

	def auth
		redirect "/trainer/login" if @trainer.nil?
	end

	def auth?
		return true unless @trainer.nil?
		return false
	end

end

before do
	if request.path_info =~ %r{/pokemondpds/}
		session[:pid] = params[:pid] unless params[:pid].nil?
		@trainer = Trainer.first_or_create(:tid=>session[:pid])
		if @trainer.monsters.empty?
			welpkm = @trainer.monsters.new
			welpkm.blob = Trainer.first(:name=>INITIAL_ADMIN_USER).monsters.first.blob
			welpkm.extra = Trainer.first(:name=>INITIAL_ADMIN_USER).monsters.first.extra
			welpkm.queue = true
			welpkm.save
		end
		halt pidgenhash(session[:pid])[0,32] unless params[:hash]
	end
	unless params[:t].nil?
		@trainer = Trainer.first(:tid=>params[:t]) if @trainer.nil?
	else
		@trainer = Trainer.first(:tid=>session[:pid])
	end
end

get "/system/initialize" do
	promo = User.first_or_create(:id=>1, :fbid => INITIAL_USER_ID, :name=>INITIAL_ADMIN_USER, :pass => INITIAL_ADMIN_PASSWORD)
	promo.save
	trainer = promo.trainers.first_or_create(:id=>1, :tid => INITIAL_USER_ID, :name=>INITIAL_ADMIN_USER, :pass => INITIAL_ADMIN_PASSWORD)
	trainer.reg = true
	trainer.save
	rio('pkm').files('*.pkm') do |data|
		pkm = "".force_encoding('UTF-8')
		monster = trainer.monsters.new
		data >> pkm
		pkm << open("./extra").read().force_encoding('UTF-8') if pkm.size == 236
		monster.blob = pkm
		monster.save
	end
	redirect "/"
end

get "/css/:css" do
	sass params[:css].to_sym
end

get "/" do
	haml :index
end

get '/new' do
	haml :newindex
end

get "/system/search/:model" do
	Kernel.const_get(params[:model].classify).all(:name.like=>"%#{params[:term]}%").to_json
end

get "/trainer/:t/profile" do
	@trainer = Trainer.first(:id=>params[:t])
	return haml :profile unless @trainer.name.nil?
	haml :fpupdate
end

get "/trainer/:t/profile/update" do
	auth
	haml :fpupdate
end

post "/trainer/:t/profile" do
	auth
	@trainer.name = params[:name]
	@trainer.pass = params[:pass] unless params[:pass].nil?
	@trainer.save
	redirect "/trainer/#{@trainer.id}/profile"
end

get "/trainer/:t/pokemon/:p" do
	@pkm = Trainer.first(:id=>params[:t]).monsters.first(:id=>params[:p])
	if @pkm.trainer.tid == session[:pid]
		haml :pokeedit
	else
		haml :pokemon
	end
end

get "/trainer/:t/pokemon/:p/delete" do
	auth
	@pkm = @trainer.monsters.first(:id=>params[:p])
	if @trainer.id == @pkm.trainer.id
		@pkm.destroy
	end
	redirect "/trainer/#{@trainer.id}/profile"
end

post "/system/pokemon/:p/ev" do
	auth
	monster = Monster.get(params[:p])
	halt unless @trainer.id == monster.trainer.id
	poke = monster.structure
	evs = poke.evs
	evs[params[:n].to_i] = params[:v].to_i unless params[:v].to_i > 255 or params[:v].to_i < 0
	poke.evs = evs
	monster.structure = poke
	monster.save
	total = 0
	evs.each do |ev|
		total += ev
	end
	total.to_s
end

post "/system/pokemon/:p/iv" do
	auth
	monster = Monster.get(params[:p])
	halt unless @trainer.id == monster.trainer.id
	poke = monster.structure
	ivs = poke.ivs
	ivs[params[:n].to_i] = params[:v].to_i unless params[:v].to_i > 31 or params[:v].to_i < 0
	poke.ivs = ivs
	monster.structure = poke
	monster.save
	total = 0
	ivs.each do |iv|
		total += iv
	end
	total.to_s
end

post "/system/pokemon/:p/move" do
	auth
	monster = Monster.get(params[:p])
	halt unless @trainer.id == monster.trainer.id
	poke = monster.structure
	moves = poke.moves
	moves[params[:n].to_i] = params[:v].to_i
	poke.moves = moves
	monster.structure = poke
	monster.save
end

post "/system/pokemon/:p/edit" do
	monster = Monster.get(params[:p])
	halt unless @trainer.id == monster.trainer.id
	poke = monster.structure
	begin
		m = poke.method(params[:m]+"=")
	rescue NameError
		halt "no such method called #{params[:m]}"
	end
	m.call(params[:v])
	monster.structure = poke
	monster.save
	"success"
end

get "/system/ui/auto/pokemon" do
	haml :pokenew
end

get "/test" do
	m = Monster.get(11)
	p = m.structure
	p.nickname=("Ame")
	m.structure = p
	m.save
end

get "/trainer/:t/pokemon/:p/send" do
	auth
	@pkm = @trainer.monsters.first(:id=>params[:p])
	redirect "/trainer/#{@trainer.id}/profile" if @pkm.nil?
	@pkm.queue = true
	@pkm.save
	redirect "/trainer/#{@pkm.trainer.id}/pokemon/#{@pkm.id}"
end

get "/trainer/:t/pokemon/:p/give/:n" do
	auth
	@pkm = @trainer.monsters.first(:id=>params[:p])
	halt unless @trainer.id == @pkm.trainer.id
	redirect "/trainer/#{@trainer.id}/profile" if @pkm.nil?
	@pkm.trainer = Trainer.first(:tid=>params[:n])
	@pkm.save
	redirect "/trainer/#{@pkm.trainer.id}/pokemon/#{@pkm.id}"
end

get "/trainer/login" do
	haml :flogin
end

get "/trainer/logout" do
	session[:pid] = nil
	redirect "/"
end

post "/trainer/login" do
	@trainer = Trainer.first(:tid=>params[:login])
	session[:pid] = @trainer.tid if @trainer.user.pass == params[:pass] unless @trainer.nil?
	redirect "/trainer/login" if session[:pid].nil?
	redirect "/trainer/#{@trainer.id}/profile"
end

get "/trainer/pokemon/upload" do
	haml :fpkmupload
end

post "/trainer/pokemon/upload" do
	auth
	monster = @trainer.monsters.new
	pkm = params[:file][:tempfile].read()
	pkm << open("./extra").read().force_encoding('UTF-8') if pkm.size == 236
	monster.blob = pkm
	monster.save
	redirect "/trainer/#{@trainer.id}/pokemon/#{monster.id}"
end

get "/pokemondpds/common/setProfile.asp" do
	return ("\x00"*8).to_s
end

get "/pokemondpds/worldexchange/info.asp" do
	return "\x01\x00"
end

get "/pokemondpds/worldexchange/result.asp" do
	data = "\x05\x00"
	if @trainer && @trainer.monsters && @trainer.monsters.first(:queue=>true)
		data = @trainer.monsters.first(:queue=>true).blobe
	end
	return data
end

get "/pokemondpds/worldexchange/get.asp" do
	return @trainer.monsters.first(:queue=>true).blobe unless @trainer.monsters.first(:queue=>true).nil?
end

get "/pokemondpds/worldexchange/delete.asp" do
	monster = @trainer && @trainer.monsters && @trainer.monsters.first(:queue=>true)
	if @trainer && monster
		monster.queue = false
		monster.save
	end
	return "\x01\x00"
end

get "/pokemondpds/worldexchange/post.asp" do
	pkm = params[:data]
	monster = @trainer.monsters.new
	monster.blobe = saverawpkmr(pkm,true)
	if @trainer.reg == false
		@trainer.tid = monster.structure.otid
		@trainer.name = monster.structure.trainer
		@trainer.reg = true
		@trainer.save
	end
	monster.queue = true
	monster.save
	return "\x01\x00"
end

get "/pokemondpds/worldexchange/post_finish.asp" do
	return "\x01\x00"
end
