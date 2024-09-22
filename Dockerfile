  # Dockerfile для конфигурации из config/local.yaml

  # Используем официальный образ Golang версии 1.22 как базовый
  FROM golang:1.22-alpine

  # Устанавливаем рабочую директорию в контейнере
  WORKDIR /app

  # Копируем файлы go.mod и go.sum (если есть) и загружаем зависимости
  COPY go.mod go.sum* ./
  RUN go mod download

  # Устанавливаем необходимые зависимости
  RUN apk add --no-cache postgresql-client redis curl mongodb-tools supervisor kubectl

  # Копируем исходный код приложения в контейнер
  COPY . .

  # Копируем конфигурационный файл
  COPY config/local.yaml /app/config/config.yaml

  # Устанавливаем переменные окружения из конфигурации
  ENV SERVER_PORT=8080
  ENV SERVER_HOST=0.0.0.0
  ENV DATABASE_HOST=postgres
  ENV DATABASE_PORT=5432
  ENV DATABASE_NAME=myapp_db
  ENV DATABASE_USER=myapp_user
  ENV DATABASE_PASSWORD=myapp_password
  ENV CACHE_ADDRESS=redis:6379
  ENV JWT_SECRET=my_super_secret_key
  ENV KAFKA_BROKERS=kafka:9092
  ENV GRPC_PORT=50051
  ENV PROMETHEUS_PORT=9090
  ENV GRAFANA_PORT=3000
  ENV JAEGER_AGENT_HOST=jaeger
  ENV JAEGER_AGENT_PORT=6831
  ENV MONGODB_URI=mongodb://mongodb:27017/myapp_db

  # Собираем приложение
  # Копируем файл main.go из директории cmd в рабочую директорию
  COPY cmd/main.go .

  # Собираем приложение
  RUN go build -o main .

  # Открываем порты, указанные в конфигурации
  EXPOSE 8080 50051 9090 3000

  # Устанавливаем Jaeger
  RUN wget -O /tmp/jaeger-client.tar.gz https://github.com/jaegertracing/jaeger-client-go/archive/v2.30.0.tar.gz && \
      tar -xzf /tmp/jaeger-client.tar.gz -C /tmp && \
      mv /tmp/jaeger-client-go-2.30.0 /usr/local/jaeger-client && \
      rm /tmp/jaeger-client.tar.gz

  # Устанавливаем Prometheus
  RUN wget https://github.com/prometheus/prometheus/releases/download/v2.30.3/prometheus-2.30.3.linux-amd64.tar.gz && \
      tar xvfz prometheus-2.30.3.linux-amd64.tar.gz && \
      mv prometheus-2.30.3.linux-amd64 /etc/prometheus && \
      rm prometheus-2.30.3.linux-amd64.tar.gz

  # Копируем конфигурацию Prometheus
  COPY prometheus.yml /etc/prometheus/prometheus.yml

  # Устанавливаем Grafana
  RUN wget https://dl.grafana.com/oss/release/grafana-8.2.2.linux-amd64.tar.gz && \
      tar -zxvf grafana-8.2.2.linux-amd64.tar.gz && \
      mv grafana-8.2.2 /var/lib/grafana && \
      rm grafana-8.2.2.linux-amd64.tar.gz

  # Копируем конфигурацию Grafana
  COPY grafana.ini /var/lib/grafana/conf/custom.ini

  # Устанавливаем дополнительные инструменты для отладки
  RUN apk add --no-cache vim

  # Создаем директорию для логов
  RUN mkdir -p /var/log/myapp

  # Устанавливаем права на выполнение для основного приложения и скриптов
  RUN chmod +x main

  # Добавляем пользователя с ограниченными правами
  RUN adduser -D myapp
  # USER myapp

  # Копируем конфигурацию supervisord
  COPY supervisord.conf /etc/supervisord.conf

  # Добавляем healthcheck
  HEALTHCHECK --interval=30s --timeout=30s --start-period=5s --retries=3 \
    CMD wget -qO- http://localhost:8080/health || exit 1

  # Метаданные
  LABEL maintainer="your-email@example.com"
  LABEL version="1.0"
  LABEL description="Docker image for MyApp based on local.yaml configuration, using Golang 1.22 with Jaeger tracing, MongoDB support, and Kubernetes integration"

  # Устанавливаем kubectl
  RUN curl -LO "https://dl.k8s.io/release/$(curl -L -s https://dl.k8s.io/release/stable.txt)/bin/linux/amd64/kubectl" && \
      chmod +x kubectl && \
      mv kubectl /usr/local/bin/

  # Копируем Kubernetes конфигурационные файлы
  COPY k8s/ /app/k8s/

  # Запускаем несколько процессов с использованием supervisord
  CMD ["/usr/bin/supervisord", "-c", "/etc/supervisord.conf"]
