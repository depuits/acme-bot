#!/usr/bin/env bash

# Custom initialization functions
init_domains() {
    if [ -z "$DOMAINS" ]; then
        return 0
    fi

    # Split by semicolon for multiple domain groups
    IFS=';' read -ra domain_groups <<< "$DOMAINS"
    for group in "${domain_groups[@]}"; do
        # Split by pipe for reloadcmd
        local issue_part="${group%%|*}"
        local reloadcmd=""
        if [[ "$group" == *"|"* ]]; then
            reloadcmd="${group#*|}"
        fi
        
        local method="${issue_part%%:*}"
        local domain_list="${issue_part#*:}"
        
        # Build -d arguments
        local domain_args=""
        IFS=',' read -ra domains <<< "$domain_list"
        for domain in "${domains[@]}"; do
            domain_args="$domain_args -d $domain"
        done

        # Build the command
        local cmd="acme.sh --issue"
        
        if [[ "$method" == dns_* ]]; then
            cmd="$cmd --dns $method"
        elif [ "$method" = "http" ]; then
            local webroot="${WEBROOT_PATH:-/var/www/html}"
            cmd="$cmd --webroot $webroot"
        elif [ "$method" = "tls-alpn-01" ]; then
            cmd="$cmd --alpn"
        else
            echo "Unknown challenge method: $method"
            continue
        fi
        
        cmd="$cmd $domain_args"
        
        if [ -n "$reloadcmd" ]; then
            cmd="$cmd --reloadcmd \"$reloadcmd\""
        fi
        
        echo "Running: $cmd"
        eval "$cmd"
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
    init_domains
    
    # Now delegate to the official entrypoint for daemon handling
    # The official entrypoint expects "daemon" as the first argument
    exec /entry.sh daemon
else
    # For any other command, just pass through to the official entrypoint
    exec /entry.sh "$@"
fi
