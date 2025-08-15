#!/bin/bash
ORG="my-org"
BUCKET="ServerMetrics"

ALL=$(influx query '
import "influxdata/influxdb/schema"
schema.measurements(bucket: "'$BUCKET'")
  |> sort()
' --raw | tail -n +2 | awk -F',' '{print $NF}')

ACTIVE=$(influx query '
from(bucket: "'$BUCKET'")
  |> range(start: -1d)
  |> keep(columns: ["_measurement"])
  |> distinct(column: "_measurement")
  |> sort()
' --raw | tail -n +2 | awk -F',' '{print $NF}')

INACTIVE=$(comm -23 <(echo "$ALL" | sort) <(echo "$ACTIVE" | sort))

echo "Các measurement inactive trong 1 ngày qua:"
echo "$INACTIVE"

for m in $INACTIVE; do
  echo "Xóa measurement: $m"
  influx delete \
    --org "$ORG" \
    --bucket "$BUCKET" \
    --start 1970-01-01T00:00:00Z \
    --stop 2100-01-01T00:00:00Z \
    --predicate "_measurement='$m'"
done
