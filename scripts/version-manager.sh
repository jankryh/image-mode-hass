#!/bin/bash
# Version management script for Home Assistant bootc
# Handles version bumping, changelog updates, and release preparation

set -euo pipefail

# Load common libraries
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/lib/common.sh"

# Initialize script
init_script "version-manager"

# Configuration
VERSION_FILE="$PROJECT_ROOT/VERSION"
CHANGELOG_FILE="$PROJECT_ROOT/CHANGELOG.md"
CONTAINERFILE="$PROJECT_ROOT/Containerfile"

# Function to get current version
get_current_version() {
    if [[ -f "$VERSION_FILE" ]]; then
        cat "$VERSION_FILE"
    else
        echo "1.0.0"
    fi
}

# Function to validate version format
validate_version() {
    local version="$1"
    if ! [[ "$version" =~ ^[0-9]+\.[0-9]+\.[0-9]+(-[a-zA-Z0-9]+)?$ ]]; then
        error "Invalid version format: $version"
        error "Expected format: MAJOR.MINOR.PATCH[-PRERELEASE]"
        return 1
    fi
    return 0
}

# Function to bump version
bump_version() {
    local current_version="$1"
    local bump_type="$2"
    
    # Parse current version
    local major minor patch prerelease
    IFS='.' read -r major minor patch <<< "${current_version%%-*}"
    if [[ "$current_version" == *-* ]]; then
        prerelease="${current_version#*-}"
    fi
    
    # Bump based on type
    case "$bump_type" in
        major)
            major=$((major + 1))
            minor=0
            patch=0
            prerelease=""
            ;;
        minor)
            minor=$((minor + 1))
            patch=0
            prerelease=""
            ;;
        patch)
            patch=$((patch + 1))
            prerelease=""
            ;;
        prerelease)
            if [[ -z "$prerelease" ]]; then
                prerelease="rc1"
            elif [[ "$prerelease" =~ rc([0-9]+) ]]; then
                local rc_num="${BASH_REMATCH[1]}"
                prerelease="rc$((rc_num + 1))"
            else
                error "Cannot bump prerelease version: $prerelease"
                return 1
            fi
            ;;
        *)
            error "Invalid bump type: $bump_type"
            return 1
            ;;
    esac
    
    # Construct new version
    local new_version="$major.$minor.$patch"
    if [[ -n "$prerelease" ]]; then
        new_version="$new_version-$prerelease"
    fi
    
    echo "$new_version"
}

# Function to update version in files
update_version_in_files() {
    local old_version="$1"
    local new_version="$2"
    
    log_step 1 4 "Updating VERSION file"
    echo "$new_version" > "$VERSION_FILE"
    success "Updated VERSION file"
    
    log_step 2 4 "Updating Containerfile"
    if grep -q "version=\"$old_version\"" "$CONTAINERFILE"; then
        sed -i.bak "s/version=\"$old_version\"/version=\"$new_version\"/g" "$CONTAINERFILE"
        rm -f "$CONTAINERFILE.bak"
        success "Updated Containerfile"
    else
        warn "Version string not found in Containerfile"
    fi
    
    log_step 3 4 "Updating README.md"
    if [[ -f "$PROJECT_ROOT/README.md" ]]; then
        # Update badge if present
        sed -i.bak "s/version-$old_version-/version-$new_version-/g" "$PROJECT_ROOT/README.md"
        rm -f "$PROJECT_ROOT/README.md.bak"
        success "Updated README.md"
    fi
    
    log_step 4 4 "Updating config.mk"
    if grep -q "IMAGE_TAG ?= $old_version" "$PROJECT_ROOT/config.mk"; then
        sed -i.bak "s/IMAGE_TAG ?= $old_version/IMAGE_TAG ?= $new_version/g" "$PROJECT_ROOT/config.mk"
        rm -f "$PROJECT_ROOT/config.mk.bak"
        success "Updated config.mk"
    fi
}

