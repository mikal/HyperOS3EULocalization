#!/system/bin/sh
MODDIR=${0%/*}

SYSTEM_VERSION=`getprop ro.system.build.version.incremental`

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

    # Build the list of APKs to install based on user's selection
    # (selection is recorded as marker files under system/etc/localization/)
    local apk_list=""
    local install_log="$TMPDIR/install_log.txt"

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
    # -d: allow version downgrade / signature mismatch
    # -g: grant all runtime permissions
    # -t: allow test packages (important for data-app)
    # --user 0: install for the primary user
    
    # Save log to module directory for debugging
    mkdir -p "$MODDIR/logs"
    local install_log="$MODDIR/logs/install_log.txt"
    echo "=== Installation started at $(date) ===" > "$install_log"
    
    for apk in $apk_list; do
        if [ -f "$apk" ]; then
            local tmp_apk="$TMPDIR/$(basename $apk)"
            cp "$apk" "$tmp_apk"
            
            # Try with -r first (replace)
            if pm install -r -d -g -t --user 0 "$tmp_apk" >/dev/null 2>&1; then
                echo "SUCCESS: $(basename $apk)" >> "$install_log"
            # If fails, try fresh install (EU ROM may not have the package)
            elif pm install -d -g -t --user 0 "$tmp_apk" >/dev/null 2>&1; then
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


cache_clean
force_install_cn_apks &
