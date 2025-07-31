# Custom Monitoring Scripts

This directory contains custom scripts that can be executed by Telegraf to collect additional metrics.

## How to Use

1. Place your custom scripts in this directory
2. Make sure scripts are executable: `chmod +x your-script.sh`
3. Enable exec scripts module in `.env`: `ENABLE_EXEC_SCRIPTS=true`
4. Configure the script in `configs/telegraf/telegraf-exec.conf`
5. Deploy/restart the services

## Script Requirements

### Output Format

Scripts must output metrics in one of these formats:

1. **InfluxDB Line Protocol** (recommended):
```
measurement,tag1=value1,tag2=value2 field1=value1,field2=value2 timestamp
```

2. **JSON Format**:
```json
{
  "measurement": "metric_name",
  "tags": {
    "tag1": "value1"
  },
  "fields": {
    "field1": 123,
    "field2": 45.6
  },
  "time": 1234567890
}
```

### Examples

See the `examples/` directory for sample scripts:
- `basic_metrics.sh` - Basic system metrics in InfluxDB format
- `advanced_metrics.py` - Advanced metrics in JSON format

## Best Practices

1. **Error Handling**: Always handle errors gracefully
2. **Timeouts**: Keep execution time under 30 seconds
3. **Output**: Use stdout for metrics, stderr for errors
4. **Testing**: Test scripts locally before deployment:
   ```bash
   ./your-script.sh
   ```

5. **Performance**: Avoid heavy operations that could impact system performance

## Adding New Scripts

1. Create your script:
```bash
#!/bin/bash
# my-custom-metric.sh
echo "my_metric,host=$(hostname) value=42"
```

2. Make it executable:
```bash
chmod +x my-custom-metric.sh
```

3. Test it:
```bash
./my-custom-metric.sh
```

4. Add to Telegraf config (`configs/telegraf/telegraf-exec.conf`):
```toml
[[inputs.exec]]
  commands = ["/scripts/my-custom-metric.sh"]
  timeout = "30s"
  data_format = "influx"
  interval = "60s"
```

5. Restart Telegraf:
```bash
docker compose restart telegraf-exec
```