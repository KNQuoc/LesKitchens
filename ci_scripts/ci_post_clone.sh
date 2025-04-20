#!/bin/bash

# Print current directory for debugging
echo "Current directory: $(pwd)"
echo "Listing directory contents:"
ls -la

# Check if the project exists where we expect it
if [ -d "LesKitchens.xcodeproj" ]; then
  echo "Project found in current directory"
else
  echo "Project not found in current directory, creating symlink if needed"
  # If the project exists but is not at the root, create a symlink
  if [ -d "./LesKitchens.xcodeproj" ]; then
    echo "Project found in LesKitchens.xcodeproj subfolder"
  else 
    find . -name "LesKitchens.xcodeproj" | while read -r projectPath; do
      echo "Found project at: $projectPath"
      # Create a symlink to the project
      ln -s "$projectPath" ./LesKitchens.xcodeproj
      echo "Created symlink to $projectPath"
      break
    done
  fi
fi

# Clean Derived Data to avoid dependency graph errors
rm -rf ~/Library/Developer/Xcode/DerivedData/*
echo "Cleaned DerivedData"

# Print environment variables for debugging
echo "CI_WORKSPACE: $CI_WORKSPACE"
echo "CI_PRIMARY_REPOSITORY_PATH: $CI_PRIMARY_REPOSITORY_PATH"
echo "CI_DERIVED_DATA_PATH: $CI_DERIVED_DATA_PATH"

# Exit with success
exit 0 