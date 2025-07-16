#!/bin/bash

# Changes for BFR setup/dependencies
append_to_dnf_install_bash() {
    local dockerfile_path="Dockerfile"
    local string_to_append="$1"

    # Check if a string to append was provided
    if [ -z "$string_to_append" ]; then
        echo "Error: String to append cannot be empty."
        echo "Usage: append_to_dnf_install_bash \"<string_to_append>\""
        return 1
    fi

    # Check if the Dockerfile exists
    if [ ! -f "$dockerfile_path" ]; then
        echo "Error: Dockerfile not found at '$dockerfile_path'."
        return 1
    fi

    local found_match_and_modified=0

    # Define the sed script using a here-document with a quoted delimiter ('EOF_SED').
    # This prevents Bash from interpreting backslashes or variables within the sed script,
    # ensuring the sed commands are passed literally.
    # We use a placeholder '__STRING_TO_APPEND__' for the string to be appended.
    local sed_script=$(cat <<'EOF_SED'
/dnf -y install/{
    :a
    N
    /\n[[:space:]]*dnf clean all/!ba
    # This substitution targets the last package line ending with ' && \' or just a '\' for continuation.
    # It ensures the new package is inserted BEFORE the '&& \' or just '\' part.
    # Group 1: Leading spaces + package name (e.g., "        git")
    # Group 2: Any spaces immediately after the package name (optional).
    # Group 3: The optional '&&' part (e.g., "&&").
    # Group 4: Any spaces after '&&' and before the literal '\' (e.g., " ").
    # Group 5: The literal '\' character at the end of the line (e.g., "\\") - now a separate group.
    # Group 6: The newline + 'dnf clean all' line (e.g., "\n    dnf clean all").
    s/([[:space:]]*[^[:space:]]+)([[:space:]]*)(&&[[:space:]]*)?([[:space:]]*\\\\)?\n([[:space:]]*dnf clean all)/\1 __STRING_TO_APPEND__\2\3\4\n\5/
    
    # This second substitution handles the edge case where 'dnf -y install \' is immediately
    # followed by 'dnf clean all' (no packages in between).
    s/([[:space:]]+dnf -y install[[:space:]]*)(\\\\)?(\n[[:space:]]*dnf clean all)/\1 __STRING_TO_APPEND__\2\n\3/
}
EOF_SED
)

    # Now, replace the placeholder with the actual string_to_append and pipe the result
    # to sed to apply the changes to the Dockerfile.
    # We use `sed -f -` to read the script from standard input.
    echo "$sed_script" | sed -e "s/__STRING_TO_APPEND__/${string_to_append}/g" | sed -E -i.bak -f - "$dockerfile_path"

    # Check if sed created a backup file, indicating it ran and potentially modified.
    if [ -f "${dockerfile_path}.bak" ]; then
        # Compare the original and modified files to confirm actual changes
        if ! cmp -s "$dockerfile_path" "${dockerfile_path}.bak"; then
            found_match_and_modified=1
            echo -e "\nDockerfile '$dockerfile_path' updated successfully."
        else
            echo -e "\nNo 'dnf -y install' lines found with the specified pattern in '$dockerfile_path'. No changes made."
        fi
        rm "${dockerfile_path}.bak" # Clean up the backup file
    else
        echo -e "\nNo 'dnf -y install' lines found with the specified pattern in '$dockerfile_path'. No changes made."
    fi
}
# append_to_dnf_install_bash cmake

docker build -t kernel-builder-fedora-brf-test-dnf-append .
docker run -it -v "$(pwd)/container_kernel_workspace":/build -v "$(pwd)":/prana_kernel_testing --name kernel-builder-fedora-container-brf-test-dnf-append kernel-builder-fedora-brf-test-dnf-append /bin/bash
