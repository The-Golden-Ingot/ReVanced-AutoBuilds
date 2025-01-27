#!/bin/bash

source ./src/build/utils.sh

# Update version information in Obtainium config
update_version_info() {
    local version_name=$1
    local version_code=$2
    local config_file="obtainium-config.json"
    
    if [ ! -f "$config_file" ]; then
        red_log "[-] Obtainium config file not found"
        return 1
    }
    
    # Update version information
    local tmp_file=$(mktemp)
    jq --arg vname "$version_name" --arg vcode "$version_code" \
        '.app.versionName = $vname | .app.versionCode = ($vcode|tonumber)' \
        "$config_file" > "$tmp_file" && mv "$tmp_file" "$config_file"
    
    green_log "[+] Updated version information in Obtainium config"
}

# Generate Obtainium metadata for releases
generate_obtainium_metadata() {
    local apk_path=$1
    local config_file="obtainium-config.json"
    local metadata_file="obtainium-metadata.json"
    
    if [ ! -f "$config_file" ]; then
        red_log "[-] Obtainium config file not found"
        return 1
    }
    
    # Extract version info from APK
    local version_name=$(aapt dump badging "$apk_path" | grep "versionName" | cut -d"'" -f2)
    local version_code=$(aapt dump badging "$apk_path" | grep "versionCode" | cut -d"'" -f2)
    
    # Update version info in config
    update_version_info "$version_name" "$version_code"
    
    # Generate metadata
    jq -n \
        --arg vname "$version_name" \
        --arg vcode "$version_code" \
        --arg apk "$(basename "$apk_path")" \
        '{
            version: $vname,
            versionCode: ($vcode|tonumber),
            apkFile: $apk,
            timestamp: (now|todate)
        }' > "$metadata_file"
    
    green_log "[+] Generated Obtainium metadata"
}

# Verify APK compatibility with Obtainium
verify_apk_compatibility() {
    local apk_path=$1
    
    if [ ! -f "$apk_path" ]; then
        red_log "[-] APK file not found: $apk_path"
        return 1
    }
    
    # Check APK signature
    if ! check_apk_signature "$apk_path"; then
        red_log "[-] APK signature verification failed"
        return 1
    }
    
    # Check version compatibility
    local version_name=$(aapt dump badging "$apk_path" | grep "versionName" | cut -d"'" -f2)
    if ! check_obtainium_compatibility "$version_name"; then
        return 1
    }
    
    green_log "[+] APK compatibility verified"
    return 0
}

# Check APK signature
check_apk_signature() {
    local apk_path=$1
    
    # Add your signature verification logic here
    # For example, using apksigner:
    if command -v apksigner &> /dev/null; then
        if apksigner verify --print-certs "$apk_path" | grep -q "Verified"; then
            return 0
        fi
    fi
    
    return 1
}

# Main function
main() {
    local command=$1
    shift
    
    case "$command" in
        "verify")
            verify_apk_compatibility "$@"
            ;;
        "metadata")
            generate_obtainium_metadata "$@"
            ;;
        "update-version")
            update_version_info "$@"
            ;;
        *)
            echo "Usage: $0 {verify|metadata|update-version} [args...]"
            exit 1
            ;;
    esac
}

# Run main if script is executed directly
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi 