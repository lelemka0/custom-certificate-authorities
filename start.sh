#!/system/bin/sh
APEX_CACERTS_DIR="/apex/com.android.conscrypt/cacerts"
SYSTEM_CACERTS_DIR="/system/etc/security/cacerts"
MODULE_CACERTS_DIR="${MODDIR}${SYSTEM_CACERTS_DIR}"
MODULE_CACERTS_HASH="${MODDIR}/cacerts.sha"
USER_CACERTS_DIRS="
/data/misc/user/0/cacerts-custom
/data/misc/user/0/cacerts-added
"

function _Calculate_Hash(){
    echo -n $(find $1 -type f -exec sha256sum {} + | awk '{print $2,$1}' | sort | sha256sum | awk '{print $1}')
}
function _DER_To_PEM(){
    # The certificates that installed by user, with der format,
    # but the format of all certificates in system root certificate store is "pem" 
    # with plaintext contain the cert in base64 itself and its text below with sha1 fingerprint.
    # TODO: Convert der to pem
}
function _Copy_User_Cacerts(){
    for file in $(find $1 -type f);do
        __name=$(echo $file | awk -F'/' '{print $NF}')
        echo $file
        cp $file $MODULE_CACERTS_DIR/$__name
    done
}
function _IsChanged(){
    # TODO: Check whether the certificate has changed to avoid repeated writing.
}
function Pre_Process(){
    mkdir -p $MODULE_CACERTS_DIR
    [ "$(ls -A $MODULE_CACERTS_DIR)" == "" ] || rm $MODULE_CACERTS_DIR/*
}
function Post_Process(){
    chown -R root:root $MODULE_CACERTS_DIR
    chmod -R ugo-rwx,ugo+rX,u+w $MODULE_CACERTS_DIR
    chcon -R u:object_r:system_security_cacerts_file:s0 $MODULE_CACERTS_DIR
    [ "$(ls -A $MODULE_CACERTS_DIR)" == "" ] || touch -d "2009-01-01 00:00:00 GMT" $MODULE_CACERTS_DIR/*
}
function Post_Process_Apex(){
    chown -R system:system $1
    [ "$(ls -A $1)" == "" ] || touch -d "1970-01-01 00:00:00 UTC" $1/*
}
function Mount_Apex(){
    [ -d "$APEX_CACERTS_DIR" ] && (
        echo "!!apex detected. Try to mount overlay fs."
        MODULE_OVERLAY="${MODDIR}/overlay"
        rm -r $MODULE_OVERLAY
        mkdir -p $MODULE_OVERLAY/{layer1,upper,worker}
        mount -t overlay CCA-Layer1 \
            -o lowerdir=$MODULE_CACERTS_DIR,upperdir=$MODULE_OVERLAY/upper,workdir=$MODULE_OVERLAY/worker \
            $MODULE_OVERLAY/layer1
        mount -t overlay CCA-APEX \
            -o lowerdir=$MODULE_OVERLAY/layer1:$APEX_CACERTS_DIR \
            $APEX_CACERTS_DIR
        Post_Process_Apex $MODULE_OVERLAY/layer1
    )
}

Pre_Process
for dir in $USER_CACERTS_DIRS; do
    _Copy_User_Cacerts $dir
done
Post_Process

# In Android 14 (aka API level 34), certificates are now loaded from /apex/com.android.conscrypt/cacerts (instead of /system/etc/security/cacerts).
# This new path corresponds to the mounted com.android.conscrypt APEX container, which is signed and immutable.
Mount_Apex
