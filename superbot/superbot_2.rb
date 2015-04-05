#!/usr/bin/env ruby
 
require 'mumble-ruby'
require 'rubygems'
require 'ruby-mpd'
require 'thread'
require 'optparse'

require_relative 'musicdownload.rb'

# copy@paste from https://gist.github.com/erskingardner/1124645#file-string_ext-rb
class String
    def to_bool
        return true if self == true || self =~ (/(true|t|yes|y|1)$/i)
        return false if self == false || self.blank? || self =~ (/(false|f|no|n|0)$/i)
        raise ArgumentError.new("invalid value for Boolean: \"#{self}\"")
    end
end

class MumbleMPD
        attr_reader :run
        Cvolume =      0x01 #send message when volume change
        Cupdating_db = 0x02 #send message when database update
        Crandom =      0x04 #send message when random mode changed
        Csingle =      0x08 #send message when single mode changed
        Cxfade =       0x10 #send message when crossfading changed
        Cconsume =     0x20 #send message when consume-mode changed
        Crepeat =      0x40 #send message when repeat-mode changed
        Cstate =       0x80 #send message when state changes
        

    def initialize

        #Initialize default values
        #@settings[:chan_notify] = Cvolume | Cupdating_db | Crandom | Csingle | Cxfade | Cconsume | Crepeat | Cstate
        @priv_notify = {}

        @template_if_comment_enabled = "<b>Artist: </b>%s<br />"\
                            + "<b>Title: </b>%s<br />" \
                            + "<b>Album: </b>%s<br /><br />" \
                            + "<b>Write %shelp to me, to get a list of my commands!"
        @template_if_comment_disabled = "<b>Artist: </b>DISABLED<br />"\
                            + "<b>Title: </b>DISABLED<br />" \
                            + "<b>Album: </b>DISABLED<br /><br />" \
                            + "<b>Write %shelp to me, to get a list of my commands!"


        #Read config file if available 
        begin
            require_relative 'superbot_conf.rb'
            ext_config()
        rescue
            puts "Config could not be loaded! Using default configuration."
        end

        OptionParser.new do |opts|
            opts.banner = "Usage: superbot_2.rb [options]"
            
            opts.on("--mumblehost=", "IP or Hostname of mumbleserver") do |v|
                @settings[:mumbleserver_host] = v
            end
            
            opts.on("--mumbleport=", "Port of Mumbleserver") do |v|
                @settings[:mumbleserver_port] = v
            end
            
            opts.on("--name=", "The Bot's Nickname") do |v|
                @settings[:mumbleserver_username] = v
            end
            
            opts.on("--userpass=", "Password if required for user") do |v|
                @settings[:mumbleserver_userpassword] = v
            end
            
            opts.on("--targetchannel=", "Channel to be joined after connect") do |v|
                @settings[:mumbleserver_targetchannel] = v
            end
            
            opts.on("--bitrate=", "Desired audio bitrate") do |v|
                @settings[:quality_bitrate] = v.to_i
            end
            
            opts.on("--fifo=", "Path to fifo") do |v|
                @settings[:mpd_fifopath] = v.to_s
            end
            
            opts.on("--mpdhost=", "MPD's Hostname") do |v|
                @settings[:mpd_host] = v
            end
            
            opts.on("--mpdport=", "MPD's Port") do |v|
                @settings[:mpd_port] = v.to_i
            end
            
            opts.on("--controllable=", "true if bot should be controlled from chatcommands") do |v|
                @settings[:controllable] = v.to_bool
            end
            
            opts.on("--certdir=", "path to cert") do |v|
                @settings[:certdirectory] = v
            end
        end.parse! 
        @configured_settings = @settings.clone 
    end
    
    def init_settings
        @mpd = nil
        @cli = nil

        @mpd = MPD.new @settings[:mpd_host], @settings[:mpd_port].to_i

        @cli = Mumble::Client.new(@settings[:mumbleserver_host], @settings[:mumbleserver_port]) do |conf|
            conf.username = @settings[:mumbleserver_username]
            conf.password = @settings[:mumbleserver_userpassword]
            conf.bitrate = @settings[:quality_bitrate].to_i
            conf.vbr_rate = @settings[:use_vbr]
            conf.ssl_cert_opts[:cert_dir] = File.expand_path(@settings[:certdirectory])
        end
    end
    
    def mumble_start

        @cli.connect
         while not @cli.connected? do
            sleep(0.5)
            puts "Connecting to the server is still ongoing." if @settings[:debug]
        end
        begin
            @cli.join_channel(@settings[:mumbleserver_targetchannel])
        rescue
            puts "[joincannel]#{$1} Can't join #{@settings[:mumbleserver_targetchannel]}!" if @settings[:debug]
        end

        begin
            Thread.kill(@duckthread)
        rescue
            puts "[killduckthread] can't kill because #{$1}" if @settings[:debug]
        end
        
        #Start duckthread
        @duckthread = Thread.new do
            while (true == true)
                while (@cli.player.volume != 100)
                    if ((Time.now - @lastaudio) < 0.1) then 
                        @cli.player.volume = 20
                    else
                        @cli.player.volume += 2 if @cli.player.volume < 100
                    end
                    sleep 0.02
                end
                Thread.stop
            end
        end
        

        begin
            @cli.set_comment("")
            @settings[:set_comment_available] = true
        rescue NoMethodError
            puts "[displaycomment]#{$!}" if @settings[:debug]
            @settings[:set_comment_available] = false 
        end
        
        @cli.on_user_state do |msg|
            handle_user_state_changes(msg)
        end

        @cli.on_text_message do |msg|
            handle_text_message(msg)
        end
        
        
        @cli.on_udp_tunnel do |udp|
            @lastaudio = Time.now
            @cli.player.volume = 20 if @settings[:ducking] == true
            @duckthread.run if @duckthread.stop?
        end
                
        @lastaudio = Time.now
        
        @run = true
        main = Thread.new do
            while (@run == true)
                sleep 1
                current = @mpd.current_song if @mpd.connected?
                if not current.nil? #Would crash if playlist was empty.
                    lastcurrent = current if lastcurrent.nil? 
                    if lastcurrent.title != current.title 
                        if @settings[:use_comment_for_status_display] == true && @settings[:set_comment_available] == true
                            begin
                                if File.exist?("../music/download/"+current.title.to_s+".jpg")
                                    image = @cli.get_imgmsg("../music/download/"+current.title+".jpg")
                                else
                                    image = @settings[:logo]
                                end
                                output = "<br />" + @template_if_comment_enabled % [current.artist, current.title, current.album,@settings[:controlstring]]
                                @cli.set_comment(image+output)
                            rescue NoMethodError
                                if @settings[:debug]
                                    puts "#{$!}"
                                end
                            end
                        else
                            if current.artist.nil? && current.title.nil? && current.album.nil?
                                @cli.text_channel(@cli.me.current_channel, "#{current.file}") if @settings[:chan_notify] && 0x80
                            else
                                @cli.text_channel(@cli.me.current_channel, "#{current.artist} - #{current.title} (#{current.album})") if (@settings[:chan_notify] && 0x80) != 0
                            end
                        end
                        lastcurrent = current
                        puts "[displayinfo] update" if @settings[:debug]
                    end
                end
            end
        end
        initialize_mpdcallbacks
        @cli.player.stream_named_pipe(@settings[:mpd_fifopath]) 
        @mpd.connect true #without true bot does not @cli.text_channel messages other than for !status

    end
    
    def initialize_mpdcallbacks
        @mpd.on :volume do |volume|
            sendmessage("Volume was set to: #{volume}%." , 0x01)
        end
        
        @mpd.on :error do |error|
            @cli.text_channel(@cli.me.current_channel, "<span style='color:red;font-weight:bold;>An error occured: #{error}.</span>") 
        end
        
        @mpd.on :updating_db do |jobid|
            @cli.text_channel(@cli.me.current_channel, "I am running a database update just now ... new songs :)<br />My job id is: #{jobid}.") if (@settings[:chan_notify] & 0x02) != 0
        end
        
        @mpd.on :random do |random|
            if random
                random = "On"
            else
                random = "Off"
            end
            @cli.text_channel(@cli.me.current_channel, "Random mode is now: #{random}.") if (@settings[:chan_notify] & 0x04) != 0
        end
        
        @mpd.on :state  do |state|
            if @settings[:chan_notify] & 0x80 != 0 then
                @cli.text_channel(@cli.me.current_channel, "Music paused.") if  state == :pause 
                @cli.text_channel(@cli.me.current_channel, "Music stopped.") if state == :stop  
                @cli.text_channel(@cli.me.current_channel, "Music start playing.") if state == :play 
            end
        end
        
        @mpd.on :single do |single|
            if single
                single = "On"
            else
                single = "Off"
            end
            @cli.text_channel(@cli.me.current_channel, "Single mode is now: #{single}.") if (@settings[:chan_notify] & 0x08) != 0
        end
        
        @mpd.on :consume do |consume|
            if consume
                consume = "On"
            else
                consume = "Off"
            end

            @cli.text_channel(@cli.me.current_channel, "Consume mode is now: #{consume}.") if (@settings[:chan_notify] & 0x10) != 0
        end
        
        @mpd.on :xfade do |xfade|
            if xfade.to_i == 0
                xfade = "Off"
                @cli.text_channel(@cli.me.current_channel, "Crossfade is now: #{xfade}.") if (@settings[:chan_notify] & 0x20) != 0
            else
                @cli.text_channel(@cli.me.current_channel, "Crossfade time (in seconds) is now: #{xfade}.") if (@settings[:chan_notify] & 0x20) != 0 
            end
        end
        
        @mpd.on :repeat do |repeat|
            if repeat
                repeat = "On"
            else
                repeat = "Off"
            end
            @cli.text_channel(@cli.me.current_channel, "Repeat mode is now: #{repeat}.") if (@settings[:chan_notify] & 0x40) != 0
        end
        
        @mpd.on :song do |current|
            if not current.nil? #Would crash if playlist was empty.
                if @settings[:use_comment_for_status_display] == true && @settings[:set_comment_available] == true
                    begin
                        if File.exist?("../music/download/"+current.title.to_s+".jpg")
                            image = @cli.get_imgmsg("../music/download/"+current.title+".jpg")
                        else
                            image = @settings[:logo]
                        end
                        output = "<br />" + @template_if_comment_enabled % [current.artist, current.title, current.album,@settings[:controlstring]]
                        @cli.set_comment(image+output)
                    rescue NoMethodError
                        if @settings[:debug]
                            puts "#{$!}"
                        end
                    end
                else
                    if current.artist.nil? && current.title.nil? && current.album.nil?
                        @cli.text_channel(@cli.me.current_channel, "#{current.file}") if @settings[:chan_notify] && 0x80
                    else
                        @cli.text_channel(@cli.me.current_channel, "#{current.artist} - #{current.title} (#{current.album})") if (@settings[:chan_notify] && 0x80) != 0
                    end
                end
            end
        end
    end
    
    def handle_user_state_changes(msg)
        #msg.actor = session_id of user who did something on someone, if self done, both is the same.
        #msg.session = session_id of the target

        msg_target = @cli.users[msg.session]
        
        if msg_target.user_id.nil?
            msg_userid = -1
            sender_is_registered = false
        else
            msg_userid = msg_target.user_id
            sender_is_registered = true
        end
                        
        if @cli.me.current_channel.channel_id == msg_target.channel_id
            if (@settings[:stop_on_unregistered_users] == true && sender_is_registered == false)
                @mpd.stop
                @cli.text_channel(@cli.me.current_channel, "<span style='color:red;'>An unregistered user currently joined or is acting in our channel. I stopped the music.</span>")
            end
        end
    end
    
    def handle_text_message(msg)
        if msg.actor.nil?
            ##next #Ignore text messages from the server
            return
        end
    
        #Some of the next two information we may need later...
        msg_sender = @cli.users[msg.actor]
        
        #This is hacky because mumble uses -1 for user_id of unregistered users,
        # while mumble-ruby seems to just omit the value for unregistered users.
        # With this hacky thing commands from SuperUser are also being ignored.
        if msg_sender.user_id.nil?
            msg_userid = -1
            sender_is_registered = false
        else
            msg_userid = msg_sender.user_id
            sender_is_registered = true
        end

        # generating help message.
        # each command adds his own help
        help ="<br />"    # start with empty help
        # the help command should be the last command in this function
        cc = @settings[:controlstring]
        
        help += "<b>superpassword+restart</b> will restart the bot.<br />"
        if msg.message == @superpassword+"restart"
            @settings = @configured_settings.clone
            @cli.text_channel(@cli.me.current_channel,@superanswer);
            @run = false
            @cli.disconnect
        end

        help += "<b>superpassword+reset</b> will reset variables to start values.<br />"
        if msg.message == @superpassword+"reset"
            @settings = @configured_settings.clone
            @cli.text_channel(@cli.me.current_channel,@superanswer);
        end

        if @settings[:listen_to_registered_users_only] == true
            if sender_is_registered == false
                if @settings[:debug]
                    puts "Debug: Not listening because @settings[:listen_to_registered_users_only] is true and sender is unregistered."
                end
                
                #next
                return
            end
        end    
        
        #Check whether message is a private one or was sent to the channel.
        # Private message looks like this:   <Hashie::Mash actor=54 message="#help" session=[119]>
        # Channel message:                   <Hashie::Mash actor=54 channel_id=[530] message="#help">
        # Channel messages don't have a session, so skip them
        if not msg.session
            if @settings[:listen_to_private_message_only] == true
                if @settings[:debug]
                    puts "Debug: Not listening because @settings[:listen_to_private_message_only] is true and message was sent to channel."
                end
                #next
                return
            end
        end
        if @settings[:controllable] == true
            if msg.message.start_with?("#{@settings[:controlstring]}") && msg.message.length >@settings[:controlstring].length #Check whether we have a command after the controlstring.
                message = msg.message.split(@settings[:controlstring])[1] #Remove@settings[:controlstring]

                help += "<b>#{cc}http-link</b> will try to get some music from link.<br />"
                if message.start_with?("<a href=") then
                    link = msg.message[msg.message.index('>') + 1 .. -1]
                    link = link[0..link.index('<')-1]
                    workingdownload = Thread.new {
                        #local variables for this thread!
                        actor = msg.actor
                        md = MusicDownload.new
                        @cli.text_user(actor, "inspecting link: " + link + "...")
                        md.get_song link
                        #@cli.text_user(msg.actor, md.songs.to_s)
                        if ( md.songs > 0 ) then
                            @mpd.update("download") 
                            @cli.text_user(actor, "Waiting for database update complete...")
                            
                            #Caution! following command needs patched ruby-mpd!
                            @mpd.idle("update")
                            # find this lines in ruby-mpd/plugins/information.rb (actual 47-49)
                            # def idle(*masks)
                            #  send_command(:idle, *masks)
                            # end
                            # and uncomment it there, then build gem new.
                                
                            @cli.text_user(actor, "Update done.")
                            while md.songs > 0 
                                song = md.songname
                                @cli.text_user(actor, song)
                                @mpd.add("download/"+song)
                                sleep 0.5
                            end
                        else
                            @cli.text_user(actor, "The link contains nothing interesting for me.")
                        end
                    }
                end

                help += "<b>#{cc}settings</b> display current settings.<br />"
                if message == 'settings' 
                    out = "<table>"
                    @settings.each do |key, value|
                        out += "<tr><td>#{key}</td><td>#{value}</td></tr>"
                    end
                    out += "</table>"
                    @cli.text_user(msg.actor, out)    
                end

                help += "<b>#{cc}set <i>variable=value</i></b> Set variable to value.<br />"
                if message.split[0] == 'set' 
                    if !@settings[:need_binding] || @settings[:boundto]==msg_userid
                        setting = message.split('=',2)
                        @settings[setting[0].split[1].to_sym] = setting[1] if setting[0].split[1] != nil
                    end
                end
                
                   help += "<b>#{cc}bind</b> Bind Bot to a user. (some functions will only do if bot is bound).<br />"
                if message == 'bind'
                    @settings[:boundto] = msg_userid if @settings[:boundto] == "nobody"
                end        
                
                help += "<b>#{cc}unbind</b> Unbind Bot.<br />"
                if message == 'unbind'
                    @settings[:boundto] = "nobody" if @settings[:boundto] == msg_userid
                end
                
                help += "<b>#{cc}reset</b> Reset variables to default value. Needs binding!<br />"
                if message == 'reset' 
                    @settings = @configured_settings.clone if @settings[:boundto] == msg_userid
                end
                
                help += "<b>#{cc}restart</b> Restart Bot. Needs binding.<br />"
                if message == 'restart'
                    if @settings[:boundto] == msg_userid
                        @run=false
                        @cli.disconnect
                    end
                end
            
                help += "<b>#{cc}seek <i>value</i>|<i>+/-value</i></b> Seek to an absolute position (in seconds). Use +value or -value to seek relative to the current position.<br />"
                if message.match(/^seek [+-]?[0-9]{1,3}$/)
                    seekto = message.match(/^seek ([+-]?[0-9]{1,3})$/)[1]
                    @mpd.seek seekto
                    status = @mpd.status

                    #Code from http://stackoverflow.com/questions/19595840/rails-get-the-time-difference-in-hours-minutes-and-seconds
                    now_mm, now_ss = status[:time][0].divmod(60) #Minutes and seconds of current time within the song.
                    now_hh, now_mm = now_mm.divmod(60)
                    total_mm, total_ss = status[:time][1].divmod(60) #Minutes and seconds of total time of the song.
                    total_hh, total_mm = total_mm.divmod(60)
                    
                    now = "%02d:%02d:%02d" % [now_hh, now_mm, now_ss]
                    total = "%02d:%02d:%02d" % [total_hh, total_mm, total_ss]
                    
                    @cli.text_channel(@cli.me.current_channel, "Seeked to position #{now}/#{total}.")
                end
                
                help += "<b>#{cc}crossfade <i>value</i></b> Set Crossfade to value seconds, 0 to disable this.<br />"
                if message.match(/^crossfade [0-9]{1,3}$/)
                    secs = message.match(/^crossfade ([0-9]{1,3})$/)[1].to_i
                    @mpd.crossfade = secs
                end
                
                help += "<b>#{cc}ch</b> Bot jump in your channel.<br />"
                if message == 'ch'
                    channeluserisin = msg_sender.channel_id

                    if @cli.me.current_channel.channel_id.to_i == channeluserisin.to_i
                        @cli.text_user(msg.actor, "Hey superbrain, I am already in your channel :)")
                    else
                        @cli.text_channel(@cli.me.current_channel, "Hey, \"#{@cli.users[msg.actor].name}\" asked me to make some music, going now. Bye :)")
                        @cli.join_channel(channeluserisin)
                    end
                end
                
                help += "<b>#{cc}debug</b> Probe command.<br />"
                if message == 'debug'
                    @cli.text_user(msg.actor, "<span style='color:red;font-size:30px;'>Stay out of here :)</span>")
                end
                
                help += "<b>#{cc}next</b> Play next title.<br />"
                if message == 'next'
                    @mpd.next
                end
                
                help += "<b>#{cc}prev</b> Play previous title.<br />"
                if message == 'prev'
                    @mpd.previous
                end
                
                help += "<b>#{cc}gotobed</b> Bot sleeps in less then 1 second :).<br />"
                if message == 'gotobed'
                    @cli.join_channel(@settings[:mumbleserver_targetchannel])
                    @mpd.pause = true
                    @cli.me.deafen true
                    begin
                        Thread.kill(@following)
                        @alreadyfollowing = false
                    rescue
                    end
                end
                
                help += "<b>#{cc}wakeup</b> Bot is under adrenalin again.<br />"
                if message == 'wakeup'
                    @mpd.pause = false
                    @cli.me.deafen false
                    @cli.me.mute false
                end
                
                help += "<b>#{cc}follow</b> Bot will follow you.<br />"
                if message == 'follow'
                        if @alreadyfollowing == true
                            @cli.text_user(msg.actor, "I am already following someone! But from now on I will follow you, master.")
                            @alreadyfollowing = false
                            begin
                                Thread.kill(@following)
                                @alreadyfollowing = false
                            rescue TypeError
                                if @settings[:debug]
                                    puts "#{$!}"
                                end
                            end
                        else
                        @cli.text_user(msg.actor, "I am following your steps, master.")
                        end
                        @follow = true
                        @alreadyfollowing = true
                        currentuser = msg.actor
                        @following = Thread.new {
                            begin
                                while @follow == true do
                                    @cli.join_channel(@cli.users[currentuser].channel_id) if (@cli.me.current_channel != @cli.users[currentuser].channel_id)
                                    sleep 0.5
                                end
                            rescue
                                if @settings[:debug]
                                    puts "#{$!}"
                                end
                                @alreadyfollowing = false
                                Thread.kill(@following)
                            end
                        }
                end
                
                help += "<b>#{cc}unfollow</b> Bot transforms from a dog into a lazy cat :).<br />"
                if message == 'unfollow'
                    if @follow == false
                        @cli.text_user(msg.actor, "I am not following anyone.")
                    else
                        @cli.text_user(msg.actor, "I will stop following.")
                        @follow = false
                        @alreadyfollowing = false
                        begin
                            Thread.kill(@following)
                            @alreadyfollowing = false
                        rescue TypeError
                            if @settings[:debug]
                                puts "#{$!}"
                            end
                            @cli.text_user(msg.actor, "#{@controlstring}follow hasn't been executed yet.")
                        end
                    end
                end
                
                help += "<b>#{cc}stick</b> Jail Bot into channel.<br />"
                if message == 'stick'
                    if @alreadysticky == true
                        @cli.text_user(msg.actor, "I'm already sticked! Resetting...")
                        @alreadysticky = false
                        begin
                            Thread.kill(@sticked)
                            @alreadysticky = false
                        rescue TypeError
                            if @settings[:debug]
                                puts "#{$!}"
                            end
                        end
                    else
                        @cli.text_user(msg.actor, "I am now sticked to this channel.")
                    end
                    @sticky = true
                    @alreadysticky = true
                    channeluserisin = @cli.users[msg.actor].channel_id
                    @sticked = Thread.new {
                        while @sticky == true do
                            if @cli.me.current_channel == channeluserisin
                                sleep(1)
                            else
                                begin
                                    @cli.join_channel(channeluserisin)
                                    sleep(1)
                                rescue
                                    @alreadysticky = false
                                    @cli.join_channel(@settings[:mumbleserver_targetchannel])
                                    Thread.kill(@sticked)
                                    if @settings[:debug]
                                        puts "#{$!}"
                                    end
                                end
                            end
                        end
                    }
                end
                
                help += "<b>#{cc}unstick</b> Free Bot.<br />"
                if message == 'unstick'
                    if @sticky == false
                        @cli.text_user(msg.actor, "I am currently not sticked to a channel.")
                    else
                        @cli.text_user(msg.actor, "I am not sticked anymore")
                        @sticky = false
                        @alreadysticky = false
                        begin
                            Thread.kill(@sticked)
                        rescue TypeError
                            if @settings[:debug]
                                puts "#{$!}"
                            end
                        end
                    end
                end
                
                help += "<b>#{cc}displayinfo</b> Toggles Infodisplay from comment to message and back.<br />"
                if message == 'displayinfo'
                    begin
                        if @settings[:use_comment_for_status_display] == true
                            @settings[:use_comment_for_status_display] = false
                            @cli.text_user(msg.actor, "Output is now \"Channel\"")
                            @cli.set_comment(@template_if_comment_disabled % [@controlstring])
                        else
                            @settings[:use_comment_for_status_display] = true
                            @cli.text_user(msg.actor, "Output is now \"Comment\"")
                            @cli.set_comment(@template_if_comment_enabled)
                        end
                    rescue NoMethodError
                        if @settings[:debug]
                            puts "#{$!}"
                        end
                    end
                end
                
                help += "<b>#{cc}v</b> Info about current playback volume.<br />"
                if message == 'v'
                    volume = @mpd.volume
                    @cli.text_user(msg.actor, "Current volume is #{volume}%.")
                end    
                
                help += "<b>#{cc}v <i>value</i></b> Set playback volume to value.<br />"
                if message.match(/^v [0-9]{1,3}$/)
                    volume = message.match(/^v ([0-9]{1,3})$/)[1].to_i
                    
                    if (volume >=0 ) && (volume <= 100)
                        @mpd.volume = volume
                    else
                        @cli.text_user(msg.actor, "Volume can be within a range of 0 to 100")
                    end
                end
                
                help += "<b>#{cc}v++++</b> turns volume 20% up.<br />"
                help += "<b>#{cc}v-</b> turns volume 5% down.<br />"
                if message.match(/^v[-]+$/)
                    multi = message.match(/^v([-]+)$/)[1].scan(/\-/).length
                    volume = ((@mpd.volume).to_i - 5 * multi)
                    if volume < 0
                        @cli.text_channel(@cli.me.current_channel, "Volume can't be set to &lt; 0.")
                        volume = 0
                    end
                    
                    @mpd.volume = volume
                end
                
                help += "<b>#{cc}clear</b> Clear playqueue.<br />"
                if message == 'clear'
                    @mpd.clear
                    @cli.text_user(msg.actor, "The playqueue was cleared.")
                end
                
                help += "<b>#{cc}random</b> toggle random mode.<br />"
                if message == 'random'
                    @mpd.random = !@mpd.random?
                end
                
                help += "<b>#{cc}repeat</b> toggle repeat mode.<br />"
                if message == 'repeat'
                    @mpd.repeat = !@mpd.repeat?
                end
                
                help += "<b>#{cc}single</b> toggle single mode.<br />"
                if message == 'single'
                    @mpd.single = !@mpd.single?
                end
                
                help += "<b>#{cc}consume</b> toggle consume mode.<br />"
                if message == 'consume'
                    @mpd.consume = !@mpd.consume?
                end
                    
                help += "<b>#{cc}pp</b> toggle pause/play.<br />"
                if message == 'pp'
                    @mpd.pause = !@mpd.paused?
                end
                
                help += "<b>#{cc}ducking</b> toggle voice ducking on/off.<br />"
                if message == 'ducking' 
                   @settings[:ducking] = !@settings[:ducking]
                   if @settings[:ducking] == false 
                        @cli.text_user(msg.actor, "Music ducking is off.")
                    else
                        @cli.text_user(msg.actor, "Music ducking is on.")
                    end
                end
                
                help += "<b>#{cc}stop</b> Stop playing.<br />"
                if message == 'stop'
                    @mpd.stop
                end
                
                help += "<b>#{cc}play</b> Start playing.<br />"
                if message == 'play'
                    @mpd.play
                    @cli.me.deafen false
                    @cli.me.mute false
                end
                
                help += "<b>#{cc}songlist</b> Display songlist.<br />"
                if message == 'songlist'
                    block = 0
                    out = ""
                    @mpd.songs.each do |song|
                        if block >= 50
                            @cli.text_user(msg.actor, out)
                            out = ""
                            block = 0
                        end
                        out += "<br/>" + song.file
                        block += 1
                    end
                    @cli.text_user(msg.actor, out)    
                end
                
                help += "<b>#{cc}stats</b> Display player stats.<br />"
                if message == 'stats'
                    out = "<table>"
                    @mpd.stats.each do |key, value|
                        out += "<tr><td>#{key}</td><td>#{value}</td></tr>"
                    end
                    out += "</table>"
                    @cli.text_user(msg.actor, out)    
                end
                
                help += "<b>#{cc}queue</b> Display actual queue.<br />"
                if message == 'queue'
                    text_out ="<br/>"
                    @mpd.queue.each do |song|
                        text_out += "#{song.title}<br/>" 
                    end
                    @cli.text_user(msg.actor, text_out)
                end
                
                help += "<b>#{cc}where song</b> find song by name and display matches.<br />"
                if ( message[0,5] == 'where' ) 
                    search = message.gsub("where", "").lstrip
                    text_out = "you should search not nothing!"
                    if search != ""
                        text_out ="found:<br/>"
                        @mpd.where(any: "#{search}").each do |song|
                            text_out += "#{song.file}<br/>" 
                        end
                    end
                    @cli.text_user(msg.actor, text_out)
                end
                
                help += "<b>#{cc}add song</b> find song by name and display matches.<br />"
                if ( message[0,3] == 'add' ) 
                    search = message.gsub("add", "").lstrip
                    text_out = "nothing found/added!"
                    if search != ""
                        text_out ="added:<br/>"
                        @mpd.where(any: "#{search}").each do |song|
                            text_out += "add #{song.file}<br/>" 
                            @mpd.add(song)
                        end
                    end
                    @cli.text_user(msg.actor, text_out)
                end
                
                help += "<b>#{cc}playlists</b> Display playlists.<br />"
                if message == 'playlists'
                    text_out = ""
                    counter = 0
                    @mpd.playlists.each do |playlist|
                        text_out = text_out + "#{counter} - #{playlist.name}<br/>"
                        counter = counter + 1
                    end
                    
                    @cli.text_user(msg.actor, "I know the following playlists:<br />#{text_out}")
                end
                
                help += "<b>#{cc}playlist <i>value</i></b> load playlist.<br />"
                if message.match(/^playlist [0-9]{1,3}.*$/)
                    playlist_id = message.match(/^playlist ([0-9]{1,3})$/)[1].to_i
                    
                    begin
                        playlist = @mpd.playlists[playlist_id]
                        @mpd.clear
                        playlist.load
                        @mpd.play
                        @cli.text_user(msg.actor, "The playlist \"#{playlist.name}\" was loaded and starts now.")
                    rescue
                        @cli.text_user(msg.actor, "Sorry, the given playlist id does not exist.")
                    end
                end

                help += "<b>#{cc}status</b> Display current status.<br />"
                if message == 'status' 
                    out = "<table>"
                    @mpd.status.each do |key, value|
                        out += "<tr><td>#{key}</td><td>#{value}</td></tr>"
                    end
                    out += "</table>"
                    @cli.text_user(msg.actor, out)    
                end
                
                help += "<b>#{cc}file</b> Display filename.<br />"
                if message == 'file'
                    current = @mpd.current_song
                    @cli.text_user(msg.actor, "Filename of currently played song:<br />#{current.file}</span>") if not current.nil?
                end
                
                help += "<b>#{cc}song</b> Display songname.<br />"
                if message == 'song'
                    current = @mpd.current_song
                    if not current.nil? #Would crash if playlist was empty.
                        @cli.text_user(msg.actor, "#{current.artist} - #{current.title} (#{current.album})")
                    else
                        @cli.text_user(msg.actor, "No song is played currently.")
                    end
                end
                
                @priv_notify[msg.actor] = 0 if @priv_notify[msg.actor].nil?
                if message[2] == '#'
                    message.split.each do |command|
                        case command
                        when "#volume"
                            add = Cvolume
                        when "#update"
                            add = Cupdating_db
                        when "#random"
                            add = Crandom
                        when "#single"
                            add = Csingle
                        when "#xfade"
                            add = Cxfade
                        when "#consume"
                            add = Cconsume
                        when "#repeat"
                            add = Crepeat
                        when "#state"
                            add = Cstate
                        else
                            add = 0
                        end
                        @priv_notify[msg.actor] |= add if message[0] == '+' 
                        @priv_notify[msg.actor] &= ~add if message[0] == '-' 
                    end
                end
                if message == '*' && !@priv_notify[msg.actor].nil?
                    send = "You listen to following MPD-Channels:"
                    send += " #volume" if (@priv_notify[msg.actor] & Cvolume) > 0
                    send += " #update" if (@priv_notify[msg.actor] & Cupdating_db) > 0
                    send += " #random" if (@priv_notify[msg.actor] & Crandom) > 0
                    send += " #single" if (@priv_notify[msg.actor] & Csingle) > 0
                    send += " #xfade" if (@priv_notify[msg.actor] & Cxfade) > 0
                    send += " #repeat" if (@priv_notify[msg.actor] & Crepeat) > 0
                    send += " #state" if (@priv_notify[msg.actor] & Cstate) > 0
                    send += "."
                    @cli.text_user(msg.actor, send)
                end

                help += "<b>#{cc}help</b> Get this list :).<br />"
                if message == 'help'
                    @cli.text_user(msg.actor, help)
                end
           end
        end
    end
    
    def sendmessage (message, messagetype)
        @cli.text_channel(@cli.me.current_channel, message) if ( @settings[:chan_notify] & messagetype) != 0
        if !@priv_notify.nil?
            @priv_notify.each do |user, notify| 
                begin
                    @cli.text_user(user,message) if ( notify & messagetype) != 0
                rescue
                
                end
            end
        end
    end
end

puts "Superbot_2 is starting..." 
client = MumbleMPD.new
while true == true
    client.init_settings
    client.mumble_start    
    sleep 3
    while client.run == true
        sleep 0.5
    end
    sleep 0.5
end

