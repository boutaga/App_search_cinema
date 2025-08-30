#!/bin/bash
#
# Create or update CONTEXT_PRESERVE.md with active issues
#

set -euo pipefail

PROJECT_ROOT="${1:-$(pwd)}"
PRESERVE_FILE="${PROJECT_ROOT}/CONTEXT_PRESERVE.md"

# Create CONTEXT_PRESERVE.md if it doesn't exist
if [[ ! -f "${PRESERVE_FILE}" ]]; then
    cat > "${PRESERVE_FILE}" <<'EOF'
# Context Preservation

This file maintains essential context that must be preserved across sessions.

## Active Issues
<!-- List any active bugs or issues being worked on -->
- None currently

## Key Decisions
<!-- Important architectural or design decisions -->
- Follow three-phase development: Research → Planning → Implementation
- Update documentation after Phase 3 completion
- Maintain backward compatibility with existing versions

## Configuration Changes
<!-- Recent configuration changes that affect the system -->
- None currently

## Breaking Changes
<!-- Any breaking changes that need attention -->
- None currently

## TODO Items
<!-- High-priority items that need immediate attention -->
- [ ] Review and update after each Phase 3 completion
- [ ] Archive completed items to current_progress.md

## Dependencies
<!-- Critical dependencies or version requirements -->
- Document any specific version requirements
- Note any environment-specific configurations

## Notes for Next Session
<!-- Important reminders for the next work session -->
- Check current_progress.md for project status
- Review map.md for codebase navigation
- Verify phase status before starting work

---
*Last Updated: $(date +%Y-%m-%d)*
*Auto-generated during context compaction*
EOF
    echo "✓ CONTEXT_PRESERVE.md created"
else
    # Update the last updated date
    sed -i "s/\*Last Updated: .*\*/*Last Updated: $(date +%Y-%m-%d)*/" "${PRESERVE_FILE}" 2>/dev/null || \
    echo "*Last Updated: $(date +%Y-%m-%d)*" >> "${PRESERVE_FILE}"
    echo "✓ CONTEXT_PRESERVE.md verified"
fi