#!/system/bin/sh
MODDIR=${0%/*}

SYSTEM_VERSION=`getprop ro.system.build.version.incremental`

if [ -f $MODDIR/system/etc/localization/NotificationFilter ] ;then
    NotificationFilter=true
else
    NotificationFilter=false
fi

cache_clean() {
    if [ ! -f $MODDIR/system/etc/localization/SystemVersion/$SYSTEM_VERSION ] ;then
        rm -rf /data/system/package_cache/*
        rm -rf $MODDIR/system/etc/localization/SystemVersion/*
        touch $MODDIR/system/etc/localization/SystemVersion/$SYSTEM_VERSION
    fi
}

notification_feature_process() {
    if $NotificationFilter ;then
        setprop persist.sys.notification_rank 3
        killall com.miui.notification
    fi
}

cache_clean
notification_feature_process