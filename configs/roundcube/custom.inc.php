<?php
// --- Configuració personalitzada de Roundcube per al laboratori ---
// Permet connexions amb certificats autosignats (entorn de laboratori)

$config['imap_conn_options'] = array(
  'ssl' => array(
    'verify_peer' => false,
    'verify_peer_name' => false,
    'allow_self_signed' => true,
  ),
);

$config['smtp_conn_options'] = array(
  'ssl' => array(
    'verify_peer' => false,
    'verify_peer_name' => false,
    'allow_self_signed' => true,
  ),
);
