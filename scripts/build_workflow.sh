#!/bin/bash

# File paths
country_port_file="region_port_mapping.txt"
workflow_dir="../.github/workflows"

# Base template for workflow content
base_content=$(cat << 'EOF'
name: Build and Push - LOCATION_NAME_PLACEHOLDER

on:
  schedule:
    - cron: '0 19 * * *'  # Runs daily at 19 UTC (4 am Korea)
  workflow_dispatch:

env:
  BASE_PATH: 333025262616.dkr.ecr.ap-northeast-2.amazonaws.com/osrm
  FULL_LOCATION: FULL_LOCATION_PLACEHOLDER

jobs:
  build-and-push:
    runs-on: ubuntu-latest

    steps:
      - name: Checkout code
        uses: actions/checkout@v3

      - name: Configure AWS credentials
        uses: aws-actions/configure-aws-credentials@v2
        with:
          aws-access-key-id: ${{ secrets.AWS_ACCESS_KEY_ID }}
          aws-secret-access-key: ${{ secrets.AWS_SECRET_ACCESS_KEY }}
          aws-region: ap-northeast-2

      - name: Log in to Amazon ECR
        run: |
          aws ecr get-login-password --region ap-northeast-2 | docker login --username AWS --password-stdin ${{ env.BASE_PATH }}

      - name: Build and push Docker image for ${{ env.FULL_LOCATION }}
        run: |
          # Use FULL_LOCATION for the download URL
          LOCATION_URL="${{ env.FULL_LOCATION }}"

          # Extract the last part of the location for the filename (e.g., "south-korea")
          LOCATION_NAME=$(basename "${LOCATION_URL}")

          # Download map file for the specified location
          curl -o ${LOCATION_NAME}-latest.osm.pbf "https://download.geofabrik.de/${LOCATION_URL}-latest.osm.pbf"

          # Build Docker image for the specified location
          docker build --build-arg LOCATION=${LOCATION_NAME} -t ${{ env.BASE_PATH }}:${LOCATION_NAME} .

          # Push Docker image for the specified location
          docker push ${{ env.BASE_PATH }}:${LOCATION_NAME}

          # Remove downloaded map file to free up space
          rm ${LOCATION_NAME}-latest.osm.pbf
EOF
)

# Check if country_ports.txt exists
if [[ ! -f "$country_port_file" ]]; then
  echo "Error: $country_port_file not found!"
  exit 1
fi

# Read country-port mappings and generate workflows
while IFS=":" read -r full_location port; do
  # Extract the last part of the location for naming the workflow
  location_name=$(basename "$full_location" | sed 's/-/_/g')

  # Replace placeholders with actual values
  workflow_content="${base_content//FULL_LOCATION_PLACEHOLDER/$full_location}"
  workflow_content="${workflow_content//LOCATION_NAME_PLACEHOLDER/$location_name}"

  # Write the content to a new workflow file using the last location name
  echo "$workflow_content" > "${workflow_dir}/osrm_${location_name}.yml"
  echo "Created workflow for $location_name at ${workflow_dir}/osrm_${location_name}.yml"
done < "$country_port_file"
