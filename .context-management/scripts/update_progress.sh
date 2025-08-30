#!/bin/bash
#
# Update current_progress.md with latest changes
#

set -euo pipefail

PROJECT_ROOT="${1:-$(pwd)}"
CURRENT_PROGRESS_FILE="${PROJECT_ROOT}/current_progress.md"
TEMP_FILE=$(mktemp)

# Check if file exists
if [[ ! -f "${CURRENT_PROGRESS_FILE}" ]]; then
    echo "Creating new current_progress.md..."
    cat > "${CURRENT_PROGRESS_FILE}" <<'EOF'
# Current Progress

## Project Overview
[Project description]

## Current Version
[Version information]

## Completed Work

## Architecture Components

## Testing and Validation

## Technical Improvements

## Environment Support

## Known Issues and Limitations

## Documentation Status

## Quality Metrics

---
*Last Updated: $(date +%Y-%m-%d)*
*Status: Active Development*
EOF
fi

# Function to extract git activity
extract_git_activity() {
    if command -v git >/dev/null 2>&1 && git rev-parse --git-dir >/dev/null 2>&1; then
        echo "### Recent Git Activity ($(date +%Y-%m-%d))"
        echo ""
        
        # Get commits from last 8 hours or last 10 commits
        echo "#### Recent Commits"
        git log --since="8 hours ago" --oneline --no-merges 2>/dev/null | head -10 | while read -r line; do
            echo "- $line"
        done
        
        echo ""
        echo "#### Modified Files"
        git diff --name-status HEAD~5..HEAD 2>/dev/null | while read -r status file; do
            case $status in
                A) echo "- Added: $file" ;;
                M) echo "- Modified: $file" ;;
                D) echo "- Deleted: $file" ;;
                R*) echo "- Renamed: $file" ;;
            esac
        done
    fi
}

# Function to extract function changes
extract_function_changes() {
    echo "### Function Changes"
    echo ""
    
    # Look for new or modified functions in shell scripts
    if command -v git >/dev/null 2>&1; then
        git diff HEAD~5..HEAD --name-only 2>/dev/null | grep -E '\.(sh|bash)$' | while read -r file; do
            if [[ -f "$file" ]]; then
                echo "#### $file"
                # Extract function definitions
                grep -E '^[[:space:]]*function |^[[:space:]]*[a-zA-Z_][a-zA-Z0-9_]*\(\)' "$file" 2>/dev/null | \
                    sed 's/^[[:space:]]*/- /' | head -5
            fi
        done
    fi
}

# Update the file
{
    # Keep everything up to "## Completed Work"
    sed -n '1,/^## Completed Work$/p' "${CURRENT_PROGRESS_FILE}"
    
    echo ""
    
    # Add new session information
    echo "### Session Update - $(date '+%Y-%m-%d %H:%M')"
    echo ""
    
    # Add git activity
    extract_git_activity
    echo ""
    
    # Add function changes if applicable
    if ls "${PROJECT_ROOT}"/lib/*.sh >/dev/null 2>&1 || ls "${PROJECT_ROOT}"/*.sh >/dev/null 2>&1; then
        extract_function_changes
        echo ""
    fi
    
    # Check for completed phases
    if [[ -f "${PROJECT_ROOT}/.phase_status" ]]; then
        echo "#### Phase Status"
        echo "- $(cat ${PROJECT_ROOT}/.phase_status)"
        echo ""
    fi
    
    # Keep everything after "## Completed Work" section
    sed -n '/^## Architecture Components$/,$p' "${CURRENT_PROGRESS_FILE}"
    
    # Update the last modified date
    sed -i "s/\*Last Updated: .*\*/*Last Updated: $(date +%Y-%m-%d)*/" "${CURRENT_PROGRESS_FILE}" 2>/dev/null || true
    
} > "${TEMP_FILE}"

# Replace the original file
mv "${TEMP_FILE}" "${CURRENT_PROGRESS_FILE}"

echo "✓ current_progress.md updated"