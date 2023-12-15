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
function _Choose_Openssl(){
    # Check CPU ABI and modify PATH
    # Openssl binary from Termux
    __ABI=$(getprop ro.product.cpu.abi | awk -F'-' '{print $1}')
    echo "ABI: ${__ABI}"
    OPENSSL_DIR="${MODDIR}/openssl/${__ABI}"
    if [ -d "$OPENSSL_DIR" ]; then
        echo "Select openssl dir ${OPENSSL_DIR}."
        chmod +x $OPENSSL_DIR/openssl
        export PATH=$PATH:$OPENSSL_DIR
        return 0
    fi
    return 1
}
function _DER_To_PEM(){
    # The certificates that installed by user, with der format,
    # but the format of all certificates in system root certificate store is "pem" 
    # with plaintext contain the cert in base64 itself and its text below with sha1 fingerprint.
    # TODO: Convert der to pem
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
    for file in $(find $1 -type f); do
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
    _DER_To_PEM
    chown -R root:root $MODULE_CACERTS_DIR
    chmod -R ugo-rwx,ugo+rX,u+w $MODULE_CACERTS_DIR
    chcon -R u:object_r:system_security_cacerts_file:s0 $MODULE_CACERTS_DIR
    [ "$(ls -A $MODULE_CACERTS_DIR)" == "" ] || touch -t 200901010000.00 $MODULE_CACERTS_DIR/*
}
function Post_Process_Apex(){
    chown -R system:system $1
    [ "$(ls -A $1)" == "" ] || touch -t 197001010000.00 $1/*
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
    [ -d "$dir" ] && _Copy_User_Cacerts $dir
done
Post_Process

# In Android 14 (aka API level 34), certificates are now loaded from /apex/com.android.conscrypt/cacerts (instead of /system/etc/security/cacerts).
# This new path corresponds to the mounted com.android.conscrypt APEX container, which is signed and immutable.
Mount_Apex
