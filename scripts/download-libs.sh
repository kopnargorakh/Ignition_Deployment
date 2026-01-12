#!/bin/bash
set -e

echo "Downloading JAR libraries..."
mkdir -p jar-files

# RabbitMQ AMQP Client (Java 17 compatible)
if [ ! -f "jar-files/amqp-client-5.28.0.jar" ]; then
    curl -L -o jar-files/amqp-client-5.28.0.jar \
        https://repo1.maven.org/maven2/com/rabbitmq/amqp-client/5.28.0/amqp-client-5.28.0.jar
    echo "Downloaded amqp-client-5.28.0.jar"
else
    echo "amqp-client-5.28.0.jar already exists"
fi

echo "JAR libraries ready:"
ls -la jar-files/
