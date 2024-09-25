#!/bin/bash
#https://www.linkedin.com/pulse/unlocking-potential-comprehensive-guide-using-media-controller-kumar-nplsc
#https://wiki.geekworm.com/CSI_Manual_on_Pi_5

#✔ 720x480p60
#✔ 1024x76pP60
#✔ 1280x720p50
#✔ 1280x720p60
#✔ 1280x1024
#✔ 1920x1080i60
#✔ 1920x1080i50
#✔ 1920x1080p60
#✔ 1920x1080p50
#✔ 1600x1200p5
#✔ 1920x1080i120

#--------------------------------------------------------------------------
#sudo killall `pidof v4l2-ctl`
##set -eE  # same as: `set -o errexit -o errtrace`                                                                                                                                  
#--------------------------------------------------------------------------
function v4l2-ctl()
{
    #SHOW="`echo "$1" | sed -r 's= -=\n\t-=g'`"
    #YELLOW "(pretty) $SHOW "
    
    echo -e "$_CYAN v4l2-ctl $* $_RESET" 1>&2

    
    /usr/bin/v4l2-ctl $*
    ret=$?

    if [ $ret == 0 ]; then
        echo -e "$_GREEN PASS"
        return $ret
    fi

    echo -e "$_RED command failed $*" 
    return $ret
}

function media-ctl()
{
    #SHOW="`echo "$1" | sed -r 's= -=\n\t-=g'`"
    #YELLOW "(pretty) $SHOW "
    
    echo -e "$_CYAN media-ctl $* $_RESET" 1>&2

    
    /usr/bin/media-ctl $*
    ret=$?

    if [ $ret == 0 ]; then
        echo -e "$_GREEN PASS"
        return $ret
    fi

    echo -e "$_RED command failed $*" 
    return $ret
}


#--------------------------------------------------------------------------
function run()
{
    SHOW="`echo "$1" | sed -r 's= -=\n\t-=g'`"
    YELLOW "(pretty) $SHOW "
    
    GREEN "(ugly)  $1"
    
    CMD="sudo $*"
    eval "$CMD"
    ret=$?
    sleep 1
    if [ $ret == 0 ]; then
        GREEN "PASS"
        return $ret
    fi
    RED "command failed $1" 
    echo $ret
    return $ret
}
#--------------------------------------------------------------------------

ME="`uname -n`"

[ "$ME" == "pi5" ] || RED "only runs on pi5 .... exiting" || exit

#--------------------------------------------------------------------------
reset

FRAME_RATE=60

#ACROSS=720
#DOWN=480

ACROSS=1920
DOWN=1080

#ACROSS=800
#DOWN=600

DIMENSIONS=${ACROSS}x${DOWN}

COLOUR_MAP_RGB=RGB888_1X24
COLOUR_MAP_YUV=UYVY8_1X16

CTYPE=RGB
if [ "$CTYPE" == "RGB" ]; then
    COLOUR_MAP=$COLOUR_MAP_RGB
elif [ "$CTYPE" == "YUV" ]; then
    COLOUR_MAP=$COLOUR_MAP_RGB
else
    RED "UNKNOWN COMRESSION TYPE .... exiting"
    exit
fi

CAPTURE_TIME_SEC=3
CAPTURE_FRAME_COUNT=$(($CAPTURE_TIME_SEC * $FRAME_RATE))

OUTPUT_FILE=$COLOUR_MAP-`date +%Y%m%d%H%M%S`.$CTYPE

EDID_FILE="/home/dwade/Scripts/HDMI/HOLD/${DIMENSIONS}-p${FRAME_RATE}.txt"

if [ ! -f $EDID_FILE ]; then
    RED "missing $EDID_FILE ... exiting"
    exit
else
    GREEN "EDID file $EDID_FILE exists"
fi


set -e

MEDIA="`sudo /usr/bin/v4l2-ctl --list-devices | grep -A50 rp1-cfe | grep  media | head -1`"
v4l2-ctl --list-devices | grep -A50 rp1-cfe 
echo "MEDIA=$MEDIA"; sleep 1
DEVICE_NUM="`echo $MEDIA | rev | cut -c1`"
echo "DEVICE_NUM = $DEVICE_NUM"
sleep 1


GREEN "1a------------------------------------------------------------------"
run "egrep -C5 --color "tc35*" /boot/firmware/config.txt"

GREEN "1b------------------------------------------------------------------"
run "edid-decode $EDID_FILE"

GREEN "1b------------------------------------------------------------------"
echo " Execute the following command to find the media node corresponding "
echo " to the CSI as media0"
echo "       under the rp1-cfe platform: 1f00128000.csi field:"


v4l2-ctl --list-devices  | grep --color -A20 platform:1f00128000.csi 

