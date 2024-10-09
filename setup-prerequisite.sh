#!/usr/bin/env bash
set -e
echo "Processing $0"
service_container_name="$SERVICE_NAME-service"
service_container_id=$(docker run -d --rm -p "$SERVICE_PORT:$SERVICE_PORT" \
  -p "$SERVICE_ADMIN_PORT:$SERVICE_ADMIN_PORT" \
	--hostname "$DATABASE_NAME" \
	-e RABBITMQ_DEFAULT_VHOST="$DATABASE_NAME" \
	-e RABBITMQ_DEFAULT_USER=$SERVICE_USERNAME \
	-e RABBITMQ_DEFAULT_PASS=$SERVICE_PASSWORD \
  --name "$service_container_name" \
  --health-cmd "$SERVICE_HEALTH_CMD" \
  --health-interval 10s --health-timeout 5s --health-retries 5 \
  ${SERVICE_IMAGE})

docker logs -f "$service_container_name" &> "$service_container_name.log" &
echo "Waiting for $service_container_name"
while [ "$( docker container inspect -f '{{.State.Status}}' $service_container_name )" != "running" ]; do
  status=$(docker inspect -f '{{.State.Status}}' $service_container_name)
  if [ $? -ne 0 ];then
    echo "ERROR: failed to inspect $service_container_name: $status"
    exit 1
  fi
  echo "waiting for $service_container_name to be running, currently: $status"
  sleep 1
done
while [ "$( docker container inspect -f '{{.State.Health.Status}}' $service_container_name )" != "healthy" ]; do
  echo "waiting for $service_container_name to be healthy, currently: $(docker inspect -f '{{.State.Health.Status}}' $service_container_name)"
  sleep 1
done

if [ -z "$service_container_id" ];then
  echo "ERROR: failed to start container '$service_container_name' using $SERVICE_IMAGE"
else
  echo "'$service_container_name' is running $SERVICE_IMAGE"
fi
service_container_name="$(docker ps -f "ancestor=$SERVICE_IMAGE" --format "{{.Names}}")"
SERVICE_CONTAINER_IP=$(docker inspect -f '{{range .NetworkSettings.Networks}}{{.IPAddress}}{{end}}' "$service_container_name")
echo "SERVICE_CONTAINER_IP: $SERVICE_CONTAINER_IP"
export SERVICE_HOST=$SERVICE_CONTAINER_IP
echo "$SERVICE_NAME - Rabbit status $service_container_name using rabbitmqctl: $(docker exec -i $service_container_name rabbitmqctl  ping)"

echo "$SERVICE_NAME - Connection to management console: curl -u "$SERVICE_USERNAME:$SERVICE_PASSWORD" http://localhost:${SERVICE_ADMIN_PORT}/api/overview"
curl -sSLf -u "$SERVICE_USERNAME:$SERVICE_PASSWORD" http://localhost:${SERVICE_ADMIN_PORT}/api/overview

echo "SERVICE_HOST: $SERVICE_HOST"
