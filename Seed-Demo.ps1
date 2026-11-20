# Creates local demo data for jbeltrano using the KMZ geometry already
# imported into MongoDB. Run it after the admin/gateway/geoloca stack is up.
$ErrorActionPreference = "Continue"
Set-Location $PSScriptRoot

$today = (Get-Date).ToString("yyyy-MM-dd")
$schoolName = "LICEO NACIONAL AGUSTIN NIETO CABALLERO"

function Wait-Database {
  param(
    [string]$Label,
    [scriptblock]$Probe
  )
  for ($attempt = 0; $attempt -lt 90; $attempt++) {
    & $Probe 2>$null | Out-Null
    if ($LASTEXITCODE -eq 0) { return }
    if ($attempt -eq 0) {
      Write-Host "Esperando $Label..."
    }
    Start-Sleep -Seconds 2
  }
  throw "Timeout esperando $Label."
}

Wait-Database "MySQL acb_routes_db" {
  docker exec acb_mysql_db mysql -uroot -proot_mysql_password --batch --skip-column-names -e "SELECT 1 FROM acb_routes_db.routes LIMIT 1"
}
Wait-Database "MySQL acb_users_db" {
  docker exec acb_mysql_db mysql -uroot -proot_mysql_password --batch --skip-column-names -e "SELECT 1 FROM acb_users_db.users LIMIT 1"
}
Wait-Database "PostgreSQL trip" {
  docker exec acb_postgres_db psql -U postgres -d acb_operation_db -t -c "SELECT 1 FROM trip LIMIT 1"
}

$mysql = @"
INSERT INTO acb_routes_db.schools
  (name, school_code, phone, address, zone, latitude, longitude, active)
VALUES
  ('$schoolName', 'MM01', '3000000000', 'Bogota', 'MM',
   4.60584683732276, -74.0861706852785, 1)
ON DUPLICATE KEY UPDATE
  school_id = LAST_INSERT_ID(school_id),
  name = VALUES(name),
  phone = VALUES(phone),
  address = VALUES(address),
  zone = VALUES(zone),
  latitude = VALUES(latitude),
  longitude = VALUES(longitude),
  active = 1;
SET @school_id = LAST_INSERT_ID();

INSERT INTO acb_routes_db.routes
  (shift_code, route_code, description, school_id, scheduled_start_time,
   guide_main_id, guide_main_name, guide_support_id, guide_support_name, active)
VALUES
  ('541', 'MM01', 'Ruta demo MM01 541', @school_id, '06:00:00',
   9001, 'J. Beltrano', NULL, NULL, 1)
ON DUPLICATE KEY UPDATE
  route_id = LAST_INSERT_ID(route_id),
  description = VALUES(description),
  school_id = VALUES(school_id),
  guide_main_id = 9001,
  guide_main_name = 'J. Beltrano',
  guide_support_id = NULL,
  guide_support_name = NULL,
  active = 1;
SET @route541 = LAST_INSERT_ID();

INSERT INTO acb_routes_db.routes
  (shift_code, route_code, description, school_id, scheduled_start_time,
   guide_main_id, guide_main_name, guide_support_id, guide_support_name, active)
VALUES
  ('542', 'MM01', 'Ruta demo MM01 542', @school_id, '14:00:00',
   9001, 'J. Beltrano', NULL, NULL, 1)
ON DUPLICATE KEY UPDATE
  route_id = LAST_INSERT_ID(route_id),
  description = VALUES(description),
  school_id = VALUES(school_id),
  guide_main_id = 9001,
  guide_main_name = 'J. Beltrano',
  guide_support_id = NULL,
  guide_support_name = NULL,
  active = 1;
SET @route542 = LAST_INSERT_ID();

INSERT INTO acb_routes_db.meeting_points
  (meeting_point_code, address, latitude, longitude, route_id)
VALUES
  ('PE01', 'PE01 ruta 541', 4.610778163276717, -74.07546943494334, @route541)
ON DUPLICATE KEY UPDATE
  meeting_point_id = LAST_INSERT_ID(meeting_point_id),
  address = VALUES(address),
  latitude = VALUES(latitude),
  longitude = VALUES(longitude);
SET @pe541 = LAST_INSERT_ID();

INSERT INTO acb_routes_db.meeting_points
  (meeting_point_code, address, latitude, longitude, route_id)
VALUES
  ('PE01', 'Salida del colegio', 4.60584683732276, -74.0861706852785, @route542)
ON DUPLICATE KEY UPDATE
  meeting_point_id = LAST_INSERT_ID(meeting_point_id),
  address = VALUES(address),
  latitude = VALUES(latitude),
  longitude = VALUES(longitude);
SET @pe542 = LAST_INSERT_ID();

INSERT INTO acb_users_db.users
  (user_id, document_type, document_number, name, address, role, active, phone)
VALUES
  (9002, 'NUIP', '1068972260', 'pepe preto', 'Calle 2', 'STUDENT', 1, '3001111111')
ON DUPLICATE KEY UPDATE
  name = VALUES(name), role = 'STUDENT', active = 1, address = VALUES(address), phone = VALUES(phone);

INSERT INTO acb_users_db.students
  (grade, school_shift, section, student_id, school_id)
VALUES
  ('10', 'MORNING', 'b', 9002, @school_id)
