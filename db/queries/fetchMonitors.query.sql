
SELECT 
  id, 
  name,
  frequency_seconds,
  url,
  expected_status_code,
  created_date,
  validation_logic,
  is_active,
  is_public
FROM monitors
ORDER BY name ASC;