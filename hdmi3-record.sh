#!/bin/bash
##set -eE  # same as: `set -o errexit -o errtrace`                                                                                                                                  
source /home/dwade/basic.sh

#--------------------------------------------------------------------------
function preview()
{
    USERNAME=`whoami`
    #echo $USERNAME
    export DISPLAY=:0
    export XAUTHORITY=/home/$USERNAME/.Xauthority
    export LD_LIBRARY_PATH=$LD_LIBRARY_PATH:/usr/lib/aarch64-linux-gnu/gstreamer-1.0

    if [ "$CAPTURE_FRAME_COUNT" != "0" ]; then
        run "gst-launch-1.0 -v v4l2src device=/dev/video0 num-buffers=300 ! video/x-raw,format=$PREVIEW_FORMAT,width=$ACROSS,height=$DOWN ! videoconvert ! xvimagesink \"render-rectangle=<450,-250,1020,1480>\" sync=false"
    else
        # RUN FOREVER !!!!
        run "gst-launch-1.0 -v v4l2src device=/dev/video0                 ! video/x-raw,format=$PREVIEW_FORMAT,width=$ACROSS,height=$DOWN ! videoconvert ! xvimagesink \"render-rectangle=<450,-250,1020,1480>\" sync=false"
    fi

    #gst-launch-1.0 -v v4l2src device=/dev/video0 num-buffers=300 ! video/x-raw,format=RGB,width=$ACROSS,height=$ACROSS ! videoconvert ! xvimagesink "render-rectangle=<450,-250,1020,1480>" sync=false
    # 4K
    #gst-launch-1.0 -v v4l2src device=/dev/video0 num-buffers=300 ! video/x-raw,format=UYVY,width=$ACROSS,height=$DOWN  ! videoconvert ! xvimagesink "render-rectangle=<1400,170,1020,1800>" sync=false
    #gst-launch-1.0 -v v4l2src device=/dev/video0 num-buffers=300 ! video/x-raw,format=UYVY,width=$ACROSS,height=$DOWN  ! videoconvert ! xvimagesink "render-rectangle=<1400,170,1020,1800>" sync=false
}

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

#--------------------------------------------------------------------------
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
    exit $ret
}
#--------------------------------------------------------------------------
title "$0 $*"

ME="`uname -n`"

[ "$ME" == "pi5" ] || [ "$ME" == 'pi6' ] || RED "only runs on pi5 .... exiting" || exit

#--------------------------------------------------------------------------

FRAME_RATE=60

#SVGA 
#ACROSS=720
#DOWN=480

# old ibm PC
#ACROSS=800
#DOWN=600

# 4K resolution
#ACROSS=3840
#DOWN=2160
#-----------------------------------------
ACROSS=1920
DOWN=1080

DIMENSIONS=${ACROSS}x${DOWN}

COLOUR_MAP_RGB888=RGB888_1X24
COLOUR_MAP_YUV16=UYVY8_1X16
COLOUR_MAP_YUV20=UYVY8_1X20

#-----------------------------------------