GREEN "2------------------------------------------------------------------"
echo "Locate the node corresponding to tc358743 as v4l-subdev2, "
echo "     and the pad0 of rp1-cfe-csi2_ch0 as video0: "

media-ctl -d $DEVICE_NUM -p  | grep --color -C10 tc358743

GREEN "3------------------------------------------------------------------"
echo "Locate the video pin, "
echo "     and the pad0 of rp1-cfe-csi2_ch0 as video0: "

media-ctl -d $DEVICE_NUM -p  | grep  -A4 ": rp1-cfe-csi2_ch" |  egrep --color -A3 "rp1-cfe-csi2_ch.|video."

GREEN "4------------------------------------------------------------------"
#https://forums.raspberrypi.com/viewtopic.php?p=2156480#p2156480

rm -f hdmi_config.save
media-ctl --print-dot  > hdmi_config.save
ls -al hdmi_config.save

GREEN "5------------------------------------------------------------------"
echo "https://forums.raspberrypi.com/viewtopic.php?t=364896"

v4l2-ctl -d /dev/v4l-subdev2 --set-edid=file=$EDID_FILE --fix-edid-checksums

GREEN "6------------------------------------------------------------------"
# reset links
echo "reset media"
media-ctl -d $DEVICE_NUM -r

GREEN "7------------------------------------------------------------------"
v4l2-ctl -d /dev/v4l-subdev2 --set-dv-bt-timings query

GREEN "8------------------------------------------------------------------"
echo "Connect CSI2's pad4 to rp1-cfe-csi2_ch0's pad0."

run " media-ctl -d $DEVICE_NUM -l ''\''csi2'\'':4 -> '\''rp1-cfe-csi2_ch0'\'':0 [1]'"

GREEN "8a-----------------------------------------------------------------"
run "media-ctl -d $DEVICE_NUM -V ''\''tc358743 4-000f'\'':0 [fmt:${COLOUR_MAP}/${DIMENSIONS} field:none colorspace:srgb]'"

GREEN "9------------------------------------------------------------------"
echo "Configure the media node."

run "media-ctl -d $DEVICE_NUM -V '\"csi2\":0 [fmt:${COLOUR_MAP}/${DIMENSIONS} field:none colorspace:srgb]'"

GREEN "10-----------------------------------------------------------------"

run "media-ctl -d $DEVICE_NUM -V '\"csi2\":4 [fmt:${COLOUR_MAP}/${DIMENSIONS} field:none colorspace:srgb]'"

GREEN "11-----------------------------------------------------------------"
echo "Set the output format."
# unknown why you DON'T specify a device name

v4l2-ctl --verbose -v width=${ACROSS},height=${DOWN},pixelformat=RGB3

GREEN "12-----------------------------------------------------------------"
echo "Capture two frames for testing to verify if tc358743 is function."
echo "Other methods, such as using GStreamer, are not currently available."


GREEN "13-----------------------------------------------------------------"
echo "manual dump topology"
media-ctl --print-topology

GREEN "14-----------------------------------------------------------------"
echo "visualize topology"
run "media-ctl --print-dot > graph.dot"
run "dot -Tpng graph.dot > graph.png"   
#feh graph.png


GREEN "14a -----------------------------------------------------------------"
echo "last second query"

v4l2-ctl -d /dev/v4l-subdev2 --query-dv-timings

GREEN "14b -----------------------------------------------------------------"
echo "logs"
v4l2-ctl  -d /dev/v4l-subdev2 --log-status

GREEN "15-----------------------------------------------------------------"
echo "last second query"
if [ ! -f `realpath first_dmesg.log` ]; then
    run "dmesg | egrep \"rp1-cfe|tc358|videodev|cma\" > /tmp/first_dmesg.log" 
fi

ln -sf /tmp/first_dmesg.log ./first_dmesg.log || true 


set +e

trap - ERR
ask "do you want to proceeed"
[ $? == 1 ] || exit
set -e

sudo dmesg -C || 1
rm -f $OUTPUT_FILE

v4l2-ctl --verbose -d /dev/video0 --set-fmt-video=width=${ACROSS},height=${DOWN},pixelformat='RGB3' --stream-mmap=4 --stream-skip=3 --stream-count=$CAPTURE_FRAME_COUNT --stream-to=$OUTPUT_FILE --stream-poll 

if [ ! -f $OUTPUT_FILE ]; then
    BLINK_RED "record stream failed"
    exit
fi
GREEN "record complete"
GREEN "`ls -al $OUTPUT_FILE`"


GREEN "13-----------------------------------------------------------------"
echo "If you have installed a desktop version of Raspberry Pi, "
echo "   you can use ffplay to directly play YUV files."

echo "ffplay -f rawvideo -video_size ${DIMENSIONS} -pixel_format bgr24 $OUTPUT_FILE "



