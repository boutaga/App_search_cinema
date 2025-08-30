#!/bin/bash
#
# Context Management System - Main Compaction Script
# Automatically manages context window by archiving completed work
# and updating documentation files
#

set -euo pipefail

# Configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(pwd)"  # Current working directory is the project root

# Context management directories
CONTEXT_MANAGEMENT_DIR="${PROJECT_ROOT}/.context-management"
SCRIPTS_DIR="${CONTEXT_MANAGEMENT_DIR}/scripts"
TEMPLATES_DIR="${CONTEXT_MANAGEMENT_DIR}/templates"

# Context management files
PHASE_STATUS_FILE="${PROJECT_ROOT}/.phase_status"
SESSION_START_FILE="${PROJECT_ROOT}/.session_start"
SESSION_BASE_COMMIT_FILE="${PROJECT_ROOT}/.session_base_commit"
CONTEXT_STATUS_FILE="${PROJECT_ROOT}/.context_status"
CONTEXT_PRESERVE_FILE="${PROJECT_ROOT}/CONTEXT_PRESERVE.md"
CURRENT_PROGRESS_FILE="${PROJECT_ROOT}/current_progress.md"
MAP_FILE="${PROJECT_ROOT}/map.md"
SESSION_ARCHIVE_DIR="${PROJECT_ROOT}/.context-archives"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Logging functions
log_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

log_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

log_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Check if compaction is needed
check_compaction_needed() {
    local reason=""
    
    # Check if Phase 3 just completed
    if [[ -f "${PHASE_STATUS_FILE}" ]] && grep -q "PHASE_3_COMPLETE" "${PHASE_STATUS_FILE}"; then
        reason="Phase 3 completed"
        echo "$reason"
        return 0
    fi
    
    # Check if too many files modified
    if command -v git >/dev/null 2>&1; then
        local modified_count=$(git status --porcelain 2>/dev/null | wc -l)
        if [[ $modified_count -gt 10 ]]; then
            reason="Too many files modified ($modified_count)"
            echo "$reason"
            return 0
        fi
    fi
    
    # Check session duration
    if [[ -f "${SESSION_START_FILE}" ]]; then
        local session_start=$(cat "${SESSION_START_FILE}")
        local current_time=$(date +%s)
        local duration=$((current_time - session_start))
        if [[ $duration -gt 7200 ]]; then  # 2 hours
            reason="Long session ($(($duration / 3600)) hours)"
            echo "$reason"
            return 0
        fi
    fi
    
    # Check for manual trigger
    if [[ -f "${PROJECT_ROOT}/.compact_now" ]]; then
        reason="Manual trigger"
        rm -f "${PROJECT_ROOT}/.compact_now"
        echo "$reason"
        return 0
    fi
    
    return 1
}

# Archive current session
archive_session() {
    log_info "Archiving current session..."
    
    # Create archive directory with timestamp
    local timestamp=$(date +%Y%m%d_%H%M%S)
    local archive_dir="${SESSION_ARCHIVE_DIR}/${timestamp}"
    mkdir -p "$archive_dir"
    
    # Archive phase status files
    for file in .phase_status .session_start .session_base_commit .current_phase; do
        if [[ -f "${PROJECT_ROOT}/${file}" ]]; then
            mv "${PROJECT_ROOT}/${file}" "${archive_dir}/"
        fi
    done
    
    # Create session summary
    cat > "${archive_dir}/session_summary.md" <<EOF
# Session Summary - ${timestamp}

## Duration
$(if [[ -f "${SESSION_START_FILE}" ]]; then
    echo "Start: $(date -d @$(cat ${SESSION_START_FILE}))"
    echo "End: $(date)"
fi)

## Git Activity
$(if command -v git >/dev/null 2>&1; then
    echo "### Recent Commits"
    git log --oneline -10 2>/dev/null || echo "No git repository"
    echo ""
    echo "### Modified Files"
    git status --porcelain 2>/dev/null || echo "No changes"
fi)

## Phase Status
$(if [[ -f "${PHASE_STATUS_FILE}" ]]; then
    cat "${PHASE_STATUS_FILE}"
else
    echo "No phase information"
fi)
EOF
    
    log_success "Session archived to ${archive_dir}"
}

# Update current_progress.md
update_current_progress() {
    log_info "Updating current_progress.md..."
    
    if [[ ! -f "${CURRENT_PROGRESS_FILE}" ]]; then
        log_warning "current_progress.md not found, creating from template..."
        if [[ -f "${TEMPLATES_DIR}/current_progress.template.md" ]]; then
            cp "${TEMPLATES_DIR}/current_progress.template.md" "${CURRENT_PROGRESS_FILE}"
        else
            log_error "Template not found: ${TEMPLATES_DIR}/current_progress.template.md"
            # Create minimal template inline
            cat > "${CURRENT_PROGRESS_FILE}" <<'EOF'
# Current Progress

## Project Overview
Brief description of the project and its main objectives.

## Completed Work

## Architecture Components

## Known Issues and Limitations

---
*Last Updated: $(date +%Y-%m-%d)*
*Status: Active Development*
EOF
        fi
    fi
    
    # Run the update script
    "${SCRIPTS_DIR}/update_progress.sh" "${PROJECT_ROOT}"
    
    log_success "current_progress.md updated"
}

