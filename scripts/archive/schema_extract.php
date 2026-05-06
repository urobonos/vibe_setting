<?php
$env = file_get_contents('/works/hongcafe-global/dev/config/.env');
$cfg = [];
foreach (explode("\n", $env) as $line) {
    $line = trim($line);
    if (str_starts_with($line, '#') || $line === '') continue;
    if (preg_match('/^([^=]+?)\s*=\s*(.*)$/', $line, $m2)) {
        $cfg[trim($m2[1])] = trim($m2[2]);
    }
}
$host = $cfg['database.default.hostname'];
$user = $cfg['database.default.username'];
$pass = $cfg['database.default.password'];
$db   = $cfg['database.default.database'];
$port = (int)($cfg['database.default.port'] ?? 3306);

$m = mysqli_init();
// No ssl_set call — just pass MYSQLI_CLIENT_SSL flag
if (!$m->real_connect($host, $user, $pass, $db, $port, null, MYSQLI_CLIENT_SSL)) {
    echo "ERR:" . $m->connect_error;
    exit(1);
}
$m->set_charset("utf8mb4");

// 1. Tables
echo "=== TABLES ===\n";
$r = $m->query("SELECT TABLE_NAME, TABLE_COMMENT FROM INFORMATION_SCHEMA.TABLES WHERE TABLE_SCHEMA='athena' ORDER BY TABLE_NAME");
while ($row = $r->fetch_assoc()) {
    echo $row['TABLE_NAME'] . "\t" . $row['TABLE_COMMENT'] . "\n";
}

// 2. Columns
echo "=== COLUMNS ===\n";
$r = $m->query("SELECT TABLE_NAME, COLUMN_NAME, COLUMN_COMMENT, COLUMN_TYPE, IS_NULLABLE, COLUMN_DEFAULT, COLUMN_KEY, EXTRA FROM INFORMATION_SCHEMA.COLUMNS WHERE TABLE_SCHEMA='athena' ORDER BY TABLE_NAME, ORDINAL_POSITION");
while ($row = $r->fetch_assoc()) {
    echo implode("\t", [
        $row['TABLE_NAME'],
        $row['COLUMN_NAME'],
        $row['COLUMN_COMMENT'] ?? '',
        $row['COLUMN_TYPE'],
        $row['IS_NULLABLE'],
        $row['COLUMN_DEFAULT'] ?? 'NULL',
        $row['COLUMN_KEY'],
        $row['EXTRA']
    ]) . "\n";
}

// 3. Indexes
echo "=== INDEXES ===\n";
$r = $m->query("SELECT TABLE_NAME, INDEX_NAME, GROUP_CONCAT(COLUMN_NAME ORDER BY SEQ_IN_INDEX) AS IDX_COLUMNS, CASE WHEN NON_UNIQUE=0 THEN 'UNIQUE' ELSE 'INDEX' END AS INDEX_TYPE FROM INFORMATION_SCHEMA.STATISTICS WHERE TABLE_SCHEMA='athena' GROUP BY TABLE_NAME, INDEX_NAME, NON_UNIQUE ORDER BY TABLE_NAME, INDEX_NAME");
while ($row = $r->fetch_assoc()) {
    echo implode("\t", [$row['TABLE_NAME'], $row['INDEX_NAME'], $row['IDX_COLUMNS'], $row['INDEX_TYPE']]) . "\n";
}

// 4. Foreign Keys
echo "=== RELATIONS ===\n";
$r = $m->query("SELECT TABLE_NAME, COLUMN_NAME, REFERENCED_TABLE_NAME, REFERENCED_COLUMN_NAME FROM INFORMATION_SCHEMA.KEY_COLUMN_USAGE WHERE TABLE_SCHEMA='athena' AND REFERENCED_TABLE_NAME IS NOT NULL ORDER BY TABLE_NAME");
while ($row = $r->fetch_assoc()) {
    echo implode("\t", [$row['TABLE_NAME'], $row['COLUMN_NAME'], $row['REFERENCED_TABLE_NAME'], $row['REFERENCED_COLUMN_NAME']]) . "\n";
}

$m->close();
