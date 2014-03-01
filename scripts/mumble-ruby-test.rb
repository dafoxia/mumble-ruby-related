#!/bin/ruby

require "mumble-ruby"
cli=Mumble::Client.new("mumble.natenom.name", "64738", "botname", "")
cli.connect
sleep(2)
mysession=cli.me.session
puts cli.channels
cli.disconnect