ON DUPLICATE KEY UPDATE
  grade = VALUES(grade), school_shift = VALUES(school_shift),
  section = VALUES(section), school_id = VALUES(school_id);

INSERT INTO acb_routes_db.students
  (student_id, name, active, route_id)
VALUES
  (9002, 'pepe preto', 1, @route541)
ON DUPLICATE KEY UPDATE
  name = VALUES(name), active = 1, route_id = VALUES(route_id);

INSERT INTO acb_routes_db.students_meeting_points
  (shift_code, meeting_point_id, student_id)
VALUES
  ('541', @pe541, 9002)
ON DUPLICATE KEY UPDATE meeting_point_id = VALUES(meeting_point_id);

SELECT CONCAT(@route541, ',', @pe541, ',', @route542, ',', @pe542);
"@

$mysqlOutput = $mysql | docker exec -i acb_mysql_db mysql -uroot -proot_mysql_password --batch --skip-column-names 2>&1
if ($LASTEXITCODE -ne 0) {
  $mysqlOutput | Write-Host
  throw "No se pudo crear la ruta demo en MySQL."
}
$idsLine = @($mysqlOutput | Where-Object { $_ -match '^\d+,\d+,\d+,\d+$' } | Select-Object -Last 1)
if (-not $idsLine) {
  throw "MySQL no devolvió los IDs de la ruta demo."
}
$ids = $idsLine.Split(",")
$route541 = $ids[0]
$pe541 = $ids[1]
$route542 = $ids[2]
$pe542 = $ids[3]

$postgres = @"
DELETE FROM trip_guide_attendance
WHERE trip_id IN (
  SELECT trip_id FROM trip
  WHERE trip_date = '$today' AND route_id IN ($route541, $route542)
) AND assignment_role = 'SUPPORT';

WITH trip541 AS (
  INSERT INTO trip
    (route_id, route_code_snapshot, shift_code_snapshot, trip_date,
     school_name_snapshot, scheduled_start_snapshot,
     start_point_id, start_point_code_snapshot)
  VALUES
    ($route541, 'MM01', '541', '$today',
     '$schoolName', '06:00:00', $pe541, 'PE01')
  ON CONFLICT (route_id, trip_date) DO UPDATE SET
    route_code_snapshot = EXCLUDED.route_code_snapshot,
    shift_code_snapshot = EXCLUDED.shift_code_snapshot,
    school_name_snapshot = EXCLUDED.school_name_snapshot,
    scheduled_start_snapshot = EXCLUDED.scheduled_start_snapshot,
    start_point_id = EXCLUDED.start_point_id,
    start_point_code_snapshot = EXCLUDED.start_point_code_snapshot,
    actual_start_at = NULL,
    actual_end_at = NULL,
    completion_code = NULL
  RETURNING trip_id
)
INSERT INTO trip_guide_attendance
  (trip_id, assignment_role, planned_guide_id, planned_guide_name_snapshot)
SELECT trip_id, 'MAIN', 9001, 'J. Beltrano' FROM trip541
ON CONFLICT (trip_id, assignment_role) DO UPDATE SET
  planned_guide_id = EXCLUDED.planned_guide_id,
  planned_guide_name_snapshot = EXCLUDED.planned_guide_name_snapshot;

WITH trip542 AS (
  INSERT INTO trip
    (route_id, route_code_snapshot, shift_code_snapshot, trip_date,
     school_name_snapshot, scheduled_start_snapshot,
     start_point_id, start_point_code_snapshot)
  VALUES
    ($route542, 'MM01', '542', '$today',
     '$schoolName', '14:00:00', $pe542, 'PE01')
  ON CONFLICT (route_id, trip_date) DO UPDATE SET
    route_code_snapshot = EXCLUDED.route_code_snapshot,
    shift_code_snapshot = EXCLUDED.shift_code_snapshot,
    school_name_snapshot = EXCLUDED.school_name_snapshot,
    scheduled_start_snapshot = EXCLUDED.scheduled_start_snapshot,
    start_point_id = EXCLUDED.start_point_id,
    start_point_code_snapshot = EXCLUDED.start_point_code_snapshot,
    actual_start_at = NULL,
    actual_end_at = NULL,
    completion_code = NULL
  RETURNING trip_id
)
INSERT INTO trip_guide_attendance
  (trip_id, assignment_role, planned_guide_id, planned_guide_name_snapshot)
SELECT trip_id, 'MAIN', 9001, 'J. Beltrano' FROM trip542
ON CONFLICT (trip_id, assignment_role) DO UPDATE SET
  planned_guide_id = EXCLUDED.planned_guide_id,
  planned_guide_name_snapshot = EXCLUDED.planned_guide_name_snapshot;
"@

$postgresOutput = $postgres | docker exec -i acb_postgres_db psql -U postgres -d acb_operation_db -v ON_ERROR_STOP=1 2>&1
if ($LASTEXITCODE -ne 0) {
  $postgresOutput | Write-Host
  throw "No se pudieron crear los viajes demo en PostgreSQL."
}

Write-Host "Datos demo listos para $today"
Write-Host "  Usuario: jbeltrano / guia2026"
Write-Host "  Rutas:   MM01 541, MM01 542"
Write-Host "  Viajes:  hoy (541 y 542)"
Write-Host "  Estudiante: pepe preto en PE01 de 541"
