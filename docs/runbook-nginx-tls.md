# Runbook: nginx + TLS

How the reverse proxy layer is put together and what to check when a
domain starts returning 502.

## Layout

    /etc/nginx/sites-enabled/     one file per vhost, symlinked from sites-available
    /etc/nginx/sites-available/   the real files
    /etc/nginx/snippets/          shared blocks (proxy headers, rate limits)

Each vhost file proxies to a port on localhost. `nginx -t` is the only
truth; a vhost that does not pass the syntax check is not loaded at all,
which is why one bad file takes the whole proxy down rather than just one
site.

## Diagnosing a 502

1. Find the vhost for the domain.

       grep -rl "example.com" /etc/nginx/sites-enabled/

2. Find the upstream port it proxies to.

       grep -E "proxy_pass" /etc/nginx/sites-enabled/<file>

3. Is anything listening on that port?

       ss -ltnp | grep :<port>

4. Is the app actually serving?

       curl -sS -i http://127.0.0.1:<port>/health | head

   A connection refused here means the app is down. A response means nginx
   cannot reach it and it is a firewall or binding problem.

5. Check the error log for the exact reason.

       tail -n 50 /var/log/nginx/error.log

## Reloading

Always test before reloading. `nginx -t` parses the config and reports
errors without touching the running process.

    nginx -t && systemctl reload nginx

A reload is safe and does not drop connections. A restart does. Do not
restart nginx to apply a config change; reload.

## Certificates

Certificates are managed by certbot with the nginx plugin, so renewal
edits the vhost file in place. After a renewal, reload nginx - the new
certificate is not served until nginx picks it up.

    certbot renew --dry-run
    nginx -t && systemctl reload nginx

## Notes

- Keep `proxy_set_header Host $host;` and the `X-Forwarded-*` headers on
  every vhost. The apps behind this proxy build absolute URLs and will
  generate http:// links otherwise.
- Long-running requests (media uploads, report generation) need
  `proxy_read_timeout` raised or they will be cut off mid-flight.
