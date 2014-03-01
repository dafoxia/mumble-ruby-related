#!/bin/bash
# Kill running clients ...
killall mpd
sleep 2
killall mpd

mpd /home/botmaster/mpd1/mpd.conf
#mpd /home/botmaster/mpd2/mpd.conf
#mpd /home/botmaster/mpd3/mpd.conf
#etc...