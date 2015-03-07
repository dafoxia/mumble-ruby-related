def ext_config()
	puts "Config loaded!"

    
    #This template must always contain four %s strings.
	@template_if_comment_enabled = "<b>Artist: </b>%s<br />"\
					+ "<b>Title: </b>%s<br />" \
					+ "<b>Album: </b>%s<br /><br />" \
					+ "<b>Write %shelp to me, to get a list of my commands!"
	
	#This template must always contain one %s string.
	@template_if_comment_disabled = "<b>Artist: </b>DISABLED<br />"\
					+ "<b>Title: </b>DISABLED<br />" \
					+ "<b>Album: </b>DISABLED<br /><br />" \
					+ "<b>Write %shelp to me, to get a list of my commands!"
    
    
    # ------------------------------------------------------------------------------------------------------------------------------------------- #
    # superbot.rb configuration                                                                                                                   #
    # ------------------------------------------------------------------------------------------------------------------------------------------- #
    # (will not be needed and used with superbot_2.rb, still leaving here because compatibility)                                                  #
    # You should delete this section or comment it out so you can not be confused longer because of duplicate settings when you use superbot_2.rb #
    # ------------------------------------------------------------------------------------------------------------------------------------------- #
    
	@controlstring = "." 				#Change it if you want to use another starting string/symbol for the commands.
	@debug = true					#Whether debug mode is on or off.
	@use_vbr = 1 					#Default for mumble-ruby is 0 in order to use cbr, set to 1 to use vbr.
	@listen_to_private_message_only = true 		#Wheter the bot should only listen to private messages.
	@listen_to_registered_users_only = true 	#Whether the bot should only react to commands from registered users.
	@stop_on_unregistered_users = true 	        #Whether the bot should stop playing music if a unregistered user joins the channel.
	@use_comment_for_status_display = false 	#Whether to use comment to display song info; false = send to channel, true = comment.

    # End of superbot.rb configuation------------------------------------------------------------------------------------------------------------ #

    # ------------------------------------------------------------------------------------------------------------------------------------------- #
    # superbot_2.rb configuration                                                                                                                 #
    # ------------------------------------------------------------------------------------------------------------------------------------------- #
    # (will not be needed and used with superbot.rb.                                                                                              #
    # You should delete this section or comment it out so you can not be confused longer because of duplicate settings when you use superbot.rb   #
    # ------------------------------------------------------------------------------------------------------------------------------------------- #
	
    @settings = {   version: 2.0, 
                    # if ducking true bot will lower volume when other's speak
                    ducking: false, 
                    # see superbot_2.rb about chan_notify variable
                    chan_notify: 0x0000, 
                    controlstring: ".", 
                    # if you want some debug info on terminal
                    debug: false, 
                    listen_to_private_messsage_only: true, 
                    listen_to_registert_users_only: true, 
                    # set to 0 if you want a constant bitrate setting
                    use_vbr: 1, 
                    # set bitrate to bitspersecond (bps) [not kbit!]
                    quality_bitrate: 72000,
                    # bot will stop when a unregisterd user join channel if set to true
                    stop_on_unregistered_users: true,
                    # use mumble comment for status display (need a patched mumble-ruby) - see for dafoxia in github
                    use_comment_for_status_display: true,
                    # comment_aviable will be overwritten by bot if capability for comments is in mumble-ruby
                    set_comment_available: false,
                    # begin mumble server config
                    mumbleserver_host: "your.hoster.name",
                    mumbleserver_port: 64738,
                    mumbleserver_username: "Musikbot",
                    mumbleserver_userpassword: "",
                    mumbleserver_targetchannel: "channel bot will join at start",
                    # begin mpd config
                    mpd_fifopath: "/path/to/fifo.file",
                    mpd_host: "localhost",
                    mpd_port: 7701,
                    # controllable should set to true else bot can't controlled by mumble-chat
                    controllable: true,
                    # path where certificates are stored
                    certdirectory: "/home/botmaster/certs",
                    # bot need binding for super user command?
                    need_binding: false,
                    # leave it to nobody else binding will fail (internal variable at this time)
                    boundto: "nobody"
                    
    }
    # End of superbot.rb configuation------------------------------------------------------------------------------------------------------------ #
   
end
