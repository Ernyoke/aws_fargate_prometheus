# cwmetrics

Spring project used for generate metrics for CloudWatch Agent with Prometheus.

## Endpoints

### Metrics

```shell
curl -XGET http://localhost:8080/actuator/prometheus
```

### Controller Endpoints

```shell
http://localhost:8080/people
```

```shell
http://localhost:8080/people/1
```

## Building the Container

```shell
mvn clean package
docker build -t cwmetrics .
```