KEEP=$*
while [ "$1" != "" ]; do
    GREEN "$1"
    case $1 in
        
        --file)
           USE_FILE=true
        ;;

        --encode)
            shift
            CTYPE=$1
            if [ "$CTYPE" == "RGB888" ]; then
                COLOUR_MAP=$COLOUR_MAP_RGB888
                COLOUR_SPACE=srgb
                FILE_SUFFIX=rgb
                PIXEL_FORMAT=RGB3
                PLAY_FORMAT=bgr24
                PREVIEW_FORMAT=RGB
            elif [ "$CTYPE" == "YUV16" ]; then
                COLOUR_MAP=$COLOUR_MAP_YUV16
                COLOUR_SPACE=smpte170m
                FILE_SUFFIX=yuv
                PIXEL_FORMAT=UYVY
                PLAY_FORMAT=uyvy422
                PREVIEW_FORMAT=YUV
            elif [ "$CTYPE" == "YUV20" ]; then
                COLOUR_MAP=$COLOUR_MAP_YUV20
                COLOUR_SPACE=smpte170m
                FILE_SUFFIX=yuv
                PIXEL_FORMAT=V210    # ok
                PLAY_FORMAT=uyvy422
                PREVIEW_FORMAT=YUV
            else
                RED "UNKNOWN COMRESSION TYPE ( pick -RGB888 | -YUV16 | -YUV20) .... exiting"
                exit
            fi
        ;;
        --seconds)
            shift
            [ ! -z $1 ] || RED "need time in seconds ... exiting" || exit
            num_seconds=$1
        ;;

        --frames)
            shift
            num_frames=$1
        ;;

        *)
            RED "unknown option >>> $1 <<<< ... exiting"
            RED " pick --encode | --frames | --seconds"
            exit
        ;;
    esac
    shift
done


if [ "$num_seconds" != "" ]; then 
    CAPTURE_FRAME_COUNT=$(($num_seconds * $FRAME_RATE))
fi

if [ "$num_frames" != '' ]; then
    CAPTURE_FRAME_COUNT=$num_frames
fi

[ "$CAPTURE_FRAME_COUNT" != "" ] || RED "option --seconds or --frames missing ... exiting" || exit

echo "$CAPTURE_FRAME_COUNT frame(s) will be captured"

[ "$COLOUR_MAP" != "" ] || RED "option --encode {RGB888|YUV16|YUV20} missing ... exiting" || exit
echo "COLOUR_MAP=$COLOUR_MAP"


OUTPUT_FILE=$COLOUR_MAP-`date +%Y%m%d%H%M%S`.$FILE_SUFFIX

EDID_FILE="/home/dwade/Scripts/HDMI/HOLD/${DIMENSIONS}-p${FRAME_RATE}.txt"

if [ ! -f $EDID_FILE ]; then
    RED "missing $EDID_FILE ... exiting"
    exit
else
    GREEN "EDID file $EDID_FILE exists"
fi

GREEN "13-----------------------------------------------------------------"
echo "manual dump topology"
media-ctl --print-topology

GREEN "14-----------------------------------------------------------------"
echo "visualize topology"
media-ctl --print-dot > graph.dot
dot -Tpng graph.dot > graph.png   
#feh graph.png


GREEN "14a -----------------------------------------------------------------"
echo "last second query"

v4l2-ctl -d /dev/v4l-subdev2 --query-dv-timings

GREEN "14b -----------------------------------------------------------------"
echo "logs"
v4l2-ctl  -d /dev/v4l-subdev2 --log-status

GREEN "15-----------------------------------------------------------------"
dmesg | egrep "rp1-cfe|tc358|videodev|cma" > /tmp/first_dmesg.log 

sudo dmesg -C || 1
rm -f $OUTPUT_FILE

GREEN "16-----------------------------------------------------------------"

if [ ! -z "$USE_FILE" ]; then
    v4l2-ctl --verbose -d /dev/video0 --set-fmt-video=width=${ACROSS},height=${DOWN},pixelformat=$PIXEL_FORMAT --stream-mmap=4 --stream-skip=3 --stream-count=$CAPTURE_FRAME_COUNT --stream-to=$OUTPUT_FILE --stream-poll 

    if [ ! -f $OUTPUT_FILE ]; then
        BLINK_RED "record stream failed"
        exit
    fi
    GREEN "record complete"
    GREEN "`ls -al $OUTPUT_FILE`"


    GREEN "13-----------------------------------------------------------------"
    echo "If you have installed a desktop version of Raspberry Pi, "
    echo "   you can use ffplay to directly play YUV files."

    echo "ffplay -f rawvideo -video_size ${DIMENSIONS} -pixel_format $PLAY_FORMAT $OUTPUT_FILE "

else
    preview
fi


