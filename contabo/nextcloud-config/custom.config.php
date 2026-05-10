<?php
$CONFIG = array (
  // Tuning untuk VPS dengan resource terbatas
  'memcache.local' => '\\OC\\Memcache\\APCu',
  'memcache.distributed' => '\\OC\\Memcache\\Redis',
  'memcache.locking' => '\\OC\\Memcache\\Redis',

  // Default phone region (untuk validasi nomor HP)
  'default_phone_region' => 'ID',

  // Logging
  'loglevel' => 2,
  'log_type' => 'file',
  'logfile' => '/var/www/html/data/nextcloud.log',

  // Theme & branding
  'theme' => '',

  // Maintenance window (jam 2-3 pagi UTC = 9-10 pagi WIB)
  'maintenance_window_start' => 1,

  // File handling
  'filesystem_check_changes' => 1,
  'integrity.check.disabled' => false,
);
