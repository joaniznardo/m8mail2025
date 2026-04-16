# Restringim local_networks per a que Rspamd faci verificació
# completa (SPF, DKIM, DMARC) dels missatges del lab
# Només el propi servidor i loopback es consideren locals
local_networks = "127.0.0.0/8";
