#!/bin/bash
WIDTH=1920
HEIGHT=1080
ENCODE=rgb
DEST_FILE=outfile.$ENCODE



case "$ENCODE" in
    rgb)
        PIXEL_FORMAT=rgb3
        FF_PLAY_FORMAT=bgr24
    ;;

    *)
        RED "unkown pixel format $ENCODE"
        exit
    ;;
esac

function run()
{
    YELLOW "$*" 1>&2
    $*
    ret=$?
    [ $ret == 0 ] || RED "$* failed"
    return $ret
}

function meedia-ctl()
{
    echo "$# parameters seen"
}

#1. Edit /boot/config.txt (sudo permission required).
#
#    sudo nano /boot/config.txt
#    Add the following content:
#    dtoverlay=tc358743
#
#    If your modules C790 support audio, add the following content to enable audio support. If you use C779, please ignore this step
#    dtoverlay=tc358743-audio
#
#    Then reboot the raspberry Pi.
#

echo "2 --------------------------------------------------------------------"
echo " Execute the following command to find the media node corresponding to"
echo " the CSI as media0, under the rp1-cfe (platform: 1f00128000.csi) field:"

v4l2-ctl --list-devices
echo

echo "2a --------------------------------------------------------------------"
echo "Note: The /dev/media0 here comes from the media number obtained in the previous step."
    MEDIA_DEVNAME=`v4l2-ctl --list-devices | grep -A 20 rp1-cfe | grep media | head -1` 
    GREEN "MEDIA_DEVNAME=$MEDIA_DEVNAME"
echo

echo "3 ---------------------------------------------------------------------"
echo " Locate the node corresponding to tc358743 as v4l-subdev2, "
echo " and the pad0 of rp1-cfe-csi2_ch0 as video0:"
echo 
#media-ctl -d $MEDIA_DEVNAME -p

run media-ctl -d $MEDIA_DEVNAME -p | grep --color -A 9 ": tc358743" 

TC3_SUBDEVICE=`media-ctl -d $MEDIA_DEVNAME -p | grep --color -A 2 ": tc358743" | tail -1 | rev | cut -d' ' -f1 | rev`
GREEN "TC3_SUBDEVICE=$TC3_SUBDEVICE"

echo

echo "    ---------- locaate video device ------------------ "
run media-ctl -d $MEDIA_DEVNAME -p | grep --color -A 5 ": rp1-cfe-csi2_ch0"

run media-ctl -d $MEDIA_DEVNAME -p | grep --color -A 2 ": rp1-cfe-csi2_ch0"

VIDEO_DEV=`media-ctl -d $MEDIA_DEVNAME -p | grep --color -A 2 ": rp1-cfe-csi2_ch0" | grep 'node name' | tr -s ' ' | cut -d' ' -f5`
GREEN "VIDEO_DEV=$VIDEO_DEV"

echo "4 ----------------------------------------------------------------------"
echo " To query the current HARDWARE source information, "
echo " if the resolution displays as 0, it indicates that no input source signal"
echo " has been detected. In this case, you should check the hardware connections"
echo " and follow the steps mentioned above to troubleshoot."
echo

    run v4l2-ctl -d $TC3_SUBDEVICE --query-dv-timings

echo "5 ---------------------------------------------------------------"
echo "  Confirm the current input source information."
echo

v4l2-ctl -d $TC3_SUBDEVICE --set-dv-bt-timings query
echo

echo "6 --------------------------------------------------------------"
echo "Initialize $MEDIA_DEVNAME"

run media-ctl -d $MEDIA_DEVNAME -r
echo

echo "7 ----------------------------------------------------------------"
echo "Connect CSI2's pad4 to rp1-cfe-csi2_ch0's pad0."

media-ctl -d $MEDIA_DEVNAME -l ''\''csi2'\'':4 -> '\''rp1-cfe-csi2_ch0'\'':0 [1]'
echo

echo "8 ----------------------------------------------------------------"
echo "  Configure the media node."

media-ctl -d $MEDIA_DEVNAME -V ''\''csi2'\'':0 [fmt:RGB888_1X24/1920x1080 field:none colorspace:srgb]'
media-ctl -d $MEDIA_DEVNAME -V ''\''csi2'\'':4 [fmt:RGB888_1X24/1920x1080 field:none colorspace:srgb]'

meedia-ctl -d $MEDIA_DEVNAME -V ''\''csi2'\'':4 [fmt:RGB888_1X24/1920x1080 field:none colorspace:srgb]'

echo "9 ----------------------------------------------------------------"
echo "Set the output format."

run v4l2-ctl -v width=${WIDTH},height=${HEIGHT},pixelformat=$PIXEL_FORMAT

echo

echo "10 ---------------------------------------------------------------"
echo "Capture two frames for testing to verify if tc358743 is functioning properly."
echo "  Other methods, such as using GStreamer, are not currently available."
echo 

rm $DEST_FILE
v4l2-ctl --verbose -d $VIDEO_DEV --set-fmt-video=width=${WIDTH},height=${HEIGHT},pixelformat=$PIXEL_FORMAT --stream-mmap=4 --stream-skip=3 --stream-count=2 --stream-to=$DEST_FILE --stream-poll

GREEN "see $DEST_FILE"
ls -al $DEST_FILE

echo "11 ---------------------------------------------------------------"
echo " If you have installed a desktop version of Raspberry Pi, "
echo " you can use ffplay to directly play YUV files."

ask "play the file" 4
if [ $? != 0 ]; then
    ffplay -f rawvideo -video_size ${WIDTH}x${HEIGHT} -pixel_format $FF_PLAY_FORMAT $DEST_FILE
fi

#On a Windows computer, you can use software like 7yuv to view .yuv files. 
# For the tutorial with an input format of 19201080, 
# you should select BGR888 in the top right corner of 7yuv 
# and set the resolution to 19201080 to view the two frames you just captured.