# Function to update changelog
update_changelog() {
    local new_version="$1"
    local release_date="$2"
    
    info "Updating CHANGELOG.md"
    
    # Create temporary file
    local temp_file
    temp_file=$(mktemp)
    
    # Process changelog
    local in_unreleased=false
    # Note: unreleased_content is used for future enhancement
    # local unreleased_content=""
    
    while IFS= read -r line; do
        if [[ "$line" == "## [Unreleased]"* ]]; then
            in_unreleased=true
            echo "$line" >> "$temp_file"
            echo "" >> "$temp_file"
            echo "## [$new_version] - $release_date" >> "$temp_file"
        elif [[ "$in_unreleased" == true ]] && [[ "$line" == "## ["* ]]; then
            in_unreleased=false
            echo "$line" >> "$temp_file"
        else
            echo "$line" >> "$temp_file"
        fi
    done < "$CHANGELOG_FILE"
    
    # Replace original file
    mv "$temp_file" "$CHANGELOG_FILE"
    success "Updated CHANGELOG.md"
}

# Function to create git tag
create_git_tag() {
    local version="$1"
    local tag_name="v$version"
    
    info "Creating git tag: $tag_name"
    
    # Check if tag already exists
    if git rev-parse "$tag_name" >/dev/null 2>&1; then
        error "Tag $tag_name already exists"
        return 1
    fi
    
    # Create annotated tag
    git tag -a "$tag_name" -m "Release version $version"
    success "Created tag: $tag_name"
    
    info "To push tag: git push origin $tag_name"
}

# Function to show current version info
show_version_info() {
    local current_version
    current_version=$(get_current_version)
    
    log_section "Version Information"
    echo "Current version: $current_version"
    echo "Version file: $VERSION_FILE"
    echo ""
    echo "Recent tags:"
    git tag -l "v*" | tail -5
    echo ""
    echo "Recent commits:"
    git log --oneline -5
}

# Main function
main() {
    local action="${1:-show}"
    local bump_type="${2:-patch}"
    
    case "$action" in
        show)
            show_version_info
            ;;
        bump)
            require_commands git sed
            
            local current_version
            current_version=$(get_current_version)
            info "Current version: $current_version"
            
            local new_version
            new_version=$(bump_version "$current_version" "$bump_type")
            info "New version: $new_version"
            
            if ! confirm "Bump version from $current_version to $new_version?"; then
                info "Version bump cancelled"
                exit 0
            fi
            
            update_version_in_files "$current_version" "$new_version"
            
            success "Version bumped to $new_version"
            info "Don't forget to update CHANGELOG.md and commit changes"
            ;;
        release)
            require_commands git
            
            local current_version
            current_version=$(get_current_version)
            local release_date
            release_date=$(date +%Y-%m-%d)
            
            info "Preparing release for version $current_version"
            
            # Check for uncommitted changes
            if ! git diff-index --quiet HEAD --; then
                error "Uncommitted changes detected. Please commit or stash them."
                exit 1
            fi
            
            update_changelog "$current_version" "$release_date"
            
            # Commit changelog
            git add "$CHANGELOG_FILE"
            git commit -m "chore: update changelog for v$current_version"
            
            # Create tag
            create_git_tag "$current_version"
            
            success "Release $current_version prepared"
            echo ""
            echo "Next steps:"
            echo "1. Review the changes"
            echo "2. Push commits: git push origin main"
            echo "3. Push tag: git push origin v$current_version"
            ;;
        set)
            local new_version="${2:-}"
            if [[ -z "$new_version" ]]; then
                error "Version number required"
                echo "Usage: $0 set VERSION"
                exit 1
            fi
            
            validate_version "$new_version"
            
            local current_version
            current_version=$(get_current_version)
            update_version_in_files "$current_version" "$new_version"
            
            success "Version set to $new_version"
            ;;
        *)
            error "Unknown action: $action"
            echo "Usage: $0 [show|bump|release|set] [VERSION|BUMP_TYPE]"
            echo ""
            echo "Actions:"
            echo "  show             Show current version info"
            echo "  bump [type]      Bump version (major|minor|patch|prerelease)"
            echo "  release          Prepare release (update changelog, create tag)"
            echo "  set VERSION      Set specific version"
            exit 1
            ;;
    esac
}

# Run main function
main "$@"