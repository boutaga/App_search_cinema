#!/bin/bash
#
# Phase Manager - Track and manage development phases
#

set -euo pipefail

PROJECT_ROOT="${1:-$(pwd)}"
PHASE_STATUS_FILE="${PROJECT_ROOT}/.phase_status"
CURRENT_PHASE_FILE="${PROJECT_ROOT}/.current_phase"
PHASE_LOG_FILE="${PROJECT_ROOT}/.phase_log"

# Colors
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# Get current phase
get_current_phase() {
    if [[ -f "${CURRENT_PHASE_FILE}" ]]; then
        cat "${CURRENT_PHASE_FILE}"
    else
        echo "NONE"
    fi
}

# Set phase
set_phase() {
    local phase="$1"
    local timestamp=$(date +"%Y-%m-%d %H:%M:%S")
    
    # Update current phase
    echo "$phase" > "${CURRENT_PHASE_FILE}"
    
    # Log phase transition
    echo "${timestamp}: ${phase}" >> "${PHASE_LOG_FILE}"
    
    # Update status file
    case "$phase" in
        1|PHASE_1|RESEARCH)
            echo "PHASE_1_RESEARCH" > "${PHASE_STATUS_FILE}"
            echo -e "${BLUE}[PHASE 1]${NC} Research phase started"
            echo "Focus: Understanding the problem and system"
            ;;
        2|PHASE_2|PLANNING)
            echo "PHASE_2_PLANNING" > "${PHASE_STATUS_FILE}"
            echo -e "${YELLOW}[PHASE 2]${NC} Planning phase started"
            echo "Focus: Building step-by-step implementation plan"
            echo "Remember: Create planning.md for review"
            ;;
        3|PHASE_3|IMPLEMENTATION)
            echo "PHASE_3_IMPLEMENTATION" > "${PHASE_STATUS_FILE}"
            echo -e "${GREEN}[PHASE 3]${NC} Implementation phase started"
            echo "Focus: Executing the approved plan"
            ;;
        COMPLETE|DONE)
            echo "PHASE_3_COMPLETE" > "${PHASE_STATUS_FILE}"
            echo -e "${GREEN}[COMPLETE]${NC} Phase 3 completed!"
            echo "Triggering context compaction..."
            touch "${PROJECT_ROOT}/.phase3_complete"
            ;;
        *)
            echo "Unknown phase: $phase"
            exit 1
            ;;
    esac
}

# Complete current phase
complete_phase() {
    local current=$(get_current_phase)
    local timestamp=$(date +"%Y-%m-%d %H:%M:%S")
    
    case "$current" in
        PHASE_1_RESEARCH|1)
            echo "${timestamp}: PHASE_1_COMPLETE" >> "${PHASE_LOG_FILE}"
            echo -e "${GREEN}✓${NC} Phase 1 (Research) completed"
            echo "Next: Start Phase 2 with 'phase_manager.sh set 2'"
            ;;
        PHASE_2_PLANNING|2)
            echo "${timestamp}: PHASE_2_COMPLETE" >> "${PHASE_LOG_FILE}"
            echo -e "${GREEN}✓${NC} Phase 2 (Planning) completed"
            echo "Ensure planning.md has been reviewed before proceeding"
            echo "Next: Start Phase 3 with 'phase_manager.sh set 3'"
            ;;
        PHASE_3_IMPLEMENTATION|3)
            echo "${timestamp}: PHASE_3_COMPLETE" >> "${PHASE_LOG_FILE}"
            set_phase COMPLETE
            ;;
        *)
            echo "No active phase to complete"
            ;;
    esac
}

# Show phase status
show_status() {
    echo "=== Development Phase Status ==="
    echo "Current Phase: $(get_current_phase)"
    echo ""
    
    if [[ -f "${PHASE_LOG_FILE}" ]]; then
        echo "Phase History:"
        tail -5 "${PHASE_LOG_FILE}"
    fi
    
    echo ""
    echo "Phase Guidelines:"
    echo "  Phase 1: Research and understand the system"
    echo "  Phase 2: Create planning.md for review"
    echo "  Phase 3: Implement approved plan"
    echo ""
    echo "Commands:"
    echo "  phase_manager.sh set [1|2|3]     - Set current phase"
    echo "  phase_manager.sh complete        - Complete current phase"
    echo "  phase_manager.sh status          - Show this status"
}

# Main execution
case "${2:-status}" in
    set)
        set_phase "${3:-}"
        ;;
    complete)
        complete_phase
        ;;
    status)
        show_status
        ;;
    reset)
        rm -f "${PHASE_STATUS_FILE}" "${CURRENT_PHASE_FILE}"
        echo "Phase tracking reset"
        ;;
    *)
        echo "Usage: $0 <project_root> [set|complete|status|reset] [phase]"
        exit 1
        ;;
esac