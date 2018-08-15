-- $1: should fetch private monitors

SELECT
  m.id,
  m.name,
  m.url,
  m.is_active,
  m.is_public,
  status.created_date AS last_check_date,
  status.succeeded AS last_check_result,
  CASE WHEN active_incident.id IS NOT NULL THEN JSON_BUILD_OBJECT(
    'id', active_incident.id,
    'createdDate', active_incident.created_date,
    'acknowledgedDate', active_incident.acknowledged_date,
    'title', active_incident.title,
    'description', active_incident.description
  ) ELSE NULL END AS active_incident,
  100 * (
    1 - (
      EXTRACT(EPOCH FROM COALESCE(rolling_month_incidents.accumulated_downtime, INTERVAL '0 second')) 
      / 
      EXTRACT(EPOCH FROM (NOW() - (NOW() - INTERVAL '1 month')))
    )
  ) AS rolling_month_uptime
FROM monitors AS m
LEFT JOIN monitor_status_checks AS status ON status.monitor_id = m.id
LEFT JOIN incidents AS active_incident ON active_incident.monitor_id = m.id AND active_incident.closed_date IS NULL
LEFT JOIN LATERAL (
  SELECT 
    i.monitor_id,
    SUM(
      CASE WHEN i.closed_date IS NOT NULL THEN i.closed_date ELSE NOW() END
      -
      CASE WHEN i.created_date > NOW() - INTERVAL '1 month' THEN i.created_date ELSE NOW() - INTERVAL '1 month' END 
    ) AS accumulated_downtime
  FROM incidents AS i
  WHERE i.closed_date IS NULL OR i.closed_date > NOW() - INTERVAL '1 month'
    AND i.count_as_downtime = TRUE
  GROUP BY i.monitor_id
) AS rolling_month_incidents ON rolling_month_incidents.monitor_id = m.id
WHERE (m.is_public = TRUE OR $1::BOOLEAN = TRUE)
ORDER BY m.name ASC
