#!/bin/sh

# Chờ Grafana khởi động
echo "Waiting for Grafana to start..."
until curl -s http://172.18.70.240:3000/api/health | grep "ok"; do
  sleep 3
done

echo "Grafana is up. Creating API Key..."

# Tạo API key trong SQLite database
sqlite3 /var/lib/grafana/grafana.db <<EOF
INSERT INTO api_key (key, name, role, created, expires) VALUES
('my-secret-token', 'admin-key', 4, strftime('%s','now'), NULL);
EOF

API_KEY="my-secret-token"

# Import dashboard
echo "Importing dashboard..."
curl -X POST http://172.18.70.240:3000/api/dashboards/db \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer $API_KEY" \
  -d @/dashboard.json

echo "Dashboard imported successfully!"
