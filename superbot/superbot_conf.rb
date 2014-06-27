def ext_config()
	puts "Config loaded!"
	@controlstring = "." 				#Change it if you want to use another starting string/symbol for the commands.
	@debug = false					#Whether debug mode is on or off.
	@use_vbr = 1 					#Default for mumble-ruby is 0 in order to use cbr, set to 1 to use vbr.
	@listen_to_private_message_only = true 		#Wheter the bot should only listen to private messages.
	@listen_to_registered_users_only = true 	#Whether the bot should only react to commands from registered users.
	@stop_on_unregistered_users = true 		#Whether the bot should stop playing music if a unregistered user joins the channel.
	@use_comment_for_status_display = false 	#Whether to use comment to display song info; false = send to channel, true = comment.
	
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
end
