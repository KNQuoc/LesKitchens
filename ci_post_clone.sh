#!/bin/bash

# Set permissions for the script
chmod +x ci_post_clone.sh

# Print current directory for debugging
echo "Current directory: $(pwd)"
echo "Listing directory contents:"
ls -la

# Check if the project exists where we expect it
if [ -d "LesKitchens.xcodeproj" ]; then
  echo "Project found in current directory"
else
  echo "Project not found in current directory, checking other locations..."
  find . -name "LesKitchens.xcodeproj" | while read -r projectPath; do
    echo "Found project at: $projectPath"
  done
fi

# Create a symlink if needed
# If the project is not at the root, create a symlink
if [ ! -d "LesKitchens.xcodeproj" ] && [ -d "./LesKitchens/LesKitchens.xcodeproj" ]; then
  echo "Creating symlink for project"
  ln -s ./LesKitchens/LesKitchens.xcodeproj ./LesKitchens.xcodeproj
fi

# Print environment variables for debugging
echo "CI_WORKSPACE: $CI_WORKSPACE"
echo "CI_PRIMARY_REPOSITORY_PATH: $CI_PRIMARY_REPOSITORY_PATH"
echo "CI_DERIVED_DATA_PATH: $CI_DERIVED_DATA_PATH"

# Exit with success
exit 0 