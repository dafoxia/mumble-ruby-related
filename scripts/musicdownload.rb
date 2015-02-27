#!/usr/bin/env ruby

require 'net/http'

class MusicDownload
    def initialize  
        @downloadfolder = "../music/download/"
        @songlist = Queue.new
    end
    
    def songs
        return @songlist.size
    end
    
    def songname
        @songlist.pop
    end
    
    def get_song site
        # www.myownmusic.de
        download = '/player/download?songid='
        if site.include? "www.myownmusic.de/" then
            begin
                if site.include? "?songid=" then
                    songid = site[site.index('=') + 1, site.length]
                end
                filename = @downloadfolder + songid.to_s + ".mp3"
                Net::HTTP.start("www.myownmusic.de") do |http|
                    resp = http.get ( download + songid.to_s )
                    while resp.code == '301' || resp.code == '302'
                        filename = @downloadfolder + resp.header['location'].split('/')[-1]
                        resp = http.get(URI.parse(URI.escape(resp.header['location'])))
                    end
                    if resp.code == '200' then
                        open(filename, "wb") { |file| file.write(resp.body) }
                        @songlist << filename.split('/')[-1]
                    end
                end
            rescue
            end
        end
        
        # www.epitonic.com
        if site.include? "www.epitonic.com/" then
            begin
                site = site[7..-1] if site[0..6]=="http://"
                domain = site.split('/')[0]
                document = site[domain.size..-1]
                document.slice!("/#")
                filelist = []
                Net::HTTP.start(domain) do |http|
                    resp = http.get ( document )
                    if resp.code =='200' then
                        resp.body.split(/\r?\n/).each do |line|
                            filelist << line[line.index("data-link") + 11 .. -3] if line.include? "data-link"
                        end
                    end
                end
                filelist.each do |line|
                    filename = line.split('/')[-1]
                    filename = filename[0..filename.index("?")-1]
                    line = line[7..-1]
                    domain = line.split('/')[0]
                    document = line[domain.size..-1]
                    Net::HTTP.start(domain) do |http|
                        if !File.exists?(@downloadfolder + filename) then
                            resp = http.get(document.sub('&amp;', '&'))
                            if resp.code == '200' then
                                filename = @downloadfolder + filename
                                open(filename, "wb") { |file| file.write(resp.body) }
                                @songlist << filename.split('/')[-1]
                            end
                        end
                    end
                end
            rescue
            end
        end
        
        if site.include? "www.youtube.com/" then
            begin
                filename = `/usr/local/bin/youtube-dl --get-filename -o \"#{@downloadfoler}%(title)s.%(ext)s\" "#{site}"` 
                system ("/usr/local/bin/youtube-dl -o \"#{@downloadfolder}%(title)s.%(ext)s\" \"#{site}\"")
                @songlist << filename.split('/')[-1]
            end
        end
    end
end


