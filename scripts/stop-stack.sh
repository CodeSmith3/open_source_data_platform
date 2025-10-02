#!/bin/bash

echo "Stopping all services gracefully..."
docker-compose down

echo "To remove all data volumes as well, run:"
echo "docker-compose down -v"
echo ""
echo "To remove all images as well, run:" 
echo "docker-compose down -v --rmi all"