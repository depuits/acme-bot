#!/usr/bin/env bash

# Process all environment variables with AB_ prefix
process_cert_groups() {
    # Find all unique group identifiers
    # Variables are in format: AB_<GROUP>_<KEY>
    local groups=""
    
    # Extract all AB_* variables and find unique group names
    for var in $(env | grep '^AB_' | cut -d'=' -f1); do
        # Remove AB_ prefix and everything after first _
        local group=$(echo "$var" | sed 's/^AB_//' | cut -d'_' -f1)
        if [[ ! " $groups " =~ " $group " ]]; then
            groups="$groups $group"
        fi
    done
    
    # Process each group
    for group in $groups; do
        # Build variable names for this group
        local domains_var="AB_${group}_DOMAINS"
        local reloadcmd_var="AB_${group}_RELOADCMD"
        local cert_home_var="AB_${group}_CERT_HOME"
        local key_path_var="AB_${group}_KEY_PATH"
        local fullchain_var="AB_${group}_FULLCHAIN_PATH"
        local webroot_var="AB_${group}_WEBROOT_PATH"
        
        # Check if required variables exist
        if [ -z "${!domains_var}" ]; then
            echo "Skipping group $group: No DOMAINS defined"
            continue
        fi
        
        # Parse the domain configuration
        local domains="${!domains_var}"
        local reloadcmd="${!reloadcmd_var:-}"
        local cert_home="${!cert_home_var:-}"
        local key_path="${!key_path_var:-}"
        local fullchain_path="${!fullchain_var:-}"
        local webroot="${!webroot_var:-/var/www/html}"
        
        # Parse method and domains
        local method="${domains%%:*}"
        local domain_list="${domains#*:}"
        
        # Build domain arguments
        local domain_args=""
        IFS=',' read -ra domains_array <<< "$domain_list"
        for domain in "${domains_array[@]}"; do
            domain_args="$domain_args -d $domain"
        done
        
        # Build the issue command
        local cmd="acme.sh --issue"
        
        if [[ "$method" == dns_* ]]; then
            cmd="$cmd --dns $method"
        elif [ "$method" = "http" ]; then
            cmd="$cmd --webroot $webroot"
        elif [ "$method" = "tls-alpn-01" ]; then
            cmd="$cmd --alpn"
        else
            echo "Unknown challenge method: $method for group $group"
            continue
        fi
        
        cmd="$cmd $domain_args"
        
        echo "Issuing certificate for group $group: $domain_list using $method"
        echo "Running: $cmd"
        eval "$cmd"
        
        # Build the install command
        local install_cmd="acme.sh --install-cert $domain_args"
        
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

    local cmd="acme.sh --set-notify --notify-hook $NOTIFY"
    
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
