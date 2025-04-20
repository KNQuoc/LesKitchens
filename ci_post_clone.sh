#!/bin/bash

# Print current directory for debugging
echo "Current directory: $(pwd)"
echo "Listing directory contents:"
ls -la

# Set up workspace paths
WORKSPACE_ROOT="/Volumes/workspace/repository"
echo "Checking if we're in Xcode Cloud environment..."
if [ -d "$WORKSPACE_ROOT" ]; then
    echo "Running in Xcode Cloud environment"
    cd "$WORKSPACE_ROOT"
    echo "Changed to workspace root: $(pwd)"
    ls -la
fi

# Check if the project exists where we expect it
if [ -d "LesKitchens.xcodeproj" ]; then
    echo "Project found in current directory"
elif [ -d "LesKitchens/LesKitchens.xcodeproj" ]; then
    echo "Project found in LesKitchens subdirectory, creating symlink"
    # Remove any existing symlink first
    rm -f LesKitchens.xcodeproj
    # Create the symlink
    ln -s LesKitchens/LesKitchens.xcodeproj LesKitchens.xcodeproj
    echo "Created symlink to LesKitchens/LesKitchens.xcodeproj"
else
    echo "Searching for project..."
    PROJECT_PATH=$(find . -name "LesKitchens.xcodeproj" -type d | head -n 1)
    if [ -n "$PROJECT_PATH" ]; then
        echo "Found project at: $PROJECT_PATH"
        # Remove any existing symlink first
        rm -f LesKitchens.xcodeproj
        # Create the symlink
        ln -s "$PROJECT_PATH" LesKitchens.xcodeproj
        echo "Created symlink to $PROJECT_PATH"
    else
        echo "ERROR: Could not find LesKitchens.xcodeproj anywhere in the repository"
        exit 1
    fi
fi

# Verify the project exists after our operations
if [ ! -d "LesKitchens.xcodeproj" ]; then
    echo "ERROR: Project still not found after setup"
    exit 1
fi

# Print environment variables for debugging
echo "CI_WORKSPACE: $CI_WORKSPACE"
echo "CI_PRIMARY_REPOSITORY_PATH: $CI_PRIMARY_REPOSITORY_PATH"
echo "CI_DERIVED_DATA_PATH: $CI_DERIVED_DATA_PATH"

# List contents of project directory
echo "Final project directory structure:"
ls -la LesKitchens.xcodeproj/

# Exit with success
exit 0 