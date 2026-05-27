#!/system/bin/sh
MODDIR=${0%/*}

SYSTEM_VERSION=`getprop ro.system.build.version.incremental`

if [ -f $MODDIR/system/etc/localization/MiPush ] ;then
    MiPush=true
else
    MiPush=false
fi

cache_clean() {
    if [ ! -f $MODDIR/system/etc/localization/SystemVersion/$SYSTEM_VERSION ] ;then
        rm -rf /data/system/package_cache/*
        rm -rf $MODDIR/system/etc/localization/SystemVersion/*
        mkdir -p $MODDIR/system/etc/localization/SystemVersion
        touch $MODDIR/system/etc/localization/SystemVersion/$SYSTEM_VERSION
    fi
}

# Force install CN APKs to override EU versions with different signatures.
# Runs once per system version, triggered on first boot after module install/update.
force_install_cn_apks() {
    local TMPDIR=/data/local/tmp/eu_loc_install
    local MARKER=$MODDIR/system/etc/localization/.apks_installed_$SYSTEM_VERSION

    # Only run once per system version.
    # Delete the marker manually (or it auto-resets on system OTA) to force a re-run.
    if [ -f "$MARKER" ]; then
        return
    fi

    # Wait for PackageManager to be fully ready
    while [ "$(getprop sys.boot_completed)" != "1" ]; do
        sleep 2
    done
    sleep 10

    mkdir -p $TMPDIR

    # Save log to module directory for debugging
    mkdir -p "$MODDIR/logs"
    local install_log="$MODDIR/logs/install_log.txt"
    echo "=== Installation started at $(date) ===" > "$install_log"

    # Install conflict-causing apps first (Notes, AOD) to resolve permission conflicts.
    # This is required before installing data-app / system-signed apps like Calendar,
    # Weather, Music and ThemeManager, otherwise pm install will fail.
    for apk in \
        "$MODDIR/system/product/app/Notes/Notes.apk" \
        "$MODDIR/system/product/priv-app/MiuiAod/MiuiAod.apk"; do
        if [ -f "$apk" ]; then
            cp "$apk" "$TMPDIR/$(basename $apk)"
            pm install -r -d -g "$TMPDIR/$(basename $apk)" >/dev/null 2>&1
            rm -f "$TMPDIR/$(basename $apk)"
        fi
    done

    sleep 3

    # Build the list of APKs to install based on user's selection
    # (selection is recorded as marker files under system/etc/localization/)
    local apk_list=""

    if [ -f "$MODDIR/system/etc/localization/Calendar" ]; then
        apk_list="$apk_list $MODDIR/system/product/data-app/MIUICalendar/MIUICalendar.apk"
    fi

    if [ -f "$MODDIR/system/etc/localization/Weather" ]; then
        apk_list="$apk_list $MODDIR/system/product/data-app/MIUIWeather/MIUIWeather.apk"
    fi

    if [ -f "$MODDIR/system/etc/localization/Music" ]; then
        apk_list="$apk_list $MODDIR/system/product/data-app/MIUIMusicT/MIUIMusicT.apk"
    fi

    if [ -f "$MODDIR/system/etc/localization/Gallery" ]; then
        apk_list="$apk_list $MODDIR/system/product/priv-app/MiuiGallery/MIUIGallery.apk"
    fi

    if [ -f "$MODDIR/system/etc/localization/MediaEditor" ]; then
        apk_list="$apk_list $MODDIR/system/product/app/MiMediaEditor/MiMediaEditor.apk"
    fi

    if [ -f "$MODDIR/system/etc/localization/ThemeManager" ]; then
        apk_list="$apk_list $MODDIR/system/app/ThemeManager/ThemeManager.apk"
    fi

    if [ -f "$MODDIR/system/etc/localization/SoundRecorder" ]; then
        apk_list="$apk_list $MODDIR/system/app/MiuiAudioMonitor/MiuiAudioMonitor.apk"
        apk_list="$apk_list $MODDIR/system/product/priv-app/SoundRecorder/SoundRecorder.apk"
    fi

    # Install each APK.
    # -r: replace existing package
    # -d: allow version downgrade / signature mismatch
    # -g: grant all runtime permissions
    for apk in $apk_list; do
        if [ -f "$apk" ]; then
            local tmp_apk="$TMPDIR/$(basename $apk)"
            cp "$apk" "$tmp_apk"
            if pm install -r -d -g "$tmp_apk" >/dev/null 2>&1; then
                echo "SUCCESS: $(basename $apk)" >> "$install_log"
            elif pm install -d -g "$tmp_apk" >/dev/null 2>&1; then
                echo "SUCCESS (fresh): $(basename $apk)" >> "$install_log"
            else
                echo "FAILED: $(basename $apk)" >> "$install_log"
            fi
            rm -f "$tmp_apk"
        fi
    done

    echo "=== Installation finished at $(date) ===" >> "$install_log"

    rm -rf $TMPDIR

    # Mark as done for this system version
    touch "$MARKER"
}

set_mipush_region() {
    local uid
    uid="$(dumpsys package com.xiaomi.xmsf 2>/dev/null | sed -n 's/.*userId=//p' | sed -n '1p' | tr -d '\r')"

    # Write to all known data directories for com.xiaomi.xmsf.
    # Both /data/data/ and /data/user/0/ may be active on the device
    # (/data/data is typically a symlink to /data/user/0 but not always).
    # /data/user_de/ is the Device Encrypted path used on Android 7+.
    for base_dir in \
        /data/data/com.xiaomi.xmsf \
        /data/user/0/com.xiaomi.xmsf \
        /data/user_de/0/com.xiaomi.xmsf; do

        [ -d "$base_dir" ] || continue

        local files_dir="$base_dir/files"
        mkdir -p "$files_dir"

        printf '%s\n' CN > "$files_dir/mipush_country_code"
        printf '%s\n' China > "$files_dir/mipush_region"

        if [ -n "$uid" ]; then
            chown -R "$uid:$uid" "$base_dir" 2>/dev/null || true
        fi

        restorecon -R "$base_dir" 2>/dev/null || true
    done
}


cache_clean
force_install_cn_apks &

if $MiPush ; then
    set_mipush_region
fi