# Update map.md
update_map() {
    log_info "Updating map.md..."
    
    if [[ ! -f "${MAP_FILE}" ]]; then
        log_warning "map.md not found, creating from template..."
        if [[ -f "${TEMPLATES_DIR}/map.template.md" ]]; then
            cp "${TEMPLATES_DIR}/map.template.md" "${MAP_FILE}"
        else
            # Create minimal template inline
            cat > "${MAP_FILE}" <<'EOF'
# Codebase Map

*Generated: $(date '+%Y-%m-%d %H:%M:%S')*

## Project Structure

## Source Files

## Documentation Files

---
*This map is automatically generated and updated during context compaction.*
EOF
        fi
    fi
    
    # Run the update script
    "${SCRIPTS_DIR}/update_map.sh" "${PROJECT_ROOT}"
    
    log_success "map.md updated"
}

# Create context preservation file
create_context_preserve() {
    if [[ ! -f "${CONTEXT_PRESERVE_FILE}" ]]; then
        log_info "Creating CONTEXT_PRESERVE.md..."
        "${SCRIPTS_DIR}/create_preserve.sh" "${PROJECT_ROOT}"
    fi
}

# Main compaction function
compact_context() {
    local reason="${1:-Manual compaction}"
    
    log_info "Starting context compaction..."
    log_info "Reason: $reason"
    
    # Create archive directory if it doesn't exist
    mkdir -p "${SESSION_ARCHIVE_DIR}"
    
    # Step 1: Archive current session
    archive_session
    
    # Step 2: Update documentation
    update_current_progress
    update_map
    create_context_preserve
    
    # Step 3: Clean up temporary files
    log_info "Cleaning up temporary files..."
    rm -f "${PROJECT_ROOT}/.phase3_complete"
    rm -f "${PROJECT_ROOT}/.compact_now"
    
    # Step 4: Reset session tracking
    date +%s > "${SESSION_START_FILE}"
    if command -v git >/dev/null 2>&1; then
        git rev-parse HEAD > "${SESSION_BASE_COMMIT_FILE}" 2>/dev/null || true
    fi
    
    # Step 5: Signal context compacted
    echo "COMPACTED: $(date)" > "${CONTEXT_STATUS_FILE}"
    
    # Step 6: Create compaction report
    cat > "${PROJECT_ROOT}/LAST_COMPACTION.md" <<EOF
# Context Compaction Report

**Date**: $(date)
**Reason**: $reason

## Actions Taken
- ✅ Session archived to ${SESSION_ARCHIVE_DIR}
- ✅ current_progress.md updated
- ✅ map.md updated
- ✅ CONTEXT_PRESERVE.md verified
- ✅ Temporary files cleaned
- ✅ Session tracking reset

## Next Steps
1. Review CONTEXT_PRESERVE.md for active issues
2. Check current_progress.md for project status
3. Refer to map.md for codebase navigation

## Quick Commands
\`\`\`bash
# View current context
cat CONTEXT_PRESERVE.md

# Check project status
cat current_progress.md

# Navigate codebase
grep -n "function_name" map.md
\`\`\`
EOF
    
    log_success "Context compaction completed!"
    echo ""
    log_info "To view compaction report: cat LAST_COMPACTION.md"
}

# Parse command line arguments
parse_arguments() {
    case "${1:-}" in
        --check)
            if reason=$(check_compaction_needed); then
                echo "Compaction needed: $reason"
                exit 0
            else
                echo "No compaction needed"
                exit 1
            fi
            ;;
        --force)
            compact_context "Manual force compaction"
            ;;
        --auto)
            if reason=$(check_compaction_needed); then
                compact_context "$reason"
            else
                log_info "No compaction needed at this time"
            fi
            ;;
        --help)
            cat <<EOF
Usage: $0 [OPTIONS]

Context management system for efficient development workflow.

Options:
    --check     Check if compaction is needed
    --force     Force context compaction
    --auto      Automatically compact if needed
    --help      Show this help message

Examples:
    $0 --auto           # Run automatic compaction check
    $0 --force          # Force immediate compaction
    $0 --check          # Check if compaction is needed

Configuration files:
    .phase_status       # Current development phase
    .session_start      # Session start timestamp
    CONTEXT_PRESERVE.md # Active context to preserve
EOF
            ;;
        *)
            # Default: auto mode
            if reason=$(check_compaction_needed); then
                compact_context "$reason"
            else
                log_info "No compaction needed at this time"
            fi
            ;;
    esac
}

# Main execution
main() {
    parse_arguments "$@"
}

main "$@"