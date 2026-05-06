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
echo "HOST=[" . ($cfg['database.default.hostname'] ?? 'MISSING') . "]\n";
echo "USER=[" . ($cfg['database.default.username'] ?? 'MISSING') . "]\n";
echo "PASS=[" . ($cfg['database.default.password'] ?? 'MISSING') . "]\n";
echo "PASS_LEN=" . strlen($cfg['database.default.password'] ?? '') . "\n";
echo "DB=[" . ($cfg['database.default.database'] ?? 'MISSING') . "]\n";
