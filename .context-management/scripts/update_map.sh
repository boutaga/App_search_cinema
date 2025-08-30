#!/bin/bash
#
# Update map.md with latest codebase structure and functions
#

set -euo pipefail

PROJECT_ROOT="${1:-$(pwd)}"
MAP_FILE="${PROJECT_ROOT}/map.md"
TEMP_FILE=$(mktemp)

# Function to extract functions from a shell script
extract_functions() {
    local file="$1"
    local relative_path="${file#$PROJECT_ROOT/}"
    
    # Extract function definitions
    grep -n -E '^[[:space:]]*function [a-zA-Z_][a-zA-Z0-9_]*|^[[:space:]]*[a-zA-Z_][a-zA-Z0-9_]*\(\)' "$file" 2>/dev/null | \
    while IFS=: read -r line_num func_def; do
        # Clean up function name
        func_name=$(echo "$func_def" | sed -E 's/^[[:space:]]*function[[:space:]]+//; s/\(\).*/(); s/[[:space:]]*\{.*$//')
        echo "| \`${func_name}\` | ${relative_path}:${line_num} |"
    done
}

# Function to build directory tree
build_tree() {
    local dir="$1"
    local prefix="$2"
    
    # List items, excluding hidden directories and common excludes
    ls -1 "$dir" 2>/dev/null | while read -r item; do
        # Skip hidden files and common directories to exclude
        [[ "$item" =~ ^\. ]] && continue
        [[ "$item" == "node_modules" ]] && continue
        [[ "$item" == "__pycache__" ]] && continue
        [[ "$item" == ".git" ]] && continue
        
        local path="${dir}/${item}"
        
        if [[ -d "$path" ]]; then
            echo "${prefix}├── ${item}/"
            build_tree "$path" "${prefix}│   "
        elif [[ -f "$path" ]]; then
            # Only show relevant files
            case "$item" in
                *.sh|*.bash|*.py|*.yml|*.yaml|*.conf|*.md|*.txt)
                    echo "${prefix}├── ${item}"
                    ;;
            esac
        fi
    done | head -100  # Limit output to prevent huge trees
}

# Create or update map.md
{
    echo "# Codebase Map"
    echo ""
    echo "*Generated: $(date '+%Y-%m-%d %H:%M:%S')*"
    echo ""
    
    echo "## Project Structure"
    echo ""
    echo '```'
    echo "$(basename ${PROJECT_ROOT})/"
    build_tree "${PROJECT_ROOT}" ""
    echo '```'
    echo ""
    
    echo "## Shell Scripts and Functions"
    echo ""
    
    # Find all shell scripts
    find "${PROJECT_ROOT}" -type f \( -name "*.sh" -o -name "*.bash" \) \
         -not -path "*/\.*" \
         -not -path "*/node_modules/*" \
         -not -path "*/.git/*" 2>/dev/null | \
    while read -r script; do
        relative_path="${script#$PROJECT_ROOT/}"
        
        # Count functions in the script
        func_count=$(grep -c -E '^[[:space:]]*function |^[[:space:]]*[a-zA-Z_][a-zA-Z0-9_]*\(\)' "$script" 2>/dev/null || echo 0)
        
        if [[ $func_count -gt 0 ]]; then
            echo "### ${relative_path}"
            echo ""
            echo "| Function | Location |"
            echo "|----------|----------|"
            extract_functions "$script"
            echo ""
        fi
    done
    
    echo "## Python Modules"
    echo ""
    
    # Find Python files
    find "${PROJECT_ROOT}" -type f -name "*.py" \
         -not -path "*/\.*" \
         -not -path "*/node_modules/*" \
         -not -path "*/__pycache__/*" \
         -not -path "*/.git/*" 2>/dev/null | \
    while read -r pyfile; do
        relative_path="${pyfile#$PROJECT_ROOT/}"
        
        # Count classes and functions
        class_count=$(grep -c "^class " "$pyfile" 2>/dev/null || echo 0)
        func_count=$(grep -c "^def " "$pyfile" 2>/dev/null || echo 0)
        
        if [[ $class_count -gt 0 ]] || [[ $func_count -gt 0 ]]; then
            echo "### ${relative_path}"
            echo "- Classes: ${class_count}"
            echo "- Functions: ${func_count}"
            echo ""
        fi
    done
    
    echo "## Configuration Files"
    echo ""
    
    # List configuration files
    find "${PROJECT_ROOT}" -type f \( -name "*.conf" -o -name "*.yml" -o -name "*.yaml" -o -name "*.json" -o -name "*.ini" \) \
         -not -path "*/\.*" \
         -not -path "*/node_modules/*" \
         -not -path "*/.git/*" 2>/dev/null | \
    while read -r config; do
        relative_path="${config#$PROJECT_ROOT/}"
        echo "- \`${relative_path}\`"
    done
    echo ""
    
    echo "## Documentation Files"
    echo ""
    
    # List markdown files
    find "${PROJECT_ROOT}" -type f -name "*.md" \
         -not -path "*/\.*" \
         -not -path "*/node_modules/*" \
         -not -path "*/.git/*" 2>/dev/null | \
    while read -r doc; do
        relative_path="${doc#$PROJECT_ROOT/}"
        # Get first heading if available
        heading=$(head -1 "$doc" 2>/dev/null | grep "^#" | sed 's/^#\+[[:space:]]*//' || echo "")
        if [[ -n "$heading" ]]; then
            echo "- \`${relative_path}\`: ${heading}"
        else
            echo "- \`${relative_path}\`"
        fi
    done
    echo ""
    
    echo "## Quick Navigation"
    echo ""
    echo "### Key Directories"
    echo ""
    
    # List main directories
    for dir in lib scripts config docs tests bin src; do
        if [[ -d "${PROJECT_ROOT}/${dir}" ]]; then
            file_count=$(find "${PROJECT_ROOT}/${dir}" -type f 2>/dev/null | wc -l)
            echo "- \`${dir}/\`: ${file_count} files"
        fi
    done
    echo ""
    
    echo "### Entry Points"
    echo ""
    
    # Find main entry points (files with main functions or if __name__ == "__main__")
    find "${PROJECT_ROOT}" -type f \( -name "*.sh" -o -name "*.py" \) \
         -not -path "*/\.*" \
         -not -path "*/node_modules/*" \
         -not -path "*/.git/*" 2>/dev/null | \
    while read -r file; do
        relative_path="${file#$PROJECT_ROOT/}"
        
        # Check for main functions or entry points
        if grep -q "^main()" "$file" 2>/dev/null || \
           grep -q 'if __name__ == "__main__"' "$file" 2>/dev/null || \
           [[ -x "$file" ]]; then
            echo "- \`${relative_path}\`"
        fi
    done | head -20
    echo ""
    
    echo "---"
    echo "*This map is automatically generated and updated during context compaction.*"
    
} > "${TEMP_FILE}"

# Replace the original file
mv "${TEMP_FILE}" "${MAP_FILE}"

echo "✓ map.md updated"