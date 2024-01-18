#!/system/bin/sh
APEX_CACERTS_DIR="/apex/com.android.conscrypt/cacerts"
SYSTEM_CACERTS_DIR="/system/etc/security/cacerts"
MODULE_PROCESS_DIR="/dev/custom_ca"
MODULE_CACERTS_DIR="${MODULE_PROCESS_DIR}/cacerts"
USER_CACERTS_DIRS="
/data/misc/user/0/cacerts-custom
/data/misc/user/0/cacerts-added
"

function _Choose_Openssl(){
    # Check CPU ABI and modify PATH
    # Openssl binary from Termux
    __ABI=$(getprop ro.product.cpu.abi | awk -F'-' '{print $1}')
    echo "ABI: ${__ABI}"
    OPENSSL_DIR="${MODDIR}/openssl/${__ABI}"
    OPENSSL_LIBS_DIR="${OPENSSL_DIR}/libs"
    if [ -d "$OPENSSL_DIR" ]; then
        echo "Select openssl dir ${OPENSSL_DIR}."
        chmod +x $OPENSSL_DIR/openssl
        export PATH=$PATH:$OPENSSL_DIR
        export LD_LIBRARY_PATH:=$LD_LIBRARY_PATH:$OPENSSL_LIBS_DIR
        return 0
    fi
    return 1
}
function _DER_To_PEM(){
    # The certificates that installed by user, with der format,
    # but the format of all certificates in system root certificate store is "pem" 
    # with plaintext contain the cert in base64 itself and its text below with sha1 fingerprint.
    _Choose_Openssl
    if (( $? != 0 )); then
        echo "No openssl available, skip converting pem."
        return 1
    fi
    for file in $(find $MODULE_CACERTS_DIR -type f); do
        openssl x509 -in $file -outform PEM -out $file
        openssl x509 -in $file -noout -text -fingerprint | tee -a $file
    done
}
function _Copy_User_Cacerts(){
    ###
    # $1: the source directory to find and copy certificates
    ###
    for file in $(find $1 -type f); do
        __name=$(echo $file | awk -F'/' '{print $NF}')
        echo $file
        cp $file $MODULE_CACERTS_DIR/$__name
    done
}
function _Setup_Mount(){
    ###
    # $1: layer name
    # $2: mount target
    ###
    __OVERLAY="${MODULE_PROCESS_DIR}/mount_${1}"
    mkdir -p $__OVERLAY/{merged,upper,worker}
    __MIDDLE_LAYER=$__OVERLAY/merged
    mount -t overlay "CCA-WORK-${1}" \
        -o lowerdir=$MODULE_CACERTS_DIR,upperdir=$__OVERLAY/upper,workdir=$__OVERLAY/worker \
        $__MIDDLE_LAYER
    [ ! -d "${2}" ] && echo "Fail! mount target: ${2} not exist." && return 1
    mount -t overlay "CCA-${1}" \
        -o "lowerdir=$__MIDDLE_LAYER:${2}" \
        "${2}"
}
function Mount_System(){
    echo "mount system cacerts overlay fs."
    _Setup_Mount system $SYSTEM_CACERTS_DIR
    chown -R root:root $__MIDDLE_LAYER
    chmod -R ugo-rwx,ugo+rX,u+w $__MIDDLE_LAYER
    chcon -R u:object_r:system_security_cacerts_file:s0 $__MIDDLE_LAYER
    [ "$(ls -A $__MIDDLE_LAYER)" == "" ] || touch -t 200901010000.00 $__MIDDLE_LAYER/*
}
function Mount_Apex(){
    # In Android 14 (aka API level 34), certificates are now loaded from /apex/com.android.conscrypt/cacerts (instead of /system/etc/security/cacerts).
    # This new path corresponds to the mounted com.android.conscrypt APEX container, which is signed and immutable.
    [ -d "$APEX_CACERTS_DIR" ] && (
        echo "!!apex detected. Try to mount apex cacerts overlay fs."
        _Setup_Mount apex $APEX_CACERTS_DIR
        chown -R system:system $__MIDDLE_LAYER
        chmod -R ugo-rwx,ugo+rX,u+w $__MIDDLE_LAYER
        chcon -R u:object_r:system_security_cacerts_file:s0 $__MIDDLE_LAYER
        [ "$(ls -A $__MIDDLE_LAYER)" == "" ] || touch -t 197001010000.00 $__MIDDLE_LAYER/*
    )
}
function Pre_Process(){
    mkdir -p $MODULE_PROCESS_DIR
    mount -t tmpfs CCA-WORK $MODULE_PROCESS_DIR
    mkdir $MODULE_CACERTS_DIR
}
function Main(){
    for dir in $USER_CACERTS_DIRS; do
        [ -d "$dir" ] && _Copy_User_Cacerts $dir
    done
    _DER_To_PEM
    Mount_System
    Mount_Apex
}
function Post_Process(){
    ###
}

Pre_Process
Main
Post_Process
