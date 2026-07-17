#!/bin/bash
export LD_LIBRARY_PATH=/usr/local/lib/

if [ -z "$1" ]; then
    WIDTH=$(cat ~/vidformat.param | xargs | cut -f1 -d" ")
    HEIGHT=$(cat ~/vidformat.param | xargs | cut -f2 -d" ")
    FRAMERATE=$(cat ~/vidformat.param | xargs | cut -f3 -d" ")
    DEVICE=$(cat ~/vidformat.param | xargs | cut -f4 -d" ")
else
    WIDTH=$1
    HEIGHT=$2
    FRAMERATE=$3
    DEVICE=$4
fi

echo "=== Starting video with width $WIDTH height $HEIGHT framerate $FRAMERATE device $DEVICE ==="

IS_H264_USB=false
gst-launch-1.0 -v v4l2src device=$DEVICE do-timestamp=true num-buffers=1 ! video/x-h264 ! fakesink &>/dev/null
if [ $? -eq 0 ]; then
    IS_H264_USB=true
    echo "Detected native H264 USB camera."
fi

USE_LIBCAMERA=false
if [ "$IS_H264_USB" = "false" ]; then
    gst-launch-1.0 libcamerasrc num-buffers=1 ! fakesink &>/dev/null
    if [ $? -eq 0 ]; then
        USE_LIBCAMERA=true
        echo "Detected Raspberry Pi CSI Camera via libcamerasrc."
    fi
fi

gstOptions=$(tr '\n' ' ' < $HOME/gstreamer2.param)

if [ "$IS_H264_USB" = "true" ]; then
    v4l2-ctl --device $DEVICE --set-parm $FRAMERATE &>/dev/null
    echo "Launching USB H.264 stream..."
    bash -c "export LD_LIBRARY_PATH=/usr/local/lib/ && gst-launch-1.0 -v v4l2src device=$DEVICE do-timestamp=true ! video/x-h264, width=$WIDTH, height=$HEIGHT, framerate=$FRAMERATE/1 $gstOptions"

elif [ "$USE_LIBCAMERA" = "true" ]; then
    echo "Launching CSI camera stream with hardware H264 encoding..."
    bash -c "export LD_LIBRARY_PATH=/usr/local/lib/ && gst-launch-1.0 -v libcamerasrc ! video/x-raw, width=$WIDTH, height=$HEIGHT, framerate=$FRAMERATE/1 ! v4l2h264enc extra-controls=\"controls,video_bitrate=4000000\" $gstOptions"

else
    echo "Warning: No optimized camera detected. Trying default v4l2src..."
    bash -c "export LD_LIBRARY_PATH=/usr/local/lib/ && gst-launch-1.0 -v v4l2src device=$DEVICE do-timestamp=true ! video/x-h264, width=$WIDTH, height=$HEIGHT, framerate=$FRAMERATE/1 $gstOptions"
fi