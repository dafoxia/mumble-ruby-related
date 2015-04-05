#!/usr/bin/env ruby

require 'net/http'

class MusicDownload
    def initialize
        # Downloadfolder is relative notated to superbot_2!
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
        
        if ( site.include? "www.youtube.com/" ) || ( site.include? "www.youtu.be/" ) || ( site.include? "m.youtube.com/" ) then
            begin
                site.gsub!(/<\/?[^>]*>/, '')
                site.gsub!("&amp;", "&")
                filename = `/usr/local/bin/youtube-dl --get-filename -i -o \"#{@downloadfoler}%(title)s\" "#{site}"`
                system ("/usr/local/bin/youtube-dl -i -o \"#{@downloadfolder}%(title)s.%(ext)s\" \"#{site}\" ")
                filename.split("\n").each do |name|
                    system ("if [ ! -e \"#{@downloadfolder}#{name}.mp3\" ]; then ffmpeg -i \"#{@downloadfolder}#{name}.mp4\" -q:a 0 -map a -metadata title=\"#{name}\" \"#{@downloadfolder}#{name}.mp3\" -y; fi")
                    system ("if [ ! -e \"#{@downloadfolder}#{name}.jpg\" ]; then ffmpeg -i \"#{@downloadfolder}#{name}.mp4\" -s qvga -filter:v select=\"eq(n\\,250)\" -vframes 1 \"#{@downloadfolder}#{name}.jpg\" -y; fi")
                    @songlist << name.split("/")[-1] + ".mp3"
                end
            end
        end
    end
end


