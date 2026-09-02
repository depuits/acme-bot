#!/usr/bin/env sh

# Process all environment variables with AB_ prefix
process_cert_groups() {
    # Find all unique group identifiers
    # Variables are in format: AB_<GROUP>_<KEY>
    groups=""
    
    # Extract all AB_* variables and find unique group names
    for var in $(env | grep '^AB_' | cut -d'=' -f1); do
        # Remove AB_ prefix and everything after first _
        group=$(echo "$var" | sed 's/^AB_//' | cut -d'_' -f1)
        case " $groups " in
            *" $group "*) ;;
            *) groups="$groups $group" ;;
        esac
    done
    
    # Process each group
    for group in $groups; do
        # Build variable names for this group
        domains_var="AB_${group}_DOMAINS"
        reloadcmd_var="AB_${group}_RELOADCMD"
        cert_home_var="AB_${group}_CERT_HOME"
        key_path_var="AB_${group}_KEY_PATH"
        fullchain_var="AB_${group}_FULLCHAIN_PATH"
        webroot_var="AB_${group}_WEBROOT_PATH"
        
        # Check if required variables exist using eval
        eval "domains=\$$domains_var"
        if [ -z "$domains" ]; then
            echo "Skipping group $group: No DOMAINS defined"
            continue
        fi
        
        # Get optional variables
        eval "reloadcmd=\$$reloadcmd_var"
        eval "cert_home=\$$cert_home_var"
        eval "key_path=\$$key_path_var"
        eval "fullchain_path=\$$fullchain_var"
        eval "webroot=\$$webroot_var"
        
        # Set default webroot if not defined
        [ -z "$webroot" ] && webroot="/var/www/html"
        
        # Parse method and domains
        method="${domains%%:*}"
        domain_list="${domains#*:}"
        
        # Build domain arguments
        domain_args=""
        OLD_IFS="$IFS"
        IFS=','
        set -- $domain_list
        IFS="$OLD_IFS"
        
        for domain in "$@"; do
            [ -z "$domain" ] && continue
            domain_args="$domain_args -d $domain"
        done
        
        # Build the issue command
        cmd="acme.sh --issue"
        
        case "$method" in
            dns_*)
                cmd="$cmd --dns $method"
                ;;
            http)
                cmd="$cmd --webroot $webroot"
                ;;
            tls-alpn-01)
                cmd="$cmd --alpn"
                ;;
            *)
                echo "Unknown challenge method: $method for group $group"
                continue
                ;;
        esac
        
        cmd="$cmd $domain_args"
        
        echo "Issuing certificate for group $group: $domain_list using $method"
        echo "Running: $cmd"
        eval "$cmd"
        
        # Build the install command
        install_cmd="acme.sh --install-cert $domain_args"
        
        if [ -n "$cert_home" ]; then
            install_cmd="$install_cmd --cert-home $cert_home"
        fi
        
        if [ -n "$key_path" ]; then
            install_cmd="$install_cmd --key-file $key_path"
        fi
        
        if [ -n "$fullchain_path" ]; then
            install_cmd="$install_cmd --fullchain-file $fullchain_path"
        fi
        
        if [ -n "$reloadcmd" ]; then
            install_cmd="$install_cmd --reloadcmd \"$reloadcmd\""
        fi
        
        echo "Installing certificate for group $group"
        echo "Running: $install_cmd"
        eval "$install_cmd"
    done
}

init_ca() {
    if [ -z "$CA" ]; then
        return 0
    fi
    acme.sh --set-default-ca --server "$CA"
}

init_email() {
    if [ -z "$EMAIL" ]; then
        echo "Please set the EMAIL environment variable"
        exit 1
    fi
    acme.sh --register-account -m "$EMAIL"
}

init_notify() {
    if [ -z "$NOTIFY" ]; then
        return 0
    fi

    cmd="acme.sh --set-notify --notify-hook $NOTIFY"
    
    if [ -n "$NOTIFY_LEVEL" ]; then
        cmd="$cmd --notify-level $NOTIFY_LEVEL"
    fi
    if [ -n "$NOTIFY_MODE" ]; then
        cmd="$cmd --notify-mode $NOTIFY_MODE"
    fi
    if [ -n "$NOTIFY_SOURCE" ]; then
        cmd="$cmd --notify-source $NOTIFY_SOURCE"
    fi

    echo "Running: $cmd"
    eval "$cmd"
}

# Handle daemon mode
if [ "$1" = "daemon" ]; then
    # Run custom initialization
    init_ca
    init_email
    init_notify
    process_cert_groups
    
    # Now delegate to the official entrypoint for daemon handling
    # The official entrypoint expects "daemon" as the first argument
    exec /entry.sh daemon
else
    # For any other command, just pass through to the official entrypoint
    exec /entry.sh "$@"
fi
