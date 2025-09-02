# Start with a base image that includes OSRM
FROM ghcr.io/project-osrm/osrm-backend

# Define build arguments for location and continent
ARG LOCATION=south-korea

# Copy the map file into the container
COPY ${LOCATION}-latest.osm.pbf /data/${LOCATION}-latest.osm.pbf

# Run OSRM commands with the location variable
RUN osrm-extract -p /opt/car.lua /data/${LOCATION}-latest.osm.pbf
RUN osrm-contract /data/${LOCATION}-latest.osrm
