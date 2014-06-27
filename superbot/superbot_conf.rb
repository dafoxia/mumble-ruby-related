def ext_config()
	puts "Config loaded!"
	@controlstring = "." 						#Change it if you want to use another starting string/symbol for the commands
	@debug = false 								#Whether debug mode is on or off
	@listen_to_private_message_only = true 		#Wheter the bot should only listen to private messages
	@listen_to_registered_users_only = true 	#Whether the bot should only listen to registered users or not
	@stop_on_unregistered_users = true 			#Whether the bot should stop playing music if a unregistered user joins the channel
	@use_comment_for_status_display = true 		#Whether to use comment to display song info; false = send to channel, true = comment
end